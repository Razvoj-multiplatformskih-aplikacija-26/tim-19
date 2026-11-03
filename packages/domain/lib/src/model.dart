import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'catalog.dart';
import 'identifiers.dart';
import 'request_status.dart';

const _listEquality = ListEquality<Object?>();

@immutable
final class Client {
  const Client({required this.id, required this.name});

  final ClientId id;
  final String name;

  @override
  bool operator ==(Object other) => other is Client && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Client(${id.value}, $name)';
}

@immutable
final class Moderator {
  const Moderator({required this.id, required this.name});

  final ModeratorId id;
  final String name;

  @override
  bool operator ==(Object other) => other is Moderator && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Moderator(${id.value}, $name)';
}

/// Pružalac usluga: producent, audio inženjer ili vokalista.
@immutable
final class Provider {
  const Provider({
    required this.id,
    required this.name,
    required this.verified,
    required this.genres,
    required this.services,
    required this.priceFrom,
    required this.capacity,
    this.bio = '',
  });

  final ProviderId id;
  final String name;

  /// Moderator je verifikovao profil; tek tada je pružalac u katalogu.
  final bool verified;
  final List<Genre> genres;
  final List<ServiceType> services;

  /// Najniža cena usluge, u evrima.
  final int priceFrom;

  /// Najveći broj zahteva koji istovremeno zauzimaju mesto.
  final int capacity;
  final String bio;

  @override
  bool operator ==(Object other) =>
      other is Provider &&
      other.id == id &&
      other.name == name &&
      other.verified == verified &&
      _listEquality.equals(other.genres, genres) &&
      _listEquality.equals(other.services, services) &&
      other.priceFrom == priceFrom &&
      other.capacity == capacity &&
      other.bio == bio;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    verified,
    _listEquality.hash(genres),
    _listEquality.hash(services),
    priceFrom,
    capacity,
    bio,
  );

  @override
  String toString() => 'Provider(${id.value}, $name)';
}

/// Glavni pojam sistema: zahtev klijenta za saradnju sa pružaocem.
@immutable
final class CollaborationRequest {
  const CollaborationRequest({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.service,
    required this.note,
    required this.status,
    required this.createdAt,
    this.revisions = 0,
  });

  final RequestId id;
  final ClientId clientId;
  final ProviderId providerId;
  final ServiceType service;
  final String note;
  final RequestStatus status;
  final DateTime createdAt;

  /// Koliko je puta klijent vratio isporučen zahtev na doradu.
  final int revisions;

  CollaborationRequest copyWith({RequestStatus? status, int? revisions}) => CollaborationRequest(
    id: id,
    clientId: clientId,
    providerId: providerId,
    service: service,
    note: note,
    status: status ?? this.status,
    createdAt: createdAt,
    revisions: revisions ?? this.revisions,
  );

  @override
  bool operator ==(Object other) =>
      other is CollaborationRequest &&
      other.id == id &&
      other.clientId == clientId &&
      other.providerId == providerId &&
      other.service == service &&
      other.note == note &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.revisions == revisions;

  @override
  int get hashCode => Object.hash(id, clientId, providerId, service, note, status, createdAt, revisions);

  @override
  String toString() => 'CollaborationRequest(${id.value}, ${status.name}, revisions: $revisions)';
}

/// Podaci koje klijent unosi u formu za novi zahtev.
@immutable
final class NewRequest {
  const NewRequest({required this.clientId, required this.providerId, required this.service, required this.note});

  final ClientId clientId;
  final ProviderId providerId;
  final ServiceType service;
  final String note;

  @override
  bool operator ==(Object other) =>
      other is NewRequest &&
      other.clientId == clientId &&
      other.providerId == providerId &&
      other.service == service &&
      other.note == note;

  @override
  int get hashCode => Object.hash(clientId, providerId, service, note);
}
