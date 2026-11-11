@Tags(['db'])
library;

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/src/passwords.dart';
import 'package:test/test.dart';

import 'support.dart';

late Pool<void> database;

void main() {
  setUpAll(() async {
    database = await freshTestDatabase('soundconnect_test_seed');
    expect(await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword), isTrue);
  });

  tearDownAll(() => database.close());

  test('bar deset zahteva i svako stanje bar jednom', () async {
    final rows = await database.execute('SELECT status, count(*) FROM requests GROUP BY status');
    final byStatus = {for (final row in rows) row[0]! as String: row[1]! as int};
    expect(byStatus.values.fold(0, (a, b) => a + b), greaterThanOrEqualTo(10));
    expect(
      byStatus.keys,
      unorderedEquals(['sent', 'accepted', 'inProgress', 'delivered', 'completed', 'rejected', 'cancelled']),
    );
  });

  test('nalog za svaku ulogu i bar dva naloga za mobilnu aplikaciju', () async {
    final rows = await database.execute('SELECT role, count(*) FROM users WHERE login IS NOT NULL GROUP BY role');
    final byRole = {for (final row in rows) row[0]! as String: row[1]! as int};
    expect(byRole.keys, unorderedEquals(['client', 'provider', 'moderator']));
    expect(byRole['client']! + byRole['provider']!, greaterThanOrEqualTo(2));
    expect(byRole['client'], greaterThanOrEqualTo(2));
  });

  test('lozinke su samo Argon2id heš, a demo lozinka prolazi proveru', () async {
    final rows = await database.execute('SELECT password_hash FROM users WHERE login IS NOT NULL');
    for (final row in rows) {
      final hash = row[0]! as String;
      expect(hash, startsWith(r'$argon2id$'));
      expect(hash, isNot(contains(demoPassword)));
    }
    expect(await verifyPassword(demoPassword, rows.first[0]! as String), isTrue);
    expect(await verifyPassword('pogresna', rows.first[0]! as String), isFalse);
  });

  test('nalog pružaoca ima isti identifikator kao profil u katalogu', () async {
    final rows = await database.execute(
      "SELECT p.id FROM users u JOIN providers p ON p.id = u.id WHERE u.role = 'provider' AND u.login IS NOT NULL",
    );
    expect(rows, isNotEmpty);
  });

  test('novi zahtev nastavlja numeraciju posle početnih', () async {
    final rows = await database.execute(
      'INSERT INTO requests (client_id, provider_id, service, note, status, created_at, updated_at) '
      "VALUES ('c-sava', 'p-ana', 'mastering', 'Proba', 'sent', now(), now()) RETURNING id",
    );
    expect(rows.single[0], 'r-21');
    await database.execute("DELETE FROM requests WHERE id = 'r-21'");
  });

  test('ponovno pokretanje ne puni bazu dvaput', () async {
    expect(await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword), isFalse);
    expect(await SoundStore(database).countRequests(), 20);
  });

  test('baza odbija stanje koje ne postoji', () async {
    expect(
      () => database.execute("UPDATE requests SET status = 'archived' WHERE id = 'r-1'"),
      throwsA(isA<ServerException>()),
    );
  });

  test('/health odgovara kada baza radi', () async {
    final server = await TestServer.start(database);
    addTearDown(server.close);
    final answer = await http.get(server.uri('/health'));
    expect([answer.statusCode, answer.body], [200, 'ok']);
    final missing = await http.get(server.uri('/nema'));
    expect(missing.statusCode, 404);
    expect(missing.headers['content-type'], startsWith('application/problem+json'));
  });
}
