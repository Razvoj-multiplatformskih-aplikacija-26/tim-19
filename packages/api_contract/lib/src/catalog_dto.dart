import 'json.dart';

/// Žanrovi na mreži. Klijent preskače žanr koji ne poznaje.
abstract final class GenreDto {
  static const pop = 'pop';
  static const hipHop = 'hip-hop';
  static const rnb = 'rnb';
  static const rock = 'rock';
  static const electronic = 'electronic';
  static const jazz = 'jazz';
  static const folk = 'folk';
}

/// Usluge na mreži.
abstract final class ServiceDto {
  static const mixing = 'mixing';
  static const mastering = 'mastering';
  static const vocals = 'vocals';
  static const beat = 'beat';
}

/// Pružalac u katalogu. Cena je ceo broj evra; [freeSlots] računa server nad zahtevima svih klijenata,
/// jer klijent tuđe zahteve ne vidi.
final class ProviderDto {
  const ProviderDto({
    required this.id,
    required this.name,
    required this.verified,
    required this.genres,
    required this.services,
    required this.priceFrom,
    required this.capacity,
    required this.freeSlots,
    this.bio = '',
  });

  final String id;
  final String name;
  final bool verified;
  final List<String> genres;
  final List<String> services;
  final int priceFrom;
  final int capacity;
  final int freeSlots;
  final String bio;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'verified': verified,
    'genres': genres,
    'services': services,
    'priceFrom': priceFrom,
    'capacity': capacity,
    'freeSlots': freeSlots,
    'bio': bio,
  };

  factory ProviderDto.fromJson(Map<String, Object?> json) => ProviderDto(
    id: jsonString(json, 'id'),
    name: jsonString(json, 'name'),
    verified: jsonBool(json, 'verified'),
    genres: jsonStrings(json, 'genres'),
    services: jsonStrings(json, 'services'),
    priceFrom: jsonInt(json, 'priceFrom'),
    capacity: jsonInt(json, 'capacity'),
    freeSlots: jsonInt(json, 'freeSlots'),
    bio: jsonOptionalString(json, 'bio') ?? '',
  );
}

/// Klijent sa imenom; listu klijenata vidi samo moderator.
final class ClientDto {
  const ClientDto({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory ClientDto.fromJson(Map<String, Object?> json) =>
      ClientDto(id: jsonString(json, 'id'), name: jsonString(json, 'name'));
}
