import 'package:meta/meta.dart';

import 'catalog.dart';
import 'request_status.dart';
import 'user.dart';

/// Greške pravila kao tipovi. Tekst poruke bira aplikacija.
sealed class DomainError {
  const DomainError();
}

@immutable
final class InvalidTransition extends DomainError {
  const InvalidTransition({required this.from, required this.to, required this.role});

  final RequestStatus from;
  final RequestStatus to;
  final Role role;

  @override
  bool operator ==(Object other) =>
      other is InvalidTransition && other.from == from && other.to == to && other.role == role;

  @override
  int get hashCode => Object.hash(InvalidTransition, from, to, role);

  @override
  String toString() => 'InvalidTransition(${from.name} -> ${to.name} by ${role.name})';
}

/// Klijent otkazuje samo dok pružalac nije prihvatio zahtev.
@immutable
final class CancelNotAllowed extends DomainError {
  const CancelNotAllowed(this.status);

  final RequestStatus status;

  @override
  bool operator ==(Object other) => other is CancelNotAllowed && other.status == status;

  @override
  int get hashCode => Object.hash(CancelNotAllowed, status);

  @override
  String toString() => 'CancelNotAllowed(${status.name})';
}

@immutable
final class RevisionLimitReached extends DomainError {
  const RevisionLimitReached({required this.max});

  final int max;

  @override
  bool operator ==(Object other) => other is RevisionLimitReached && other.max == max;

  @override
  int get hashCode => Object.hash(RevisionLimitReached, max);

  @override
  String toString() => 'RevisionLimitReached(max: $max)';
}

@immutable
final class NoFreeSlots extends DomainError {
  const NoFreeSlots({required this.capacity});

  final int capacity;

  @override
  bool operator ==(Object other) => other is NoFreeSlots && other.capacity == capacity;

  @override
  int get hashCode => Object.hash(NoFreeSlots, capacity);

  @override
  String toString() => 'NoFreeSlots(capacity: $capacity)';
}

@immutable
final class NoteTooLong extends DomainError {
  const NoteTooLong(this.length, {required this.max});

  final int length;
  final int max;

  @override
  bool operator ==(Object other) => other is NoteTooLong && other.length == length && other.max == max;

  @override
  int get hashCode => Object.hash(NoteTooLong, length, max);

  @override
  String toString() => 'NoteTooLong($length, max: $max)';
}

final class NoteEmpty extends DomainError {
  const NoteEmpty();
}

/// Pružalac nije verifikovan, pa nije u katalogu i ne prima zahteve.
final class ProviderNotListed extends DomainError {
  const ProviderNotListed();
}

@immutable
final class ServiceNotOffered extends DomainError {
  const ServiceNotOffered(this.service);

  final ServiceType service;

  @override
  bool operator ==(Object other) => other is ServiceNotOffered && other.service == service;

  @override
  int get hashCode => Object.hash(ServiceNotOffered, service);

  @override
  String toString() => 'ServiceNotOffered(${service.name})';
}

/// Zahtev je završen, odbijen ili otkazan i više ne menja stanje.
@immutable
final class RequestClosed extends DomainError {
  const RequestClosed(this.status);

  final RequestStatus status;

  @override
  bool operator ==(Object other) => other is RequestClosed && other.status == status;

  @override
  int get hashCode => Object.hash(RequestClosed, status);

  @override
  String toString() => 'RequestClosed(${status.name})';
}

@immutable
final class NotDelivered extends DomainError {
  const NotDelivered(this.status);

  final RequestStatus status;

  @override
  bool operator ==(Object other) => other is NotDelivered && other.status == status;

  @override
  int get hashCode => Object.hash(NotDelivered, status);

  @override
  String toString() => 'NotDelivered(${status.name})';
}

final class NotFound extends DomainError {
  const NotFound();
}

/// Korisnik nema pravo na akciju ili zapis (tuđ zahtev, akcija druge uloge).
final class NotAllowed extends DomainError {
  const NotAllowed();
}

/// Korisnik se prijavljuje u aplikaciju koja nije za njegovu ulogu.
@immutable
final class WrongApp extends DomainError {
  const WrongApp(this.app);

  /// Aplikacija u koju je pokušao da se prijavi.
  final ClientApp app;

  @override
  bool operator ==(Object other) => other is WrongApp && other.app == app;

  @override
  int get hashCode => Object.hash(WrongApp, app);

  @override
  String toString() => 'WrongApp(${app.name})';
}

/// Zahtev je u međuvremenu promenio neko drugi; izmena je pravljena nad zastarelim stanjem.
@immutable
final class StaleRequest extends DomainError {
  const StaleRequest(this.current);

  /// Stanje u kome je zahtev sada.
  final RequestStatus current;

  @override
  bool operator ==(Object other) => other is StaleRequest && other.current == current;

  @override
  int get hashCode => Object.hash(StaleRequest, current);

  @override
  String toString() => 'StaleRequest(${current.name})';
}

/// Server je odbio akciju kodom koji ova verzija aplikacije ne poznaje (novo pravilo na serveru).
@immutable
final class ServerRejected extends DomainError {
  const ServerRejected(this.code);

  final String code;

  @override
  bool operator ==(Object other) => other is ServerRejected && other.code == code;

  @override
  int get hashCode => Object.hash(ServerRejected, code);

  @override
  String toString() => 'ServerRejected($code)';
}
