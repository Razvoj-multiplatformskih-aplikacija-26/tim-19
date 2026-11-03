part of 'requests_bloc.dart';

sealed class RequestsEvent {
  const RequestsEvent();
}

final class LoadRequests extends RequestsEvent {
  const LoadRequests();
}

final class RetryLoad extends RequestsEvent {
  const RetryLoad();
}

final class CancelRequest extends RequestsEvent {
  const CancelRequest(this.id);

  final RequestId id;
}

/// Ekran je prikazao obaveštenje, pa ga stanje više ne nosi.
final class RequestsNoticeShown extends RequestsEvent {
  const RequestsNoticeShown();
}
