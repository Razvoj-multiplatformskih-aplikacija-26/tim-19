import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Deo liste zahteva i ukupan broj zapisa koji odgovaraju filteru.
typedef RequestPage = ({List<CollaborationRequest> items, int total});

/// Čitanje i upis u bazu. Pravila ovde nema: proverava ih domen pre upisa.
final class SoundStore {
  const SoundStore(this._database);

  final Session _database;

  Future<bool> isEmpty() async {
    final rows = await _database.execute('SELECT count(*) FROM users');
    return rows.single[0] == 0;
  }

  // Pružaoci i klijenti.

  static const _providerColumns = 'id, name, verified, genres, services, price_from, capacity, bio';

  Future<List<Provider>> providers() async {
    final rows = await _database.execute('SELECT $_providerColumns FROM providers ORDER BY name');
    return [for (final row in rows) _provider(row.toColumnMap())];
  }

  /// Pružalac; sa [lock] red ostaje zaključan do kraja transakcije, pa se istovremeni zahtevi za istog pružaoca
  /// obrađuju jedan po jedan (pravilo o slobodnim mestima).
  Future<Provider?> provider(ProviderId id, {bool lock = false}) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_providerColumns FROM providers WHERE id = @id${lock ? ' FOR UPDATE' : ''}'),
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : _provider(rows.single.toColumnMap());
  }

  Future<List<Client>> clients() async {
    final rows = await _database.execute("SELECT id, name FROM users WHERE role = 'client' ORDER BY name");
    return [for (final row in rows) Client(id: ClientId(row[0]! as String), name: row[1]! as String)];
  }

  // Zahtevi.

  static const _requestColumns = 'id, client_id, provider_id, service, note, status, revisions, created_at';

  /// Zahtevi koji zauzimaju mesto; [providerId] ograničava na jednog pružaoca.
  Future<List<CollaborationRequest>> activeRequests({ProviderId? providerId}) async {
    final active = [for (final s in RequestStatus.values.where((s) => s.occupiesSlot)) s.name];
    final rows = await _database.execute(
      Sql.named(
        'SELECT $_requestColumns FROM requests WHERE status = ANY(@active)'
        '${providerId == null ? '' : ' AND provider_id = @provider'}',
      ),
      parameters: {'active': TypedValue(Type.textArray, active), 'provider': ?providerId?.value},
    );
    return [for (final row in rows) _request(row.toColumnMap())];
  }

  /// Strana zahteva, najnoviji prvi. Filteri koji su `null` se ne primenjuju.
  Future<RequestPage> requests({
    ClientId? clientId,
    ProviderId? providerId,
    RequestStatus? status,
    required int limit,
    required int offset,
  }) async {
    final where = [
      if (clientId != null) 'client_id = @client',
      if (providerId != null) 'provider_id = @provider',
      if (status != null) 'status = @status',
    ];
    final filter = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final parameters = {'client': ?clientId?.value, 'provider': ?providerId?.value, 'status': ?status?.name};
    final total = await _database.execute(Sql.named('SELECT count(*) FROM requests $filter'), parameters: parameters);
    final rows = await _database.execute(
      Sql.named(
        'SELECT $_requestColumns FROM requests $filter ORDER BY created_at DESC, id LIMIT @limit OFFSET @offset',
      ),
      parameters: {...parameters, 'limit': limit, 'offset': offset},
    );
    return (items: [for (final row in rows) _request(row.toColumnMap())], total: total.single[0]! as int);
  }

  /// Zahtev; sa [lock] red ostaje zaključan do kraja transakcije (istovremene akcije nad istim zahtevom).
  Future<CollaborationRequest?> request(RequestId id, {bool lock = false}) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_requestColumns FROM requests WHERE id = @id${lock ? ' FOR UPDATE' : ''}'),
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : _request(rows.single.toColumnMap());
  }

  /// Upisuje novi zahtev koji je odobrio domen; baza mu daje sledeći broj (`r-21` …).
  Future<CollaborationRequest> insertNew(CollaborationRequest request) async {
    final rows = await _database.execute(
      Sql.named(
        'INSERT INTO requests (client_id, provider_id, service, note, status, revisions, created_at, updated_at) '
        'VALUES (@client, @provider, @service, @note, @status, @revisions, @created, @created) '
        'RETURNING $_requestColumns',
      ),
      parameters: _requestParameters(request),
    );
    return _request(rows.single.toColumnMap());
  }

  /// Upis zahteva sa zadatim identifikatorom (početni podaci).
  Future<void> insertRequest(CollaborationRequest request) => _database.execute(
    Sql.named(
      'INSERT INTO requests (id, client_id, provider_id, service, note, status, revisions, created_at, updated_at) '
      'VALUES (@id, @client, @provider, @service, @note, @status, @revisions, @created, @created)',
    ),
    parameters: {'id': request.id.value, ..._requestParameters(request)},
  );

  /// Čuva novo stanje i broj revizija koje je odobrio domen.
  Future<void> updateRequest(CollaborationRequest request, {required DateTime now}) => _database.execute(
    Sql.named('UPDATE requests SET status = @status, revisions = @revisions, updated_at = @now WHERE id = @id'),
    parameters: {
      'id': request.id.value,
      'status': request.status.name,
      'revisions': request.revisions,
      'now': now.toUtc(),
    },
  );

  // Početni podaci.

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

  /// Novi zahtevi nastavljaju numeraciju posle početnih (`r-21`, `r-22` …).
  Future<void> continueRequestNumbersAfter(int last) =>
      _database.execute(Sql.named("SELECT setval('request_numbers', @last)"), parameters: {'last': last});

  Future<int> countRequests() async => (await _database.execute('SELECT count(*) FROM requests')).single[0]! as int;
}

Map<String, Object?> _requestParameters(CollaborationRequest request) => {
  'client': request.clientId.value,
  'provider': request.providerId.value,
  'service': request.service.name,
  'note': request.note,
  'status': request.status.name,
  'revisions': request.revisions,
  'created': request.createdAt.toUtc(),
};

Provider _provider(Map<String, Object?> row) => Provider(
  id: ProviderId(row['id']! as String),
  name: row['name']! as String,
  verified: row['verified']! as bool,
  genres: [for (final g in row['genres']! as List<Object?>) Genre.values.byName(g! as String)],
  services: [for (final s in row['services']! as List<Object?>) ServiceType.values.byName(s! as String)],
  priceFrom: row['price_from']! as int,
  capacity: row['capacity']! as int,
  bio: row['bio']! as String,
);

CollaborationRequest _request(Map<String, Object?> row) => CollaborationRequest(
  id: RequestId(row['id']! as String),
  clientId: ClientId(row['client_id']! as String),
  providerId: ProviderId(row['provider_id']! as String),
  service: ServiceType.values.byName(row['service']! as String),
  note: row['note']! as String,
  status: RequestStatus.values.byName(row['status']! as String),
  revisions: row['revisions']! as int,
  createdAt: (row['created_at']! as DateTime).toUtc(),
);
