@Tags(['db'])
library;

import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support.dart';

// Početni podaci (seed.dart): klijent1 = c-sava (r-1 … r-5), klijent2 = c-mila (r-6 … r-8),
// pruzalac1 = p-marko (r-1, r-4, r-6, r-15), moderator1 vidi sve.

late Pool<void> database;
late TestServer server;
late Map<String, String> sava;
late Map<String, String> mila;
late Map<String, String> marko;
late Map<String, String> kosta;

Future<http.Response> get(String path, Map<String, String> headers, [Map<String, String>? query]) =>
    http.get(server.uri(path, query), headers: headers);

Future<http.Response> send(Map<String, String> headers, NewRequestDto body) =>
    http.post(server.uri(ApiPaths.requests), headers: headers, body: jsonEncode(body.toJson()));

Future<http.Response> act(String path, Map<String, String> headers, {required String from}) => http.post(
  server.uri(path),
  headers: headers,
  body: jsonEncode(ActionDto(from: from).toJson()),
);

RequestDto requestOf(http.Response answer) => RequestDto.fromJson(bodyOf(answer));

PageDto<RequestDto> pageOf(http.Response answer) => PageDto.fromJson(bodyOf(answer), RequestDto.fromJson);

void expectProblem(http.Response answer, int status, String code) {
  expect(answer.statusCode, status, reason: answer.body);
  expect(codeOf(answer), code, reason: answer.body);
}

