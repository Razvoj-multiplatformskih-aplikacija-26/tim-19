@Tags(['db'])
library;

import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support.dart';

late Pool<void> database;
late TestServer server;

Future<http.Response> current(Map<String, String> headers) =>
    http.get(server.uri(ApiPaths.currentSession), headers: headers);

void main() {
  setUpAll(() async {
    database = await freshTestDatabase('soundconnect_test_sessions');
    await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);
    server = await TestServer.start(database);
  });

  tearDownAll(() async {
    await server.close();
    await database.close();
  });

  group('prijava', () {
    test('klijent u mobilnoj dobija token i podatke o sebi', () async {
      final answer = await server.logIn('klijent1');
      expect(answer.statusCode, 201);
      final session = SessionDto.fromJson(bodyOf(answer));
      expect([session.user.id, session.user.role], ['c-sava', RoleDto.client]);
      expect(session.token, isNotEmpty);
      expect(session.expiresAt.difference(DateTime.now()).inMinutes, closeTo(60, 1));
    });

    test('pružalac u mobilnoj i moderator u backoffice-u', () async {
      expect((await server.logIn('pruzalac1')).statusCode, 201);
      expect((await server.logIn('moderator1', app: AppDto.backoffice)).statusCode, 201);
    });

    test('pogrešna lozinka i nepostojeći nalog daju isti odgovor', () async {
      final wrong = await server.logIn('klijent1', password: 'pogresna');
      final missing = await server.logIn('nema-ga');
      for (final answer in [wrong, missing]) {
        expect(answer.statusCode, 401);
        expect(codeOf(answer), ErrorCodes.invalidCredentials);
      }
    });

    test('korisnik mobilne aplikacije ne ulazi u backoffice, i server kaže zašto', () async {
      for (final login in ['klijent1', 'pruzalac1']) {
        final answer = await server.logIn(login, app: AppDto.backoffice);
        expect(answer.statusCode, 403, reason: login);
        expect(codeOf(answer), ErrorCodes.wrongApp);
        expect(bodyOf(answer)['app'], AppDto.backoffice);
      }
    });

    test('moderator ne ulazi u mobilnu aplikaciju', () async {
      final answer = await server.logIn('moderator1');
      expect([answer.statusCode, codeOf(answer)], [403, ErrorCodes.wrongApp]);
    });

    test('pogrešna lozinka u pogrešnoj aplikaciji ne otkriva ulogu naloga', () async {
      final answer = await server.logIn('klijent1', app: AppDto.backoffice, password: 'pogresna');
      expect(codeOf(answer), ErrorCodes.invalidCredentials);
    });

    test('nepoznata aplikacija i pogrešno telo su 400', () async {
      expect((await server.logIn('klijent1', app: 'televizor')).statusCode, 400);
      final notJson = await http.post(server.uri(ApiPaths.sessions), body: 'klijent1');
      expect(notJson.statusCode, 415);
    });
  });

  group('provera prijave pri svakom pozivu', () {
    test('važeći token: server zna ko poziva', () async {
      final answer = await current(bearer(await server.tokenOf('klijent2')));
      expect(answer.statusCode, 200);
      expect(SessionDto.fromJson(bodyOf(answer)).user.id, 'c-mila');
    });

    test('bez prijave: sign-in-required', () async {
      final answer = await current(const {});
      expect([answer.statusCode, codeOf(answer)], [401, ErrorCodes.signInRequired]);
    });

    test('izmenjen token (druga uloga) ne prolazi: server veruje samo svom potpisu', () async {
      final token = await server.tokenOf('klijent1');
      final [header, _, signature] = token.split('.');
      final forged = base64Url
          .encode(utf8.encode(jsonEncode({'sub': 'm-kosta', 'name': 'Kosta', 'role': 'moderator', 'exp': 9999999999})))
          .replaceAll('=', '');
      final answer = await current(bearer('$header.$forged.$signature'));
      expect([answer.statusCode, codeOf(answer)], [401, ErrorCodes.sessionExpired]);
    });

    test('token potpisan tuđom tajnom ili drugim algoritmom ne prolazi', () async {
      final foreign = JWT(
        {'name': 'Sava', 'role': 'client'},
        subject: 'c-sava',
      ).sign(SecretKey('tudja-tajna-0123456789-0123456789-abcdef'), expiresIn: const Duration(hours: 1));
      final none = JWT(
        {'name': 'Sava', 'role': 'client'},
        subject: 'c-sava',
      ).sign(SecretKey(config.jwtSecret), algorithm: JWTAlgorithm.HS512, expiresIn: const Duration(hours: 1));
      for (final token in [foreign, none]) {
        final answer = await current(bearer(token));
        expect(codeOf(answer), ErrorCodes.sessionExpired);
      }
    });

    test('prijava ističe posle vremena iz podešavanja servera', () async {
      final short = await TestServer.start(database, ttl: const Duration(seconds: 1));
      addTearDown(short.close);
      final token = await short.tokenOf('klijent1');
      final fresh = await http.get(short.uri(ApiPaths.currentSession), headers: bearer(token));
      expect(fresh.statusCode, 200);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      final later = await http.get(short.uri(ApiPaths.currentSession), headers: bearer(token));
      expect([later.statusCode, codeOf(later)], [401, ErrorCodes.sessionExpired]);
    });
  });

  group('pregledač: prijava u HttpOnly kolačiću', () {
    test('kolačić umesto tokena, prijava radi, odjava ga briše', () async {
      final answer = await server.logIn('moderator1', app: AppDto.backoffice, cookie: true);
      expect(answer.statusCode, 201);
      expect(bodyOf(answer).keys, isNot(contains('token')));
      final setCookie = answer.headers['set-cookie']!;
      expect(setCookie, contains('${ApiCookies.session}='));
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie.toLowerCase(), contains('samesite=lax'));

      final cookie = setCookie.split(';').first;
      final me = await current({'Cookie': cookie});
      expect(SessionDto.fromJson(bodyOf(me)).user.role, RoleDto.moderator);

      final out = await http.delete(server.uri(ApiPaths.currentSession), headers: {'Cookie': cookie});
      expect(out.statusCode, 204);
      expect(out.headers['set-cookie'], contains('Max-Age=0'));
    });
  });

  group('CORS', () {
    test('dozvoljena adresa dobija dozvolu sa kolačićem', () async {
      final request = http.Request('OPTIONS', server.uri(ApiPaths.sessions))
        ..headers['Origin'] = 'http://localhost:8081'
        ..headers['Access-Control-Request-Method'] = 'POST';
      final answer = await http.Response.fromStream(await request.send());
      expect(answer.headers['access-control-allow-origin'], 'http://localhost:8081');
      expect(answer.headers['access-control-allow-credentials'], 'true');
    });

    test('tuđa adresa ne može da menja podatke', () async {
      final answer = await http.post(
        server.uri(ApiPaths.sessions),
        headers: {'Origin': 'http://zlonamerni.example', 'Content-Type': 'application/json'},
        body: jsonEncode(const LoginDto(username: 'klijent1', password: 'x', app: AppDto.mobile).toJson()),
      );
      expect(answer.statusCode, 403);
      expect(answer.headers['access-control-allow-origin'], isNull);
    });
  });
}
