import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

/// Isto što se desi na mreži: u tekst i nazad.
Map<String, Object?> overTheWire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final createdAt = DateTime.utc(2026, 11, 3, 12, 48, 1);

  group('JSON tamo i nazad', () {
    test('zahtev', () {
      final dto = RequestDto(
        id: 'r-1',
        clientId: 'c-sava',
        providerId: 'p-marko',
        service: ServiceDto.mixing,
        note: 'Miks singla, 24 traka 🎚️',
        status: RequestStatusDto.inProgress,
        createdAt: createdAt,
        revisions: 1,
      );
      final json = overTheWire(dto.toJson());
      expect(json['createdAt'], '2026-11-03T12:48:01.000Z');
      expect(json['status'], 'in-progress');
      expect(RequestDto.fromJson(json).toJson(), dto.toJson());
    });

    test('pružalac sa slobodnim mestima i cenom kao celim brojem', () {
      const dto = ProviderDto(
        id: 'p-marko',
        name: 'Marko „Mix“ Petrović',
        verified: true,
        genres: [GenreDto.hipHop, GenreDto.rnb],
        services: [ServiceDto.mixing, ServiceDto.mastering],
        priceFrom: 80,
        capacity: 3,
        freeSlots: 1,
        bio: 'Miks i mastering.',
      );
      final json = overTheWire(dto.toJson());
      expect(json['priceFrom'], 80);
      expect(ProviderDto.fromJson(json).toJson(), dto.toJson());
    });

    test('klijent', () {
      const dto = ClientDto(id: 'c-sava', name: 'Sava Radošević');
      expect(ClientDto.fromJson(overTheWire(dto.toJson())).toJson(), dto.toJson());
    });

    test('novi zahtev nema klijenta u telu', () {
      const dto = NewRequestDto(providerId: 'p-marko', service: ServiceDto.mixing, note: 'Miks');
      final json = overTheWire(dto.toJson());
      expect(json.keys, isNot(contains('clientId')));
      expect(NewRequestDto.fromJson(json).toJson(), dto.toJson());
    });

    test('akcija nosi stanje koje je korisnik video', () {
      const dto = ActionDto(from: RequestStatusDto.sent);
      expect(ActionDto.fromJson(overTheWire(dto.toJson())).from, 'sent');
    });

    test('prijava', () {
      const dto = LoginDto(username: 'klijent1', password: 'tajna', app: AppDto.mobile);
      final back = LoginDto.fromJson(overTheWire(dto.toJson()));
      expect(back.toJson(), dto.toJson());
      expect(back.cookie, isFalse);
    });

    test('sesija sa tokenom i bez njega', () {
      const user = UserDto(id: 'c-sava', name: 'Sava', role: RoleDto.client);
      final withToken = SessionDto(user: user, expiresAt: createdAt, token: 'abc');
      final inCookie = SessionDto(user: user, expiresAt: createdAt);
      expect(SessionDto.fromJson(overTheWire(withToken.toJson())).toJson(), withToken.toJson());
      expect(overTheWire(inCookie.toJson()).keys, isNot(contains('token')));
      expect(SessionDto.fromJson(overTheWire(inCookie.toJson())).token, isNull);
    });

    test('strana liste', () {
      const page = PageDto(
        items: [ClientDto(id: 'c-1', name: 'Ana')],
        total: 3,
        limit: 1,
        offset: 1,
      );
      final back = PageDto.fromJson(overTheWire(page.toJson((c) => c.toJson())), ClientDto.fromJson);
      expect(back.items.single.name, 'Ana');
      expect([back.total, back.limit, back.offset], [3, 1, 1]);
      expect(back.hasMore, isTrue);
    });
  });

  group('greška (problem+json)', () {
    test('nosi kôd i podatke pravila, a prazne podatke izostavlja', () {
      const problem = ProblemDto(
        status: 422,
        code: ErrorCodes.noteTooLong,
        title: 'Note too long',
        value: 501,
        max: 500,
      );
      final json = overTheWire(problem.toJson());
      expect(json, {
        'type': 'tag:raf.rs,2026:soundconnect/problem/note-too-long',
        'title': 'Note too long',
        'status': 422,
        'code': 'note-too-long',
        'value': 501,
        'max': 500,
      });
      final back = ProblemDto.fromJson(json);
      expect([back.status, back.code, back.value, back.max], [422, 'note-too-long', 501, 500]);
    });

    test('prelaz nosi stanja i ulogu', () {
      const problem = ProblemDto(
        status: 409,
        code: ErrorCodes.invalidTransition,
        title: 'Invalid transition',
        from: RequestStatusDto.accepted,
        to: RequestStatusDto.cancelled,
        role: RoleDto.client,
      );
      final back = ProblemDto.fromJson(overTheWire(problem.toJson()));
      expect([back.from, back.to, back.role], ['accepted', 'cancelled', 'client']);
    });

    test('nepoznat kôd se čita bez greške (stara aplikacija, novo pravilo)', () {
      final back = ProblemDto.fromJson({'status': 422, 'code': 'novo-pravilo', 'limit': 7});
      expect(back.code, 'novo-pravilo');
      expect(back.title, '');
    });
  });

  group('pogrešan oblik daje FormatException', () {
    test('nedostaje polje', () {
      expect(() => ClientDto.fromJson({'id': 'c-1'}), throwsFormatException);
    });

    test('pogrešan tip', () {
      expect(() => ActionDto.fromJson({'from': 3}), throwsFormatException);
    });

    test('vreme bez zone', () {
      final json = RequestDto(
        id: 'r-1',
        clientId: 'c-1',
        providerId: 'p-1',
        service: ServiceDto.beat,
        note: 'Bit',
        status: RequestStatusDto.sent,
        createdAt: createdAt,
        revisions: 0,
      ).toJson()..['createdAt'] = '2026-11-03T12:48:01';
      expect(() => RequestDto.fromJson(json), throwsFormatException);
    });

    test('lista žanrova sa brojem', () {
      final json = overTheWire(
        const ProviderDto(
          id: 'p',
          name: 'P',
          verified: true,
          genres: [],
          services: [],
          priceFrom: 1,
          capacity: 1,
          freeSlots: 1,
        ).toJson(),
      )..['genres'] = [1];
      expect(() => ProviderDto.fromJson(json), throwsFormatException);
    });
  });

  test('putanje akcija su pod-resursi zahteva', () {
    expect(ApiPaths.cancellation('r-1'), '/api/v1/requests/r-1/cancellation');
    expect(ApiPaths.acceptance('r-1'), '/api/v1/requests/r-1/acceptance');
    expect(ApiPaths.closure('r-1'), '/api/v1/requests/r-1/closure');
  });
}
