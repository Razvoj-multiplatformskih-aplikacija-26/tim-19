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

/// Akcija nad zahtevom: klijent otkazuje, potvrđuje isporuku ili traži reviziju; pružalac prihvata ili odbija.
final class RequestActionRequested extends RequestsEvent {
  const RequestActionRequested(this.action, this.id);

  final RequestAction action;
  final RequestId id;
}

/// Klijent otkazuje svoj zahtev.
final class CancelRequest extends RequestActionRequested {
  const CancelRequest(RequestId id) : super(RequestAction.cancel, id);
}

/// Ekran je prikazao obaveštenje, pa ga stanje više ne nosi.
final class RequestsNoticeShown extends RequestsEvent {
  const RequestsNoticeShown();
}
