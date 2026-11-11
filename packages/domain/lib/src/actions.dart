import 'access_policy.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'model.dart';
import 'request_status.dart';
import 'result.dart';
import 'rules.dart';
import 'transitions.dart';
import 'user.dart';

// Akcije nad zahtevom. Redom proveravaju pravo (AccessPolicy), pravilo i prelaz, pa vraćaju izmenjen zahtev.
// Klijenti i server ih pozivaju, a ne ponavljaju pravila.

Result<CollaborationRequest> _move(
  CollaborationRequest request, {
  required RequestStatus to,
  required Role role,
  required bool allowed,
  Result<void> rule = const Success(null),
  int? revisions,
}) {
  if (!allowed) return const Failure(NotAllowed());
  if (rule case Failure(:final error)) return Failure(error);
  if (!canTransition(request.status, to, role)) {
    return Failure(InvalidTransition(from: request.status, to: to, role: role));
  }
  return Success(request.copyWith(status: to, revisions: revisions));
}

/// Klijent otkazuje svoj zahtev dok ga pružalac nije prihvatio.
Result<CollaborationRequest> cancelByClient(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.cancelled,
  role: Role.client,
  allowed: AccessPolicy.canActAsClient(by, request),
  rule: canCancelByClient(request),
);

/// Klijent potvrđuje isporuku svog zahteva.
Result<CollaborationRequest> confirmDelivery(CollaborationRequest request, {required User by}) =>
    _move(request, to: RequestStatus.completed, role: Role.client, allowed: AccessPolicy.canActAsClient(by, request));

/// Klijent vraća isporučen zahtev na doradu; troši jednu reviziju.
Result<CollaborationRequest> requestRevision(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.inProgress,
  role: Role.client,
  allowed: AccessPolicy.canActAsClient(by, request),
  rule: withinRevisionLimit(request),
  revisions: request.revisions + 1,
);

/// Pružalac prihvata poslat zahtev upućen njemu.
Result<CollaborationRequest> acceptByProvider(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.accepted,
  role: Role.provider,
  allowed: AccessPolicy.canActAsProvider(by, request),
);

/// Pružalac odbija poslat zahtev upućen njemu.
Result<CollaborationRequest> rejectByProvider(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.rejected,
  role: Role.provider,
  allowed: AccessPolicy.canActAsProvider(by, request),
);

Result<CollaborationRequest> moderatorCancel(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.cancelled,
  role: Role.moderator,
  allowed: AccessPolicy.canModerate(by),
  rule: moderatorCanCancel(request),
);

Result<CollaborationRequest> moderatorClose(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.completed,
  role: Role.moderator,
  allowed: AccessPolicy.canModerate(by),
  rule: moderatorCanClose(request),
);

Result<CollaborationRequest> moderatorReopen(CollaborationRequest request, {required User by}) => _move(
  request,
  to: RequestStatus.inProgress,
  role: Role.moderator,
  allowed: AccessPolicy.canModerate(by),
  rule: moderatorCanReopen(request),
);

/// Pravi novi zahtev u stanju „poslat“ ako ga šalje klijent u svoje ime, pružalac prima zahteve,
/// nudi uslugu i ima mesta.
Result<CollaborationRequest> createRequest(
  NewRequest draft, {
  required User by,
  required Provider provider,
  required Iterable<CollaborationRequest> existing,
  required RequestId id,
  required DateTime now,
}) {
  if (!AccessPolicy.canCreateRequest(by, draft)) return const Failure(NotAllowed());
  if (!isListedInCatalog(provider)) return const Failure(ProviderNotListed());
  if (!provider.services.contains(draft.service)) return Failure(ServiceNotOffered(draft.service));
  final note = noteWithinLength(draft.note);
  if (note case Failure(:final error)) return Failure(error);
  if (providerHasCapacity(provider, existing) case Failure(:final error)) return Failure(error);
  return Success(
    CollaborationRequest(
      id: id,
      clientId: draft.clientId,
      providerId: draft.providerId,
      service: draft.service,
      note: note.valueOrNull!,
      status: RequestStatus.sent,
      createdAt: now,
    ),
  );
}

/// Prijava u aplikaciju: uspeh nosi korisnika, a pogrešna aplikacija daje [WrongApp].
Result<User> signInTo(ClientApp app, User user) =>
    AccessPolicy.canSignIn(user, app) ? Success(user) : Failure(WrongApp(app));

/// Akcije nad postojećim zahtevom, kako ih šalje klijent i prima server.
enum RequestAction { cancel, complete, revise, accept, reject, close, reopen }

/// Akcija iz domena za [action] u ime [by]. Otkazivanje zavisi od uloge: moderator otkazuje svaki nezavršen
/// zahtev, klijent samo svoj poslat. Isto koriste klijenti (provera pre slanja) i server (konačna odluka).
Result<CollaborationRequest> applyAction(RequestAction action, CollaborationRequest request, {required User by}) =>
    switch (action) {
      RequestAction.cancel when by.role == Role.moderator => moderatorCancel(request, by: by),
      RequestAction.cancel => cancelByClient(request, by: by),
      RequestAction.complete => confirmDelivery(request, by: by),
      RequestAction.revise => requestRevision(request, by: by),
      RequestAction.accept => acceptByProvider(request, by: by),
      RequestAction.reject => rejectByProvider(request, by: by),
      RequestAction.close => moderatorClose(request, by: by),
      RequestAction.reopen => moderatorReopen(request, by: by),
    };
