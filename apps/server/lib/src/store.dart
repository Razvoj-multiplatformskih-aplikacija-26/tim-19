import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Čitanje i upis u bazu. Pravila ovde nema: proverava ih domen pre upisa.
final class SoundStore {
  const SoundStore(this._database);

  final Session _database;

  Future<bool> isEmpty() async {
    final rows = await _database.execute('SELECT count(*) FROM users');
    return rows.single[0] == 0;
  }

  Future<void> insertUser(User user, {String? login, String? passwordHash}) => _database.execute(
    Sql.named('INSERT INTO users (id, name, role, login, password_hash) VALUES (@id, @name, @role, @login, @hash)'),
    parameters: {'id': user.id.value, 'name': user.name, 'role': user.role.name, 'login': login, 'hash': passwordHash},
  );

  Future<void> insertProvider(Provider provider) => _database.execute(
    Sql.named(
      'INSERT INTO providers (id, name, verified, genres, services, price_from, capacity, bio) '
      'VALUES (@id, @name, @verified, @genres, @services, @price, @capacity, @bio)',
    ),
    parameters: {
      'id': provider.id.value,
      'name': provider.name,
      'verified': provider.verified,
      'genres': TypedValue(Type.textArray, [for (final g in provider.genres) g.name]),
      'services': TypedValue(Type.textArray, [for (final s in provider.services) s.name]),
      'price': provider.priceFrom,
      'capacity': provider.capacity,
      'bio': provider.bio,
    },
  );

  /// Upis zahteva sa zadatim identifikatorom (početni podaci).
  Future<void> insertRequest(CollaborationRequest request) => _database.execute(
    Sql.named(
      'INSERT INTO requests (id, client_id, provider_id, service, note, status, revisions, created_at, updated_at) '
      'VALUES (@id, @client, @provider, @service, @note, @status, @revisions, @created, @created)',
    ),
    parameters: {
      'id': request.id.value,
      'client': request.clientId.value,
      'provider': request.providerId.value,
      'service': request.service.name,
      'note': request.note,
      'status': request.status.name,
      'revisions': request.revisions,
      'created': request.createdAt.toUtc(),
    },
  );

  /// Novi zahtevi nastavljaju numeraciju posle početnih (`r-21`, `r-22` …).
  Future<void> continueRequestNumbersAfter(int last) =>
      _database.execute(Sql.named('SELECT setval(\'request_numbers\', @last)'), parameters: {'last': last});

  Future<int> countRequests() async => (await _database.execute('SELECT count(*) FROM requests')).single[0]! as int;
}
