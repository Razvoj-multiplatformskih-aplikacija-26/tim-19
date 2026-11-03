import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('cancelByClient', () {
    test('otkazuje poslat zahtev', () {
      expect(cancelByClient(request()).valueOrNull?.status, RequestStatus.cancelled);
    });

    test('ne otkazuje prihvaćen zahtev', () {
      expect(
        cancelByClient(request(status: RequestStatus.accepted)).errorOrNull,
        const CancelNotAllowed(RequestStatus.accepted),
      );
    });
  });

  group('revizije', () {
    test('vraćanje na doradu povećava broj revizija', () {
      final next = requestRevision(request(status: RequestStatus.delivered)).valueOrNull!;
      expect(next.status, RequestStatus.inProgress);
      expect(next.revisions, 1);
    });

    test('posle $maxRevisions revizije klijent može samo da potvrdi isporuku', () {
      final used = request(status: RequestStatus.delivered, revisions: maxRevisions);
      expect(requestRevision(used).errorOrNull, const RevisionLimitReached(max: maxRevisions));
      expect(confirmDelivery(used).valueOrNull?.status, RequestStatus.completed);
    });

    test('revizija je moguća samo iz isporučenog zahteva', () {
      expect(
        requestRevision(request(status: RequestStatus.accepted)).errorOrNull,
        const InvalidTransition(from: RequestStatus.accepted, to: RequestStatus.inProgress, actor: Actor.client),
      );
    });
  });

  group('moderator', () {
    test('otkazuje zahtev u izradi', () {
      expect(moderatorCancel(request(status: RequestStatus.inProgress)).valueOrNull?.status, RequestStatus.cancelled);
    });

    test('ne menja završen zahtev', () {
      expect(
        moderatorCancel(request(status: RequestStatus.completed)).errorOrNull,
        const RequestClosed(RequestStatus.completed),
      );
    });

    test('zatvara isporučen zahtev kao završen', () {
      expect(moderatorClose(request(status: RequestStatus.delivered)).valueOrNull?.status, RequestStatus.completed);
    });

    test('vraća isporučen zahtev u izradu bez trošenja revizije', () {
      final next = moderatorReopen(request(status: RequestStatus.delivered, revisions: 1)).valueOrNull!;
      expect(next.status, RequestStatus.inProgress);
      expect(next.revisions, 1);
    });

    test('ne zatvara zahtev koji nije isporučen', () {
      expect(
        moderatorClose(request(status: RequestStatus.inProgress)).errorOrNull,
        const NotDelivered(RequestStatus.inProgress),
      );
    });
  });

  group('createRequest', () {
    const draft = NewRequest(
      clientId: ClientId('c-1'),
      providerId: ProviderId('p-1'),
      service: ServiceType.mixing,
      note: '  Miks singla  ',
    );

    Result<CollaborationRequest> create(
      NewRequest draft, {
      Provider to = provider,
      List<CollaborationRequest>? existing,
    }) =>
        createRequest(draft, provider: to, existing: existing ?? const [], id: const RequestId('new'), now: createdAt);

    test('pravi poslat zahtev sa očišćenom napomenom', () {
      final created = create(draft).valueOrNull!;
      expect(created.status, RequestStatus.sent);
      expect(created.note, 'Miks singla');
      expect(created.revisions, 0);
    });

    test('odbija neverifikovanog pružaoca', () {
      expect(create(draft, to: unverified).errorOrNull, const ProviderNotListed());
    });

    test('odbija uslugu koju pružalac ne nudi', () {
      const vocals = NewRequest(
        clientId: ClientId('c-1'),
        providerId: ProviderId('p-1'),
        service: ServiceType.vocals,
        note: 'Vokal',
      );
      expect(create(vocals).errorOrNull, const ServiceNotOffered(ServiceType.vocals));
    });

    test('odbija predugu napomenu', () {
      final long = NewRequest(
        clientId: draft.clientId,
        providerId: draft.providerId,
        service: draft.service,
        note: 'a' * (maxNoteLength + 1),
      );
      expect(create(long).errorOrNull, const NoteTooLong(maxNoteLength + 1, max: maxNoteLength));
    });

    test('odbija kada pružalac nema slobodnih mesta', () {
      final full = [for (var i = 0; i < provider.capacity; i++) request(id: 'r$i', clientId: ClientId('c-$i'))];
      expect(create(draft, existing: full).errorOrNull, const NoFreeSlots(capacity: 3));
    });
  });
}
