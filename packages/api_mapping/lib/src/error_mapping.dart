import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import 'catalog_mapping.dart';
import 'request_mapping.dart';
import 'user_mapping.dart';

/// Server: greška pravila postaje HTTP odgovor sa kodom i podacima pravila. Switch je iscrpan, pa nova greška
/// u domenu ne prolazi analizu dok ne dobije kôd.
extension DomainErrorMapping on DomainError {
  ProblemDto toProblem() => switch (this) {
    InvalidTransition(:final from, :final to, :final role) => ProblemDto(
      status: 409,
      code: ErrorCodes.invalidTransition,
      title: 'Invalid transition',
      from: from.toDto(),
      to: to.toDto(),
      role: role.toDto(),
    ),
    CancelNotAllowed(:final status) => ProblemDto(
      status: 409,
      code: ErrorCodes.cancelNotAllowed,
      title: 'Cancel not allowed',
      state: status.toDto(),
    ),
    RevisionLimitReached(:final max) => ProblemDto(
      status: 409,
      code: ErrorCodes.revisionLimitReached,
      title: 'Revision limit reached',
      max: max,
    ),
    NoFreeSlots(:final capacity) => ProblemDto(
      status: 409,
      code: ErrorCodes.noFreeSlots,
      title: 'No free slots',
      max: capacity,
    ),
    NoteTooLong(:final length, :final max) => ProblemDto(
      status: 422,
      code: ErrorCodes.noteTooLong,
      title: 'Note too long',
      value: length,
      max: max,
    ),
    NoteEmpty() => const ProblemDto(status: 422, code: ErrorCodes.noteEmpty, title: 'Note empty'),
    ProviderNotListed() => const ProblemDto(
      status: 422,
      code: ErrorCodes.providerNotListed,
      title: 'Provider not listed',
    ),
    ServiceNotOffered(:final service) => ProblemDto(
      status: 422,
      code: ErrorCodes.serviceNotOffered,
      title: 'Service not offered',
      service: service.toDto(),
    ),
    RequestClosed(:final status) => ProblemDto(
      status: 409,
      code: ErrorCodes.requestClosed,
      title: 'Request closed',
      state: status.toDto(),
    ),
    NotDelivered(:final status) => ProblemDto(
      status: 409,
      code: ErrorCodes.notDelivered,
      title: 'Request not delivered',
      state: status.toDto(),
    ),
    NotFound() => const ProblemDto(status: 404, code: ErrorCodes.notFound, title: 'Not found'),
    NotAllowed() => const ProblemDto(status: 403, code: ErrorCodes.notAllowed, title: 'Not allowed'),
    WrongApp(:final app) => ProblemDto(status: 403, code: ErrorCodes.wrongApp, title: 'Wrong app', app: app.toDto()),
    StaleRequest(:final current) => ProblemDto(
      status: 409,
      code: ErrorCodes.staleRequest,
      title: 'Request changed meanwhile',
      state: current.toDto(),
    ),
    // Greška koju je klijent dobio sa servera; server je ne šalje, ali kôd ostaje isti.
    ServerRejected(:final code) => ProblemDto(status: 409, code: code, title: 'Rejected'),
  };
}

/// Klijent: greška sa servera postaje ista greška iz domena, pa korisnik vidi istu poruku kao kada pravilo
/// proveri sam. Kôd ili podatke koje ova verzija ne poznaje daje kao [ServerRejected], nikad kao izuzetak.
extension ProblemMapping on ProblemDto {
  DomainError toDomainError() => _known() ?? ServerRejected(code);

  DomainError? _known() {
    final state = _status(this.state);
    final from = _status(this.from);
    final to = _status(this.to);
    final role = this.role == null ? null : roleFromDto(this.role!);
    final service = this.service == null ? null : serviceFromDto(this.service!);
    final app = this.app == null ? null : appFromDto(this.app!);
    return switch (code) {
      ErrorCodes.invalidTransition when from != null && to != null && role != null => InvalidTransition(
        from: from,
        to: to,
        role: role,
      ),
      ErrorCodes.cancelNotAllowed when state != null => CancelNotAllowed(state),
      ErrorCodes.revisionLimitReached when max != null => RevisionLimitReached(max: max!),
      ErrorCodes.noFreeSlots when max != null => NoFreeSlots(capacity: max!),
      ErrorCodes.noteTooLong when value != null && max != null => NoteTooLong(value!, max: max!),
      ErrorCodes.noteEmpty => const NoteEmpty(),
      ErrorCodes.providerNotListed => const ProviderNotListed(),
      ErrorCodes.serviceNotOffered when service != null => ServiceNotOffered(service),
      ErrorCodes.requestClosed when state != null => RequestClosed(state),
      ErrorCodes.notDelivered when state != null => NotDelivered(state),
      ErrorCodes.notFound => const NotFound(),
      ErrorCodes.notAllowed => const NotAllowed(),
      ErrorCodes.wrongApp when app != null => WrongApp(app),
      ErrorCodes.staleRequest when state != null => StaleRequest(state),
      _ => null,
    };
  }

  static RequestStatus? _status(String? value) => value == null ? null : statusFromDto(value);
}
