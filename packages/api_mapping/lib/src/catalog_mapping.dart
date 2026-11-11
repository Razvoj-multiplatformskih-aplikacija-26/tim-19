import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

extension GenreMapping on Genre {
  String toDto() => switch (this) {
    Genre.pop => GenreDto.pop,
    Genre.hipHop => GenreDto.hipHop,
    Genre.rnb => GenreDto.rnb,
    Genre.rock => GenreDto.rock,
    Genre.electronic => GenreDto.electronic,
    Genre.jazz => GenreDto.jazz,
    Genre.folk => GenreDto.folk,
  };
}

/// Žanr sa mreže; `null` za žanr koji ova verzija ne poznaje.
Genre? genreFromDto(String value) => switch (value) {
  GenreDto.pop => Genre.pop,
  GenreDto.hipHop => Genre.hipHop,
  GenreDto.rnb => Genre.rnb,
  GenreDto.rock => Genre.rock,
  GenreDto.electronic => Genre.electronic,
  GenreDto.jazz => Genre.jazz,
  GenreDto.folk => Genre.folk,
  _ => null,
};

extension ServiceTypeMapping on ServiceType {
  String toDto() => switch (this) {
    ServiceType.mixing => ServiceDto.mixing,
    ServiceType.mastering => ServiceDto.mastering,
    ServiceType.vocals => ServiceDto.vocals,
    ServiceType.beat => ServiceDto.beat,
  };
}

/// Usluga sa mreže; `null` za uslugu koju ova verzija ne poznaje.
ServiceType? serviceFromDto(String value) => switch (value) {
  ServiceDto.mixing => ServiceType.mixing,
  ServiceDto.mastering => ServiceType.mastering,
  ServiceDto.vocals => ServiceType.vocals,
  ServiceDto.beat => ServiceType.beat,
  _ => null,
};

extension ProviderMapping on Provider {
  /// [freeSlots] računa server istim pravilom iz domena (`freeSlots`) nad zahtevima svih klijenata.
  ProviderDto toDto({required int freeSlots}) => ProviderDto(
    id: id.value,
    name: name,
    verified: verified,
    genres: [for (final genre in genres) genre.toDto()],
    services: [for (final service in services) service.toDto()],
    priceFrom: priceFrom,
    capacity: capacity,
    freeSlots: freeSlots,
    bio: bio,
  );
}

extension ProviderDtoMapping on ProviderDto {
  /// Žanrove i usluge koje ova verzija ne poznaje preskače, da stara aplikacija ne padne.
  Provider toDomain() => Provider(
    id: ProviderId(id),
    name: name,
    verified: verified,
    genres: [...genres.map(genreFromDto).nonNulls],
    services: [...services.map(serviceFromDto).nonNulls],
    priceFrom: priceFrom,
    capacity: capacity,
    bio: bio,
  );
}

extension ClientMapping on Client {
  ClientDto toDto() => ClientDto(id: id.value, name: name);
}

extension ClientDtoMapping on ClientDto {
  Client toDomain() => Client(id: ClientId(id), name: name);
}
