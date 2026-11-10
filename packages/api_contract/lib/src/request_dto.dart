import 'json.dart';

/// Stanja zahteva na mreži, kao čitljiv tekst. Stara aplikacija mora da preživi stanje koje ne poznaje.
abstract final class RequestStatusDto {
  static const sent = 'sent';
  static const accepted = 'accepted';
  static const inProgress = 'in-progress';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
}

/// Zahtev za saradnju. Vreme je ISO 8601 u UTC.
final class RequestDto {
  const RequestDto({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.service,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.revisions,
  });

  final String id;
  final String clientId;
  final String providerId;
  final String service;
  final String note;
  final String status;
  final DateTime createdAt;
  final int revisions;

  Map<String, Object?> toJson() => {
    'id': id,
    'clientId': clientId,
    'providerId': providerId,
    'service': service,
    'note': note,
    'status': status,
    'createdAt': instantToJson(createdAt),
    'revisions': revisions,
  };

  factory RequestDto.fromJson(Map<String, Object?> json) => RequestDto(
    id: jsonString(json, 'id'),
    clientId: jsonString(json, 'clientId'),
    providerId: jsonString(json, 'providerId'),
    service: jsonString(json, 'service'),
    note: jsonString(json, 'note'),
    status: jsonString(json, 'status'),
    createdAt: jsonInstant(json, 'createdAt'),
    revisions: jsonInt(json, 'revisions'),
  );
}

/// Telo za `POST /api/v1/requests`. Klijenta nema u telu: server ga zna samo iz prijave.
final class NewRequestDto {
  const NewRequestDto({required this.providerId, required this.service, required this.note});

  final String providerId;
  final String service;
  final String note;

  Map<String, Object?> toJson() => {'providerId': providerId, 'service': service, 'note': note};

  factory NewRequestDto.fromJson(Map<String, Object?> json) => NewRequestDto(
    providerId: jsonString(json, 'providerId'),
    service: jsonString(json, 'service'),
    note: jsonString(json, 'note'),
  );
}

/// Telo akcije nad zahtevom: stanje koje je korisnik video. Ako se u međuvremenu promenilo, server vraća
/// `stale-request` umesto da menja zahtev za koji korisnik nije znao.
final class ActionDto {
  const ActionDto({required this.from});

  final String from;

  Map<String, Object?> toJson() => {'from': from};

  factory ActionDto.fromJson(Map<String, Object?> json) => ActionDto(from: jsonString(json, 'from'));
}
