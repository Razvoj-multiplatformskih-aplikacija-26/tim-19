import 'json.dart';

abstract final class RoleDto {
  static const client = 'client';
  static const provider = 'provider';
  static const moderator = 'moderator';
}

/// Aplikacija u koju se korisnik prijavljuje; server po njoj odbija pogrešnu ulogu (`wrong-app`).
abstract final class AppDto {
  static const mobile = 'mobile';
  static const backoffice = 'backoffice';
}

final class UserDto {
  const UserDto({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'role': role};

  factory UserDto.fromJson(Map<String, Object?> json) =>
      UserDto(id: jsonString(json, 'id'), name: jsonString(json, 'name'), role: jsonString(json, 'role'));
}

/// Telo za `POST /api/v1/sessions`. Pregledač traži prijavu u HttpOnly kolačiću ([cookie]), ostali token u telu.
final class LoginDto {
  const LoginDto({required this.username, required this.password, required this.app, this.cookie = false});

  final String username;
  final String password;
  final String app;
  final bool cookie;

  Map<String, Object?> toJson() => {'username': username, 'password': password, 'app': app, 'cookie': cookie};

  factory LoginDto.fromJson(Map<String, Object?> json) => LoginDto(
    username: jsonString(json, 'username'),
    password: jsonString(json, 'password'),
    app: jsonString(json, 'app'),
    cookie: json['cookie'] == true,
  );
}

/// Prijava koju je izdao server. [token] postoji samo kada prijava nije u kolačiću.
final class SessionDto {
  const SessionDto({required this.user, required this.expiresAt, this.token});

  final UserDto user;
  final DateTime expiresAt;
  final String? token;

  Map<String, Object?> toJson() => {'user': user.toJson(), 'expiresAt': instantToJson(expiresAt), 'token': ?token};

  factory SessionDto.fromJson(Map<String, Object?> json) => SessionDto(
    user: UserDto.fromJson(jsonObject(json['user'])),
    expiresAt: jsonInstant(json, 'expiresAt'),
    token: jsonOptionalString(json, 'token'),
  );
}
