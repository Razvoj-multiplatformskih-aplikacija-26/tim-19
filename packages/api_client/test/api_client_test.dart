import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Lažni server: beleži pozive i vraća ono što test zada.
final class FakeServer {
  final calls = <http.Request>[];
  http.Response Function(http.Request request) answer = (_) => http.Response('{}', 200);

  http.Client get client => MockClient((request) async {
    calls.add(request);
    return answer(request);
  });
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': status >= 400 ? ProblemDto.mediaType : 'application/json'},
);

final createdAt = DateTime.utc(2026, 11, 3, 12);

Map<String, Object?> requestJson(String id, String status) => RequestDto(
  id: id,
  clientId: 'c-sava',
  providerId: 'p-ana',
  service: ServiceDto.mastering,
  note: 'Mastering',
  status: status,
  createdAt: createdAt,
  revisions: 0,
).toJson();

void main() {
  late FakeServer server;
  late MemoryTokenStore tokens;

  ApiClient api({bool cookie = false, Duration timeout = const Duration(seconds: 2)}) => ApiClient(
    baseUri: Uri.parse('http://localhost:8080'),
    tokens: tokens,
    httpClient: server.client,
    keepsSessionInCookie: cookie,
    timeout: timeout,
  );

  setUp(() {
    server = FakeServer();
    tokens = MemoryTokenStore();
  });

  group('prijava', () {
    test('uspeh čuva token iza porta i vraća korisnika; lozinka se ne čuva', () async {
      server.answer = (_) => jsonResponse(
        SessionDto(
          user: const UserDto(id: 'c-sava', name: 'Sava', role: RoleDto.client),
          expiresAt: createdAt,
          token: 'tok',
        ).toJson(),
        201,
      );
      final result = await HttpSessionRepository(api())
          .signIn(username: 'klijent1', password: 'tajna', app: ClientApp.mobile);
      expect(result.valueOrNull, const User(id: UserId('c-sava'), name: 'Sava', role: Role.client));
      expect(await tokens.read(), 'tok');
      final sent = jsonDecode(server.calls.single.body) as Map<String, Object?>;
      expect([sent['app'], sent['cookie']], [AppDto.mobile, false]);
    });

    test('pogrešna lozinka i pogrešna aplikacija su greške iz domena, bez tokena', () async {
      server.answer = (_) =>
          jsonResponse(const ProblemDto(status: 401, code: ErrorCodes.invalidCredentials, title: 'x').toJson(), 401);
      final sessions = HttpSessionRepository(api());
      expect(
        (await sessions.signIn(username: 'a', password: 'b', app: ClientApp.mobile)).errorOrNull,
        const InvalidCredentials(),
      );
      server.answer = (_) => jsonResponse(
        const ProblemDto(status: 403, code: ErrorCodes.wrongApp, title: 'x', app: AppDto.backoffice).toJson(),
        403,
      );
      expect(
        (await sessions.signIn(username: 'klijent1', password: 'b', app: ClientApp.backoffice)).errorOrNull,
        const WrongApp(ClientApp.backoffice),
      );
      expect(await tokens.read(), isNull);
    });

    test('bez sačuvanog tokena nema poziva serveru; istekla prijava briše token', () async {
      final sessions = HttpSessionRepository(api());
      expect(await sessions.current(), isNull);
      expect(server.calls, isEmpty);

      await tokens.write('star');
      server.answer = (_) =>
          jsonResponse(const ProblemDto(status: 401, code: ErrorCodes.sessionExpired, title: 'x').toJson(), 401);
      expect(await sessions.current(), isNull);
      expect(await tokens.read(), isNull);
    });

    test('odjava briše token i kada server nije dostupan', () async {
      await tokens.write('tok');
      server.answer = (_) => throw http.ClientException('nema mreže');
      await HttpSessionRepository(api()).signOut();
      expect(await tokens.read(), isNull);
    });

    test('pregledač: bez zaglavlja Authorization, prijava traži kolačić', () async {
      await tokens.write('ne-sme-da-ode');
      server.answer = (_) => jsonResponse(
        SessionDto(
          user: const UserDto(id: 'm-kosta', name: 'Kosta', role: RoleDto.moderator),
          expiresAt: createdAt,
        ).toJson(),
        201,
      );
      await HttpSessionRepository(api(cookie: true))
          .signIn(username: 'moderator1', password: 'x', app: ClientApp.backoffice);
      expect(server.calls.single.headers['Authorization'], isNull);
      expect((jsonDecode(server.calls.single.body) as Map<String, Object?>)['cookie'], isTrue);
    });
  });

  group('zahtevi', () {
    test('šalje token, čita stranu i preskače stanje koje ne poznaje', () async {
      await tokens.write('tok');
      server.answer = (_) => jsonResponse(
        PageDto(
          items: [requestJson('r-1', RequestStatusDto.sent), requestJson('r-2', 'archived')],
          total: 2,
          limit: 50,
          offset: 0,
        ).toJson((item) => item),
      );
      final page = await HttpRequestsRepository(api()).requests(status: RequestStatus.sent, limit: 50);
      expect(page.items.map((r) => r.id), [const RequestId('r-1')]);
      expect(page.total, 2);
      final call = server.calls.single;
      expect(call.headers['Authorization'], 'Bearer tok');
      expect(call.url.queryParameters, {'limit': '50', 'offset': '0', 'status': 'sent'});
    });

    test('akcija ide na svoju putanju sa stanjem koje je korisnik video', () async {
      server.answer = (_) => jsonResponse(requestJson('r-1', RequestStatusDto.cancelled));
      final result = await HttpRequestsRepository(api())
          .apply(RequestAction.cancel, const RequestId('r-1'), from: RequestStatus.sent);
      expect(result.valueOrNull?.status, RequestStatus.cancelled);
      expect(server.calls.single.url.path, '/api/v1/requests/r-1/cancellation');
      expect(jsonDecode(server.calls.single.body), {'from': 'sent'});
    });

    test('pravilo koje je proverio server stiže kao ista greška iz domena, sa granicom', () async {
      server.answer = (_) => jsonResponse(
        const ProblemDto(status: 422, code: ErrorCodes.noteTooLong, title: 'x', value: 501, max: 500).toJson(),
        422,
      );
      const draft = NewRequest(
        clientId: ClientId('c-sava'),
        providerId: ProviderId('p-ana'),
        service: ServiceType.mastering,
        note: 'x',
      );
      final result = await HttpRequestsRepository(api()).create(draft);
      expect(result.errorOrNull, const NoteTooLong(501, max: 500));
      expect(jsonDecode(server.calls.single.body), isNot(contains('clientId')));
    });

    test('stara verzija: nepoznat kôd je ServerRejected, ne izuzetak', () async {
      server.answer = (_) =>
          jsonResponse(const ProblemDto(status: 422, code: 'deadline-too-close', title: 'x').toJson(), 422);
      final result = await HttpRequestsRepository(api())
          .apply(RequestAction.cancel, const RequestId('r-1'), from: RequestStatus.sent);
      expect(result.errorOrNull, const ServerRejected('deadline-too-close'));
    });

    test('tuđ ili nepostojeći zahtev je null', () async {
      server.answer = (_) =>
          jsonResponse(const ProblemDto(status: 403, code: ErrorCodes.notAllowed, title: 'x').toJson(), 403);
      expect(await HttpRequestsRepository(api()).getById(const RequestId('r-7')), isNull);
    });
  });

  test('katalog nosi slobodna mesta koja je izračunao server', () async {
    server.answer = (_) => jsonResponse([
      const ProviderDto(
        id: 'p-jelena',
        name: 'Jelena',
        verified: true,
        genres: [GenreDto.pop],
        services: [ServiceDto.vocals],
        priceFrom: 60,
        capacity: 3,
        freeSlots: 1,
      ).toJson(),
    ]);
    final entries = await HttpProvidersRepository(api()).catalog();
    expect(entries.single.freeSlots, 1);
    expect(entries.single.provider.services, [ServiceType.vocals]);
  });

  group('kada server nije dostupan, ekran to kaže', () {
    Future<RepositoryFailure> failureOf(Future<Object?> Function() call) async {
      try {
        await call();
      } on RepositoryException catch (error) {
        return error.failure;
      }
      fail('Očekivan RepositoryException');
    }

    test('nema mreže ili server ne radi', () async {
      server.answer = (_) => throw http.ClientException('Connection refused');
      expect(await failureOf(() => HttpProvidersRepository(api()).catalog()), RepositoryFailure.unreachable);
    });

    test('server ne odgovara na vreme: nema učitavanja bez kraja', () async {
      final slow = MockClient((_) => Completer<http.Response>().future);
      final client = ApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        httpClient: slow,
        keepsSessionInCookie: false,
        timeout: const Duration(milliseconds: 50),
      );
      expect(await failureOf(() => HttpProvidersRepository(client).catalog()), RepositoryFailure.unreachable);
    });

    test('greška servera i nečitljiv odgovor', () async {
      server.answer = (_) => http.Response('oops', 500);
      expect(await failureOf(() => HttpProvidersRepository(api()).catalog()), RepositoryFailure.serverError);
      server.answer = (_) => http.Response('{"nije": "lista"}', 200);
      expect(await failureOf(() => HttpProvidersRepository(api()).catalog()), RepositoryFailure.serverError);
    });

    test('istekla prijava u bilo kom pozivu javlja se aplikaciji', () async {
      final client = api();
      final expired = client.expirations.first;
      server.answer = (_) =>
          jsonResponse(const ProblemDto(status: 401, code: ErrorCodes.sessionExpired, title: 'x').toJson(), 401);
      expect(await failureOf(() => HttpRequestsRepository(client).requests()), RepositoryFailure.sessionExpired);
      await expired;
    });
  });
}
