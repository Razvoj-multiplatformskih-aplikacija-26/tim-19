import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Akcija iz domena i stanje iz kog ima smisla (da pravilo i prelaz prođu kada pravo postoji).
typedef _Action = ({
  String name,
  RequestStatus from,
  Result<CollaborationRequest> Function(CollaborationRequest, User) run,
});

final List<_Action> _actions = [
  (name: 'otkazivanje klijenta', from: RequestStatus.sent, run: (r, u) => cancelByClient(r, by: u)),
  (name: 'potvrda isporuke', from: RequestStatus.delivered, run: (r, u) => confirmDelivery(r, by: u)),
  (name: 'revizija', from: RequestStatus.delivered, run: (r, u) => requestRevision(r, by: u)),
  (name: 'prihvatanje', from: RequestStatus.sent, run: (r, u) => acceptByProvider(r, by: u)),
  (name: 'odbijanje', from: RequestStatus.sent, run: (r, u) => rejectByProvider(r, by: u)),
  (name: 'otkazivanje moderatora', from: RequestStatus.inProgress, run: (r, u) => moderatorCancel(r, by: u)),
  (name: 'zatvaranje', from: RequestStatus.delivered, run: (r, u) => moderatorClose(r, by: u)),
  (name: 'vraćanje u izradu', from: RequestStatus.delivered, run: (r, u) => moderatorReopen(r, by: u)),
];

/// Ko sme koju akciju nad zahtevom `r-1` (klijent `c-1`, pružalac `p-1`). Ostali dobijaju [NotAllowed].
final _allowed = {
  'otkazivanje klijenta': {owner},
  'potvrda isporuke': {owner},
  'revizija': {owner},
  'prihvatanje': {addressee},
  'odbijanje': {addressee},
  'otkazivanje moderatora': {moderator},
  'zatvaranje': {moderator},
  'vraćanje u izradu': {moderator},
};

void main() {
  const users = [owner, otherClient, addressee, otherProvider, moderator];

  group('prava na akcije', () {
    for (final action in _actions) {
      for (final user in users) {
        final allowed = _allowed[action.name]!.contains(user);
        test('${action.name}: ${user.name} ${allowed ? 'sme' : 'ne sme'}', () {
          final result = action.run(request(status: action.from), user);
          if (allowed) {
            expect(result.isSuccess, isTrue, reason: '$result');
          } else {
            expect(result.errorOrNull, const NotAllowed());
          }
        });
      }
    }
  });

  group('pravo se proverava pre pravila', () {
    test('tuđ zahtev koji ni vlasnik ne bi mogao da otkaže daje NotAllowed, ne CancelNotAllowed', () {
      expect(cancelByClient(request(status: RequestStatus.accepted), by: otherClient).errorOrNull, const NotAllowed());
    });

    test('klijent ne može da zatvori svoj isporučen zahtev kao moderator', () {
      expect(moderatorClose(request(status: RequestStatus.delivered), by: owner).errorOrNull, const NotAllowed());
    });
  });

  group('pružalac', () {
    test('prihvata poslat zahtev upućen njemu', () {
      expect(acceptByProvider(request(), by: addressee).valueOrNull?.status, RequestStatus.accepted);
    });

    test('odbija poslat zahtev upućen njemu', () {
      expect(rejectByProvider(request(), by: addressee).valueOrNull?.status, RequestStatus.rejected);
    });

    test('ne prihvata zahtev koji nije poslat', () {
      expect(
        acceptByProvider(request(status: RequestStatus.inProgress), by: addressee).errorOrNull,
        const InvalidTransition(from: RequestStatus.inProgress, to: RequestStatus.accepted, role: Role.provider),
      );
    });
  });

  group('vidljivost', () {
    test('klijent vidi svoj zahtev, ne tuđ', () {
      expect(AccessPolicy.canView(owner, request()), isTrue);
      expect(AccessPolicy.canView(otherClient, request()), isFalse);
    });

    test('pružalac vidi zahtev upućen njemu, ne drugome', () {
      expect(AccessPolicy.canView(addressee, request()), isTrue);
      expect(AccessPolicy.canView(otherProvider, request()), isFalse);
    });

    test('moderator vidi sve zahteve', () {
      expect(AccessPolicy.canView(moderator, request(clientId: const ClientId('c-5'))), isTrue);
      expect(AccessPolicy.canViewAll(moderator), isTrue);
      expect(AccessPolicy.canViewAll(owner), isFalse);
      expect(AccessPolicy.canViewAll(addressee), isFalse);
    });
  });

  group('novi zahtev', () {
    const draft = NewRequest(
      clientId: ClientId('c-1'),
      providerId: ProviderId('p-1'),
      service: ServiceType.mixing,
      note: 'Miks singla',
    );

    Result<CollaborationRequest> create(User by) =>
        createRequest(draft, by: by, provider: provider, existing: const [], id: const RequestId('n'), now: createdAt);

    test('klijent šalje zahtev u svoje ime', () {
      expect(create(owner).isSuccess, isTrue);
    });

    test('klijent ne šalje zahtev u tuđe ime', () {
      expect(create(otherClient).errorOrNull, const NotAllowed());
    });

    test('pružalac i moderator ne šalju zahteve', () {
      expect(create(addressee).errorOrNull, const NotAllowed());
      expect(create(moderator).errorOrNull, const NotAllowed());
    });
  });

  group('prijava u aplikaciju', () {
    test('mobilnu koriste klijent i pružalac', () {
      expect(signInTo(ClientApp.mobile, owner).valueOrNull, owner);
      expect(signInTo(ClientApp.mobile, addressee).valueOrNull, addressee);
      expect(signInTo(ClientApp.mobile, moderator).errorOrNull, const WrongApp(ClientApp.mobile));
    });

    test('backoffice koristi samo moderator', () {
      expect(signInTo(ClientApp.backoffice, moderator).valueOrNull, moderator);
      expect(signInTo(ClientApp.backoffice, owner).errorOrNull, const WrongApp(ClientApp.backoffice));
      expect(signInTo(ClientApp.backoffice, addressee).errorOrNull, const WrongApp(ClientApp.backoffice));
    });
  });

  group('applyAction', () {
    test('otkazivanje bira akciju po ulozi: klijent samo poslat, moderator i u izradi', () {
      expect(applyAction(RequestAction.cancel, request(), by: owner).valueOrNull?.status, RequestStatus.cancelled);
      expect(
        applyAction(RequestAction.cancel, request(status: RequestStatus.inProgress), by: owner).errorOrNull,
        const CancelNotAllowed(RequestStatus.inProgress),
      );
      expect(
        applyAction(RequestAction.cancel, request(status: RequestStatus.inProgress), by: moderator).valueOrNull?.status,
        RequestStatus.cancelled,
      );
    });

    test('svaka akcija ide kroz isto pravo kao i direktan poziv', () {
      for (final action in RequestAction.values) {
        expect(
          applyAction(action, request(status: RequestStatus.delivered), by: otherClient).errorOrNull,
          const NotAllowed(),
          reason: action.name,
        );
      }
    });
  });
}
