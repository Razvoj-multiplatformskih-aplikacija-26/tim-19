import 'actor.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'model.dart';
import 'request_status.dart';
import 'result.dart';
import 'rules.dart';
import 'transitions.dart';

// Akcije nad zahtevom: proveravaju pravilo i prelaz, pa vraćaju izmenjen zahtev.
// Klijenti i server ih pozivaju, a ne ponavljaju pravila.

Result<CollaborationRequest> _move(
  CollaborationRequest request, {
  required RequestStatus to,
  required Actor by,
  Result<void> rule = const Success(null),
  int? revisions,
}) {
  if (rule case Failure(:final error)) return Failure(error);
  if (!canTransition(request.status, to, by)) {
    return Failure(InvalidTransition(from: request.status, to: to, actor: by));
  }
  return Success(request.copyWith(status: to, revisions: revisions));
}

Result<CollaborationRequest> cancelByClient(CollaborationRequest request) =>
    _move(request, to: RequestStatus.cancelled, by: Actor.client, rule: canCancelByClient(request));

Result<CollaborationRequest> confirmDelivery(CollaborationRequest request) =>
    _move(request, to: RequestStatus.completed, by: Actor.client);

Result<CollaborationRequest> requestRevision(CollaborationRequest request) => _move(
  request,
  to: RequestStatus.inProgress,
  by: Actor.client,
  rule: withinRevisionLimit(request),
  revisions: request.revisions + 1,
);

Result<CollaborationRequest> moderatorCancel(CollaborationRequest request) =>
    _move(request, to: RequestStatus.cancelled, by: Actor.moderator, rule: moderatorCanCancel(request));

Result<CollaborationRequest> moderatorClose(CollaborationRequest request) =>
    _move(request, to: RequestStatus.completed, by: Actor.moderator, rule: moderatorCanClose(request));

Result<CollaborationRequest> moderatorReopen(CollaborationRequest request) =>
    _move(request, to: RequestStatus.inProgress, by: Actor.moderator, rule: moderatorCanReopen(request));

/// Pravi novi zahtev u stanju „poslat“ ako pružalac prima zahteve, nudi uslugu i ima mesta.
Result<CollaborationRequest> createRequest(
  NewRequest draft, {
  required Provider provider,
  required Iterable<CollaborationRequest> existing,
  required RequestId id,
  required DateTime now,
}) {
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
