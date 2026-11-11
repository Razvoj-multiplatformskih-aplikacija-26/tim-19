import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

extension RoleMapping on Role {
  String toDto() => switch (this) {
    Role.client => RoleDto.client,
    Role.provider => RoleDto.provider,
    Role.moderator => RoleDto.moderator,
  };
}

/// Uloga sa mreže; `null` za ulogu koju ova verzija ne poznaje.
Role? roleFromDto(String value) => switch (value) {
  RoleDto.client => Role.client,
  RoleDto.provider => Role.provider,
  RoleDto.moderator => Role.moderator,
  _ => null,
};

extension ClientAppMapping on ClientApp {
  String toDto() => switch (this) {
    ClientApp.mobile => AppDto.mobile,
    ClientApp.backoffice => AppDto.backoffice,
  };
}

/// Aplikacija sa mreže; `null` za nepoznatu.
ClientApp? appFromDto(String value) => switch (value) {
  AppDto.mobile => ClientApp.mobile,
  AppDto.backoffice => ClientApp.backoffice,
  _ => null,
};

extension UserMapping on User {
  UserDto toDto() => UserDto(id: id.value, name: name, role: role.toDto());
}

extension UserDtoMapping on UserDto {
  /// Korisnik bez poznate uloge ne može da se prijavi; oblik odgovora je pogrešan.
  User toDomain() =>
      User(id: UserId(id), name: name, role: roleFromDto(role) ?? (throw FormatException('Nepoznata uloga', role)));
}
