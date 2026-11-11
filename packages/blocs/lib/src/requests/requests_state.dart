part of 'requests_bloc.dart';

sealed class RequestsState extends Equatable {
  const RequestsState();

  @override
  List<Object?> get props => const [];
}

final class RequestsLoading extends RequestsState {
  const RequestsLoading();
}

final class RequestsError extends RequestsState {
  const RequestsError(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}

final class RequestsEmpty extends RequestsState {
  const RequestsEmpty();
}

final class RequestsLoaded extends RequestsState {
  const RequestsLoaded({
    required this.items,
    required this.providers,
    this.actions = const {},
    this.notice,
    this.busyId,
  });

  /// Zahtevi koje korisnik vidi (klijent svoje, pružalac upućene njemu), najnoviji prvi.
  final List<CollaborationRequest> items;
  final Map<ProviderId, Provider> providers;

  /// Akcije koje domen dozvoljava prijavljenom korisniku, po zahtevu; ekran nudi samo njih.
  final Map<RequestId, List<RequestAction>> actions;
  final RequestsNotice? notice;

  /// Zahtev nad kojim akcija upravo traje.
  final RequestId? busyId;

  bool get isBusy => busyId != null;

  CollaborationRequest? byId(RequestId id) => items.where((r) => r.id == id).firstOrNull;

  Provider? providerOf(CollaborationRequest request) => providers[request.providerId];

  List<RequestAction> actionsFor(CollaborationRequest request) => actions[request.id] ?? const [];

  /// Pravilo iz domena odlučuje da li se nudi dugme za otkazivanje.
  bool canCancel(CollaborationRequest request) => actionsFor(request).contains(RequestAction.cancel);

  /// Zašto aktivan zahtev više ne može da se otkaže; `null` za poslat ili završen zahtev.
  DomainError? whyNotCancellable(CollaborationRequest request) =>
      request.status.isFinal ? null : canCancelByClient(request).errorOrNull;

  RequestsLoaded copyWith({required RequestsNotice? notice, RequestId? busyId}) =>
      RequestsLoaded(items: items, providers: providers, actions: actions, notice: notice, busyId: busyId);

  @override
  List<Object?> get props => [items, providers, actions, notice, busyId];
}

sealed class RequestsNotice extends Equatable {
  const RequestsNotice(this.action);

  final RequestAction action;

  @override
  List<Object?> get props => [action];
}

final class RequestActionDone extends RequestsNotice {
  const RequestActionDone(super.action, this.request);

  final CollaborationRequest request;

  @override
  List<Object?> get props => [action, request];
}

/// Pravilo je odbilo akciju: domen na klijentu pre slanja, ili server (tada su podaci ponovo učitani).
final class RequestActionRejected extends RequestsNotice {
  const RequestActionRejected(super.action, this.error);

  final DomainError error;

  @override
  List<Object?> get props => [action, error];
}

/// Port nije odgovorio.
final class RequestActionFailed extends RequestsNotice {
  const RequestActionFailed(super.action, this.cause);

  final Object cause;

  @override
  List<Object?> get props => [action, cause];
}
