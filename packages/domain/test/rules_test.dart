import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('canCancelByClient', () {
    test('dozvoljava otkazivanje poslatog zahteva', () {
      expect(canCancelByClient(request()).isSuccess, isTrue);
    });

    test('odbija otkazivanje čim pružalac prihvati', () {
      for (final status in RequestStatus.values.where((s) => s != RequestStatus.sent)) {
        expect(canCancelByClient(request(status: status)), Failure<void>(CancelNotAllowed(status)));
      }
    });
  });

  group('withinRevisionLimit', () {
    test('dozvoljava reviziju dok ih ima manje od $maxRevisions', () {
      for (var used = 0; used < maxRevisions; used++) {
        expect(withinRevisionLimit(request(revisions: used)).isSuccess, isTrue);
      }
    });

    test('odbija reviziju posle $maxRevisions', () {
      expect(
        withinRevisionLimit(request(revisions: maxRevisions)),
        const Failure<void>(RevisionLimitReached(max: maxRevisions)),
      );
    });
  });

  group('noteWithinLength', () {
    test('vraća očišćen tekst', () {
      expect(noteWithinLength('  miks  '), const Success('miks'));
    });

    test('prihvata tačno $maxNoteLength znakova', () {
      expect(noteWithinLength('a' * maxNoteLength).isSuccess, isTrue);
    });

    test('odbija duži tekst', () {
      expect(
        noteWithinLength('a' * (maxNoteLength + 1)),
        const Failure<String>(NoteTooLong(maxNoteLength + 1, max: maxNoteLength)),
      );
    });

    test('odbija praznu napomenu', () {
      expect(noteWithinLength('   '), const Failure<String>(NoteEmpty()));
    });
  });

  group('providerHasCapacity', () {
    test('broji samo aktivne zahteve tog pružaoca, svih klijenata', () {
      final requests = [
        request(id: 'a', clientId: const ClientId('c-1')),
        request(id: 'b', clientId: const ClientId('c-2'), status: RequestStatus.inProgress),
        request(id: 'c', status: RequestStatus.completed),
        request(id: 'd', status: RequestStatus.cancelled),
        request(id: 'e', providerId: const ProviderId('p-9')),
      ];
      expect(freeSlots(provider, requests), 1);
      expect(providerHasCapacity(provider, requests), const Success(1));
    });

    test('javlja grešku kada su sva mesta zauzeta', () {
      final requests = [for (var i = 0; i < provider.capacity; i++) request(id: 'r$i', status: RequestStatus.accepted)];
      expect(freeSlots(provider, requests), 0);
      expect(providerHasCapacity(provider, requests), const Failure<int>(NoFreeSlots(capacity: 3)));
    });
  });

  group('katalog', () {
    test('prikazuje samo verifikovane pružaoce', () {
      expect(catalog([provider, unverified]), [provider]);
    });

    test('filtrira po žanru i usluzi', () {
      expect(catalog([provider], genre: Genre.rnb, service: ServiceType.mastering), [provider]);
      expect(catalog([provider], genre: Genre.rock), isEmpty);
      expect(catalog([provider], service: ServiceType.vocals), isEmpty);
    });
  });

  group('moderator', () {
    test('otkazuje svaki zahtev koji nije završen, odbijen ni otkazan', () {
      for (final status in RequestStatus.values) {
        expect(moderatorCanCancel(request(status: status)).isSuccess, !status.isFinal, reason: status.name);
      }
    });

    test('zatvara i vraća u izradu samo isporučen zahtev', () {
      for (final status in RequestStatus.values) {
        final delivered = status == RequestStatus.delivered;
        expect(moderatorCanClose(request(status: status)).isSuccess, delivered, reason: status.name);
        expect(moderatorCanReopen(request(status: status)).isSuccess, delivered, reason: status.name);
      }
    });
  });
}