void main() {
  setUpAll(() async {
    database = await freshTestDatabase('soundconnect_test_requests');
    await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);
    server = await TestServer.start(database);
    sava = bearer(await server.tokenOf('klijent1'));
    mila = bearer(await server.tokenOf('klijent2'));
    marko = bearer(await server.tokenOf('pruzalac1'));
    kosta = bearer(await server.tokenOf('moderator1', app: AppDto.backoffice));
  });

  tearDownAll(() async {
    await server.close();
    await database.close();
  });

  group('katalog', () {
    test('javan je, samo verifikovani pružaoci, sa slobodnim mestima koja računa server', () async {
      final answer = await get(ApiPaths.providers, const {});
      expect(answer.statusCode, 200);
      final providers = {
        for (final p in jsonDecode(answer.body) as List<Object?>)
          (p! as Map<String, Object?>)['id']: ProviderDto.fromJson(p as Map<String, Object?>),
      };
      expect(providers.keys, isNot(contains('p-novi')));
      expect(providers['p-marko']!.freeSlots, 0);
      expect(providers['p-jelena']!.freeSlots, 1);
      expect(providers['p-djole']!.freeSlots, 0);
    });

    test('moderator vidi i neverifikovane pružaoce', () async {
      final answer = await get(ApiPaths.providers, kosta);
      expect(answer.body, contains('p-novi'));
      expect((await get(ApiPaths.provider('p-novi'), const {})).statusCode, 404);
      expect((await get(ApiPaths.provider('p-novi'), kosta)).statusCode, 200);
    });

    test('klijente vidi samo moderator', () async {
      expectProblem(await get(ApiPaths.clients, sava), 403, ErrorCodes.notAllowed);
      final answer = await get(ApiPaths.clients, kosta);
      expect(jsonDecode(answer.body) as List<Object?>, hasLength(6));
    });
  });

  group('šta od zapisa vidi koja uloga', () {
    test('klijent vidi samo svoje zahteve', () async {
      final page = pageOf(await get(ApiPaths.requests, sava));
      expect(page.total, 5);
      expect(page.items.map((r) => r.clientId).toSet(), {'c-sava'});
    });

    test('pružalac vidi samo zahteve upućene njemu', () async {
      final page = pageOf(await get(ApiPaths.requests, marko));
      expect(page.items.map((r) => r.id), unorderedEquals(['r-1', 'r-4', 'r-6', 'r-15']));
    });

    test('moderator vidi sve, po stranama i po stanju', () async {
      final first = pageOf(await get(ApiPaths.requests, kosta, {ApiQuery.limit: '5'}));
      expect([first.total, first.items.length, first.hasMore], [20, 5, true]);
      final last = pageOf(await get(ApiPaths.requests, kosta, {ApiQuery.limit: '5', ApiQuery.offset: '15'}));
      expect([last.items.length, last.hasMore], [5, false]);
      expect({...first.items.map((r) => r.id)}.intersection({...last.items.map((r) => r.id)}), isEmpty);
      final delivered = pageOf(await get(ApiPaths.requests, kosta, {ApiQuery.status: RequestStatusDto.delivered}));
      expect(delivered.items.map((r) => r.id), unorderedEquals(['r-4', 'r-5', 'r-10', 'r-16']));
    });

    test('tuđ zahtev se ne vidi ni preko identifikatora', () async {
      expectProblem(await get(ApiPaths.request('r-7'), sava), 403, ErrorCodes.notAllowed);
      expect((await get(ApiPaths.request('r-7'), mila)).statusCode, 200);
      expectProblem(await get(ApiPaths.request('r-999'), kosta), 404, ErrorCodes.notFound);
    });

    test('pogrešni parametri liste su 400', () async {
      expectProblem(await get(ApiPaths.requests, kosta, {ApiQuery.limit: '0'}), 400, ErrorCodes.badRequest);
      expectProblem(await get(ApiPaths.requests, kosta, {ApiQuery.limit: 'sto'}), 400, ErrorCodes.badRequest);
      expectProblem(await get(ApiPaths.requests, kosta, {ApiQuery.status: 'archived'}), 400, ErrorCodes.badRequest);
    });

    test('bez prijave nema zahteva', () async {
      expectProblem(await get(ApiPaths.requests, const {}), 401, ErrorCodes.signInRequired);
    });
  });

  group('novi zahtev: ista pravila kao na klijentu', () {
    test('predugačka napomena: isti kôd i granica', () async {
      final answer = await send(
        sava,
        NewRequestDto(providerId: 'p-ana', service: ServiceDto.mastering, note: 'a' * 501),
      );
      expectProblem(answer, 422, ErrorCodes.noteTooLong);
      expect([bodyOf(answer)['value'], bodyOf(answer)['max']], [501, maxNoteLength]);
    });

    test('prazna napomena, usluga koju pružalac ne nudi, neverifikovan pružalac', () async {
      expectProblem(
        await send(sava, const NewRequestDto(providerId: 'p-ana', service: ServiceDto.mastering, note: '   ')),
        422,
        ErrorCodes.noteEmpty,
      );
      final vocals = await send(sava, const NewRequestDto(providerId: 'p-ana', service: ServiceDto.vocals, note: 'x'));
      expectProblem(vocals, 422, ErrorCodes.serviceNotOffered);
      expect(bodyOf(vocals)['service'], ServiceDto.vocals);
      expectProblem(
        await send(sava, const NewRequestDto(providerId: 'p-novi', service: ServiceDto.beat, note: 'Bit')),
        422,
        ErrorCodes.providerNotListed,
      );
    });

    test('pružalac bez slobodnih mesta', () async {
      final answer = await send(
        sava,
        const NewRequestDto(providerId: 'p-marko', service: ServiceDto.mixing, note: 'x'),
      );
      expectProblem(answer, 409, ErrorCodes.noFreeSlots);
      expect(bodyOf(answer)['max'], 3);
    });

    test('klijent je onaj iz prijave, ne iz tela; server šalje obaveštenje pružaocu', () async {
      final answer = await http.post(
        server.uri(ApiPaths.requests),
        headers: sava,
        body: jsonEncode({
          ...const NewRequestDto(
            providerId: 'p-ana',
            service: ServiceDto.mastering,
            note: '  Mastering singla  ',
          ).toJson(),
          'clientId': 'c-mila',
        }),
      );
      expect(answer.statusCode, 201, reason: answer.body);
      final created = requestOf(answer);
      expect([created.clientId, created.status, created.note], ['c-sava', RequestStatusDto.sent, 'Mastering singla']);
      expect(created.id, startsWith('r-'));
      expect(server.notifications.sent.last, (request: RequestId(created.id), provider: const ProviderId('p-ana')));
    });

    test('pružalac i moderator ne šalju zahteve', () async {
      for (final headers in [marko, kosta]) {
        expectProblem(
          await send(headers, const NewRequestDto(providerId: 'p-nikola', service: ServiceDto.beat, note: 'Bit')),
          403,
          ErrorCodes.notAllowed,
        );
      }
    });
  });

  group('akcije klijenta', () {
    test('otkazuje svoj poslat zahtev', () async {
      final created = requestOf(
        await send(sava, const NewRequestDto(providerId: 'p-nikola', service: ServiceDto.beat, note: 'Bit')),
      );
      final answer = await act(ApiPaths.cancellation(created.id), sava, from: RequestStatusDto.sent);
      expect(answer.statusCode, 200, reason: answer.body);
      expect(requestOf(answer).status, RequestStatusDto.cancelled);
    });

    test('ne otkazuje prihvaćen zahtev: isto pravilo i kôd kao u aplikaciji', () async {
      final answer = await act(ApiPaths.cancellation('r-2'), sava, from: RequestStatusDto.accepted);
      expectProblem(answer, 409, ErrorCodes.cancelNotAllowed);
      expect(bodyOf(answer)['state'], RequestStatusDto.accepted);
    });

    test('tuđ zahtev ne može da otkaže', () async {
      expectProblem(
        await act(ApiPaths.cancellation('r-7'), sava, from: RequestStatusDto.sent),
        403,
        ErrorCodes.notAllowed,
      );
    });

    test('akcije moderatora mimo aplikacije odbija server', () async {
      for (final path in [ApiPaths.closure('r-4'), ApiPaths.reopening('r-4')]) {
        expectProblem(await act(path, sava, from: RequestStatusDto.delivered), 403, ErrorCodes.notAllowed);
      }
    });

    test('zahtev promenjen u međuvremenu: stale-request sa trenutnim stanjem', () async {
      final answer = await act(ApiPaths.cancellation('r-3'), sava, from: RequestStatusDto.sent);
      expectProblem(answer, 409, ErrorCodes.staleRequest);
      expect(bodyOf(answer)['state'], RequestStatusDto.inProgress);
    });

    test('revizija troši jednu, a posle poslednje ostaje samo potvrda isporuke', () async {
      final revised = await act(ApiPaths.revision('r-4'), sava, from: RequestStatusDto.delivered);
      expect([requestOf(revised).status, requestOf(revised).revisions], [RequestStatusDto.inProgress, 1]);
      final limit = await act(ApiPaths.revision('r-5'), sava, from: RequestStatusDto.delivered);
      expectProblem(limit, 409, ErrorCodes.revisionLimitReached);
      expect(bodyOf(limit)['max'], maxRevisions);
      final completed = await act(ApiPaths.completion('r-5'), sava, from: RequestStatusDto.delivered);
      expect(requestOf(completed).status, RequestStatusDto.completed);
    });

    test('nepoznato stanje u telu je 400, bez prijave 401', () async {
      expectProblem(await act(ApiPaths.cancellation('r-1'), sava, from: 'archived'), 400, ErrorCodes.badRequest);
      expectProblem(
        await act(ApiPaths.cancellation('r-1'), const {'Content-Type': 'application/json'}, from: 'sent'),
        401,
        ErrorCodes.signInRequired,
      );
    });
  });

  group('akcije pružaoca', () {
    test('ne dira zahtev upućen drugom pružaocu', () async {
      expectProblem(
        await act(ApiPaths.rejection('r-7'), marko, from: RequestStatusDto.sent),
        403,
        ErrorCodes.notAllowed,
      );
    });

    test('prihvata poslat zahtev upućen njemu', () async {
      final answer = await act(ApiPaths.acceptance('r-1'), marko, from: RequestStatusDto.sent);
      expect(requestOf(answer).status, RequestStatusDto.accepted);
    });

    test('ne otkazuje zahtev kao klijent', () async {
      expectProblem(
        await act(ApiPaths.cancellation('r-6'), marko, from: RequestStatusDto.inProgress),
        403,
        ErrorCodes.notAllowed,
      );
    });
  });

  group('akcije moderatora', () {
    test('otkazuje zahtev u izradi, zatvara i vraća u izradu isporučen bez trošenja revizije', () async {
      expect(requestOf(await act(ApiPaths.cancellation('r-14'), kosta, from: 'in-progress')).status, 'cancelled');
      expect(requestOf(await act(ApiPaths.closure('r-16'), kosta, from: 'delivered')).status, 'completed');
      final reopened = requestOf(await act(ApiPaths.reopening('r-10'), kosta, from: 'delivered'));
      expect([reopened.status, reopened.revisions], ['in-progress', 1]);
    });

    test('završen zahtev se više ne menja; zatvara se samo isporučen', () async {
      final closed = await act(ApiPaths.cancellation('r-8'), kosta, from: RequestStatusDto.completed);
      expectProblem(closed, 409, ErrorCodes.requestClosed);
      expectProblem(await act(ApiPaths.closure('r-6'), kosta, from: 'in-progress'), 409, ErrorCodes.notDelivered);
    });

    test('promena iz jednog klijenta vidi se u drugom posle osvežavanja', () async {
      await act(ApiPaths.cancellation('r-12'), kosta, from: RequestStatusDto.sent);
      final seen = pageOf(await get(ApiPaths.requests, kosta, {ApiQuery.status: RequestStatusDto.cancelled}));
      expect(seen.items.map((r) => r.id), contains('r-12'));
    });
  });
}
