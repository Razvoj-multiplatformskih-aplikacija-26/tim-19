import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Nalog sa hešom lozinke; postoji samo na serveru.
final class Account {
  const Account({required this.user, required this.passwordHash});

  final User user;
  final String passwordHash;
}

final class AccountStore {
  const AccountStore(this._database);

  final Pool<void> _database;

  Future<Account?> account(String login) async {
    final rows = await _database.execute(
      Sql.named('SELECT id, name, role, password_hash FROM users WHERE login = @login AND password_hash IS NOT NULL'),
      parameters: {'login': login},
    );
    if (rows.isEmpty) return null;
    final [id, name, role, hash] = rows.single;
    return Account(
      user: User(id: UserId(id! as String), name: name! as String, role: Role.values.byName(role! as String)),
      passwordHash: hash! as String,
    );
  }
}
