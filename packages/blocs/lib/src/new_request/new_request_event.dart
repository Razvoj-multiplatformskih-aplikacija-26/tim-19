part of 'new_request_bloc.dart';

sealed class NewRequestEvent {
  const NewRequestEvent();
}

final class NoteChanged extends NewRequestEvent {
  const NoteChanged(this.text);

  final String text;
}

final class ServiceChanged extends NewRequestEvent {
  const ServiceChanged(this.service);

  final ServiceType service;
}

final class SubmitNewRequest extends NewRequestEvent {
  const SubmitNewRequest();
}
