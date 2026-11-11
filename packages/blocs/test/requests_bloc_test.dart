import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeRepository repo;

  RequestsBloc build() => RequestsBloc(requests: repo, providers: repo, user: anaUser);

  setUp(() {
    repo = FakeRepository(
      requests: [
        request('r-1', RequestStatus.sent),
        request('r-2', RequestStatus.accepted, minutes: 5),
        request('r-3', RequestStatus.sent, client: boris),
      ],
    );
  });

  blocTest<RequestsBloc, RequestsState>(
    'učitava samo zahteve prijavljenog klijenta, najnovije prve',
    build: build,
    act: (bloc) => bloc.add(const LoadRequests()),
    expect: () => [
      const RequestsLoading(),
      isA<RequestsLoaded>().having((s) => s.items.map((r) => r.id.value), 'ids', ['r-2', 'r-1']),
    ],
  );

  blocTest<RequestsBloc, RequestsState>(
    'prazan prikaz kada klijent nema zahteve',
    setUp: () => repo.stored.clear(),
    build: build,
    act: (bloc) => bloc.add(const LoadRequests()),
    expect: () => [const RequestsLoading(), const RequestsEmpty()],
  );

  blocTest<RequestsBloc, RequestsState>(
    'greška, pa „Pokušaj ponovo“ učitava podatke',
    setUp: () => repo.failNext = 1,
    build: build,
    act: (bloc) async {
      bloc.add(const LoadRequests());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const RetryLoad());
    },
    expect: () => [const RequestsLoading(), isA<RequestsError>(), const RequestsLoading(), isA<RequestsLoaded>()],
  );

  blocTest<RequestsBloc, RequestsState>(
    'otkazuje poslat zahtev i javlja uspeh',
    build: build,
    seed: () => RequestsLoaded(items: [repo.stored.first], providers: const {}),
    act: (bloc) => bloc.add(const CancelRequest(RequestId('r-1'))),
    expect: () => [
      isA<RequestsLoaded>().having((s) => s.busyId, 'busyId', const RequestId('r-1')),
      isA<RequestsLoaded>()
          .having((s) => s.byId(const RequestId('r-1'))?.status, 'status', RequestStatus.cancelled)
          .having((s) => s.notice, 'notice', isA<RequestActionDone>()),
    ],
    verify: (_) => expect(repo.stored.first.status, RequestStatus.cancelled),
  );

  blocTest<RequestsBloc, RequestsState>(
    'pravilo iz domena odbija otkazivanje prihvaćenog zahteva',
    build: build,
    seed: () => RequestsLoaded(items: [repo.stored[1]], providers: const {}),
    act: (bloc) => bloc.add(const CancelRequest(RequestId('r-2'))),
    expect: () => [
      isA<RequestsLoaded>().having(
        (s) => s.notice,
        'notice',
        const RequestActionRejected(RequestAction.cancel, CancelNotAllowed(RequestStatus.accepted)),
      ),
    ],
    verify: (_) => expect(repo.stored[1].status, RequestStatus.accepted),
  );

  blocTest<RequestsBloc, RequestsState>(
    'prekid veze pri otkazivanju ostavlja listu i javlja grešku',
    build: build,
    seed: () => RequestsLoaded(items: [repo.stored.first], providers: const {}),
    act: (bloc) {
      repo.failNext = 1;
      bloc.add(const CancelRequest(RequestId('r-1')));
    },
    expect: () => [
      isA<RequestsLoaded>(),
      isA<RequestsLoaded>()
          .having((s) => s.notice, 'notice', isA<RequestActionFailed>())
          .having((s) => s.isBusy, 'busy', false),
    ],
  );

  blocTest<RequestsBloc, RequestsState>(
    'zahtev koji je pružalac u međuvremenu prihvatio: razlog je StaleRequest',
    build: build,
    // Klijent vidi zahtev kao poslat, a u portu je već prihvaćen.
    seed: () => RequestsLoaded(items: [repo.stored.first], providers: const {}),
    act: (bloc) {
      repo.stored[0] = repo.stored[0].copyWith(status: RequestStatus.accepted);
      bloc.add(const CancelRequest(RequestId('r-1')));
    },
    skip: 1,
    expect: () => [
      isA<RequestsLoaded>().having(
        (s) => s.notice,
        'notice',
        const RequestActionRejected(RequestAction.cancel, StaleRequest(RequestStatus.accepted)),
      ),
    ],
    verify: (bloc) {
      expect(repo.stored.first.status, RequestStatus.accepted);
      // Posle odbijanja sa servera ekran vidi sveže stanje, bez dugmeta za otkazivanje.
      final state = bloc.state as RequestsLoaded;
      expect(state.byId(const RequestId('r-1'))?.status, RequestStatus.accepted);
      expect(state.canCancel(state.byId(const RequestId('r-1'))!), isFalse);
    },
  );

  blocTest<RequestsBloc, RequestsState>(
    'tuđ zahtev ne može da se otkaže: NotAllowed iz AccessPolicy',
    build: () => RequestsBloc(requests: repo, providers: repo, user: borisUser),
    seed: () => RequestsLoaded(items: [repo.stored.first], providers: const {}),
    act: (bloc) => bloc.add(const CancelRequest(RequestId('r-1'))),
    expect: () => [
      isA<RequestsLoaded>().having(
        (s) => s.notice,
        'notice',
        const RequestActionRejected(RequestAction.cancel, NotAllowed()),
      ),
    ],
    verify: (_) => expect(repo.stored.first.status, RequestStatus.sent),
  );

  group('pružalac u mobilnoj', () {
    const markoUser = User(id: UserId('p-marko'), name: 'Marko', role: Role.provider);

    blocTest<RequestsBloc, RequestsState>(
      'vidi zahteve upućene njemu i nudi mu samo prihvatanje i odbijanje poslatih',
      setUp: () => repo = FakeRepository(requests: repo.stored, session: markoUser),
      build: () => RequestsBloc(requests: repo, providers: repo, user: markoUser),
      act: (bloc) => bloc.add(const LoadRequests()),
      skip: 1,
      verify: (bloc) {
        final state = bloc.state as RequestsLoaded;
        expect(state.items, hasLength(3));
        expect(state.actionsFor(state.byId(const RequestId('r-1'))!), [RequestAction.accept, RequestAction.reject]);
        expect(state.actionsFor(state.byId(const RequestId('r-2'))!), isEmpty);
      },
    );

    blocTest<RequestsBloc, RequestsState>(
      'prihvata poslat zahtev, pa ponovo učitava',
      setUp: () => repo = FakeRepository(requests: repo.stored, session: markoUser),
      build: () => RequestsBloc(requests: repo, providers: repo, user: markoUser),
      act: (bloc) async {
        bloc.add(const LoadRequests());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const RequestActionRequested(RequestAction.accept, RequestId('r-1')));
      },
      verify: (bloc) {
        final state = bloc.state as RequestsLoaded;
        expect(state.byId(const RequestId('r-1'))?.status, RequestStatus.accepted);
        expect(state.notice, isA<RequestActionDone>());
      },
    );
  });
}
