@Tags(['db'])
library;

import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support.dart';

// Isti posao u istom trenutku iz različitih klijenata: server pušta samo onoliko koliko pravilo dozvoljava.

late Pool<void> database;
late TestServer server;

void main() {
  setUpAll(() async {
    database = await freshTestDatabase('soundconnect_test_race');
    await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);
    server = await TestServer.start(database);
  });

  tearDownAll(() async {
    await server.close();
    await database.close();
  });

  test('šest istovremenih zahteva za poslednje mesto kod Jelene: prolazi tačno jedan', () async {
    final sava = bearer(await server.tokenOf('klijent1'));
    final mila = bearer(await server.tokenOf('klijent2'));
    const body = NewRequestDto(providerId: 'p-jelena', service: ServiceDto.vocals, note: 'Vokal za refren.');

    final answers = await Future.wait([
      for (var i = 0; i < 6; i++)
        http.post(server.uri(ApiPaths.requests), headers: i.isEven ? sava : mila, body: jsonEncode(body.toJson())),
    ]);

    final statuses = answers.map((a) => a.statusCode).toList();
    expect(statuses.where((s) => s == 201), hasLength(1), reason: '$statuses');
    expect(statuses.where((s) => s == 409), hasLength(5), reason: '$statuses');
    for (final late in answers.where((a) => a.statusCode == 409)) {
      expect(codeOf(late), ErrorCodes.noFreeSlots);
      expect(bodyOf(late)['max'], 3);
    }
    final active = await SoundStore(database).activeRequests();
    expect(active.where((r) => r.providerId.value == 'p-jelena'), hasLength(3));
  });

  test('klijent otkazuje dok pružalac prihvata isti zahtev: prolazi jedan, drugi dobija stale-request', () async {
    final sava = bearer(await server.tokenOf('klijent1'));
    final marko = bearer(await server.tokenOf('pruzalac1'));
    final body = jsonEncode(const ActionDto(from: RequestStatusDto.sent).toJson());

    final answers = await Future.wait([
      http.post(server.uri(ApiPaths.cancellation('r-1')), headers: sava, body: body),
      http.post(server.uri(ApiPaths.acceptance('r-1')), headers: marko, body: body),
    ]);

    expect(answers.map((a) => a.statusCode), unorderedEquals([200, 409]));
    final late = answers.firstWhere((a) => a.statusCode == 409);
    expect(codeOf(late), ErrorCodes.staleRequest);
    final winner = RequestDto.fromJson(bodyOf(answers.firstWhere((a) => a.statusCode == 200)));
    expect(bodyOf(late)['state'], winner.status);
  });
}
