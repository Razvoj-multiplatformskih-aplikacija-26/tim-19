part of 'new_request_bloc.dart';

enum NewRequestStatus { editing, submitting, done }

const _keep = Object();

final class NewRequestState extends Equatable {
  const NewRequestState({
    required this.service,
    this.note = '',
    this.noteError,
    this.attempted = false,
    this.status = NewRequestStatus.editing,
    this.created,
    this.submitError,
    this.failure,
  });

  final ServiceType service;
  final String note;

  /// Greška pravila za napomenu, dok korisnik kuca.
  final DomainError? noteError;
  final bool attempted;
  final NewRequestStatus status;
  final CollaborationRequest? created;

  /// Port je odbio zahtev pravilom (npr. nema slobodnih mesta).
  final DomainError? submitError;

  /// Port nije odgovorio.
  final Object? failure;

  int get noteLength => note.trim().length;

  /// Novo stanje; greške slanja se brišu pri svakoj izmeni.
  NewRequestState copyWith({
    ServiceType? service,
    String? note,
    Object? noteError = _keep,
    bool? attempted,
    NewRequestStatus? status,
    CollaborationRequest? created,
    DomainError? submitError,
    Object? failure,
  }) => NewRequestState(
    service: service ?? this.service,
    note: note ?? this.note,
    noteError: identical(noteError, _keep) ? this.noteError : noteError as DomainError?,
    attempted: attempted ?? this.attempted,
    status: status ?? this.status,
    created: created ?? this.created,
    submitError: submitError,
    failure: failure,
  );

  @override
  List<Object?> get props => [service, note, noteError, attempted, status, created, submitError, failure];
}
