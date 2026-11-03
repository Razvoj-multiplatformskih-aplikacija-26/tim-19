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
  const RequestsLoaded({required this.items, required this.providers, this.notice, this.busyId});

  /// Zahtevi klijenta, najnoviji prvi.
  final List<CollaborationRequest> items;
  final Map<ProviderId, Provider> providers;
  final RequestsNotice? notice;

  /// Zahtev koji se upravo otkazuje.
  final RequestId? busyId;

  bool get isBusy => busyId != null;

  CollaborationRequest? byId(RequestId id) => items.where((r) => r.id == id).firstOrNull;

  Provider? providerOf(CollaborationRequest request) => providers[request.providerId];

  /// Pravilo iz domena odlučuje da li se nudi dugme za otkazivanje.
  bool canCancel(CollaborationRequest request) => canCancelByClient(request).isSuccess;

  /// Zašto aktivan zahtev više ne može da se otkaže; `null` za poslat ili završen zahtev.
  DomainError? whyNotCancellable(CollaborationRequest request) =>
      request.status.isFinal ? null : canCancelByClient(request).errorOrNull;

  RequestsLoaded copyWith({required RequestsNotice? notice, RequestId? busyId}) =>
      RequestsLoaded(items: items, providers: providers, notice: notice, busyId: busyId);

  @override
  List<Object?> get props => [items, providers, notice, busyId];
}

sealed class RequestsNotice extends Equatable {
  const RequestsNotice();

  @override
  List<Object?> get props => const [];
}

final class RequestCancelled extends RequestsNotice {
  const RequestCancelled(this.request);

  final CollaborationRequest request;

  @override
  List<Object?> get props => [request];
}

/// Pravilo iz domena ili port je odbio otkazivanje.
final class CancelRejected extends RequestsNotice {
  const CancelRejected(this.error);

  final DomainError error;

  @override
  List<Object?> get props => [error];
}

/// Port nije odgovorio.
final class CancelFailed extends RequestsNotice {
  const CancelFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}
