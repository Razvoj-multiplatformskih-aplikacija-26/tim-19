import 'package:meta/meta.dart';

import 'identifiers.dart';

/// Uloga korisnika. Klijent i pružalac rade u mobilnoj aplikaciji, moderator u backoffice-u.
enum Role { client, provider, moderator }

/// Aplikacija u koju se korisnik prijavljuje.
enum ClientApp { mobile, backoffice }

/// Prijavljeni korisnik. Klijent i pružalac imaju profil sa istim identifikatorom kao nalog.
@immutable
final class User {
  const User({required this.id, required this.name, required this.role});

  final UserId id;
  final String name;
  final Role role;

  /// Profil klijenta ovog naloga; ima smisla samo za [Role.client].
  ClientId get asClient => ClientId(id.value);

  /// Profil pružaoca ovog naloga; ima smisla samo za [Role.provider].
  ProviderId get asProvider => ProviderId(id.value);

  @override
  bool operator ==(Object other) => other is User && other.id == id && other.name == name && other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);

  @override
  String toString() => 'User(${id.value}, $name, ${role.name})';
}
