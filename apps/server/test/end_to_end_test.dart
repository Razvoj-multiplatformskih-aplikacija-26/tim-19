@Tags(['db'])
library;

import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support.dart';

// Isti kôd koji koriste mobilna i backoffice (api_client), nad pravim serverom i bazom.

late Pool<void> database;
late TestServer server;

ApiClient client() => ApiClient(baseUri: server.base, keepsSessionInCookie: false);

void main() {
  setUpAll(() async {
    database = await freshTestDatabase('soundconnect_test_e2e');
    await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);
    server = await TestServer.start(database);
  });

  tearDownAll(() async {
    await server.close();
    await database.close();
  });

  test('klijent: prijava, katalog, zahtev, ista greška pravila kao u domenu, otkazivanje', () async {
    final api = client();
    final sessions = HttpSessionRepository(api);
    final user = (await sessions.signIn(
      username: 'klijent1',
      password: demoPassword,
      app: ClientApp.mobile,
    )).valueOrNull!;
    expect(user.id, const UserId('c-sava'));
    expect(await sessions.current(), user);

    final catalog = await HttpProvidersRepository(api).catalog();
    expect(catalog.firstWhere((e) => e.provider.id == const ProviderId('p-jelena')).freeSlots, 1);

    final requests = HttpRequestsRepository(api);
    final draft = NewRequest(
      clientId: user.asClient,
      providerId: const ProviderId('p-ana'),
      service: ServiceType.mastering,
      note: 'a' * (maxNoteLength + 1),
    );
    // Ista greška koju bi forma dobila od pravila u domenu.
    expect((await requests.create(draft)).errorOrNull, noteWithinLength(draft.note).errorOrNull);

    final created = (await requests.create(
      NewRequest(clientId: user.asClient, providerId: draft.providerId, service: draft.service, note: 'Mastering'),
    )).valueOrNull!;
    final cancelled = await requests.apply(RequestAction.cancel, created.id, from: RequestStatus.sent);
    expect(cancelled.valueOrNull?.status, RequestStatus.cancelled);

    final mine = await requests.requests();
    expect(mine.items.every((r) => r.clientId == user.asClient), isTrue);

    await sessions.signOut();
    expect(await sessions.current(), isNull);
  });

  test('moderator vidi sve, klijent u backoffice-u dobija WrongApp', () async {
    final moderator = client();
    await HttpSessionRepository(moderator)
        .signIn(username: 'moderator1', password: demoPassword, app: ClientApp.backoffice);
    expect((await HttpRequestsRepository(moderator).requests(limit: 5)).total, greaterThanOrEqualTo(20));
    expect(await HttpClientsRepository(moderator).allClients(), hasLength(6));

    final wrong = await HttpSessionRepository(client())
        .signIn(username: 'klijent1', password: demoPassword, app: ClientApp.backoffice);
    expect(wrong.errorOrNull, const WrongApp(ClientApp.backoffice));
  });
}
