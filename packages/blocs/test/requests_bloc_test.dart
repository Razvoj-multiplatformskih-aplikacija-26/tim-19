import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeRepository repo;

  RequestsBloc build() => RequestsBloc(requests: repo, providers: repo, clientId: ana.id);

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
    setUp: () => repo.requests.clear(),
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
    seed: () => RequestsLoaded(items: [repo.requests.first], providers: const {}),
    act: (bloc) => bloc.add(const CancelRequest(RequestId('r-1'))),
    expect: () => [
      isA<RequestsLoaded>().having((s) => s.busyId, 'busyId', const RequestId('r-1')),
      isA<RequestsLoaded>()
          .having((s) => s.byId(const RequestId('r-1'))?.status, 'status', RequestStatus.cancelled)
          .having((s) => s.notice, 'notice', isA<RequestCancelled>()),
    ],
    verify: (_) => expect(repo.requests.first.status, RequestStatus.cancelled),
  );

  blocTest<RequestsBloc, RequestsState>(
    'pravilo iz domena odbija otkazivanje prihvaćenog zahteva',
    build: build,
    seed: () => RequestsLoaded(items: [repo.requests[1]], providers: const {}),
    act: (bloc) => bloc.add(const CancelRequest(RequestId('r-2'))),
    expect: () => [
      isA<RequestsLoaded>().having(
        (s) => s.notice,
        'notice',
        const CancelRejected(CancelNotAllowed(RequestStatus.accepted)),
      ),
    ],
    verify: (_) => expect(repo.requests[1].status, RequestStatus.accepted),
  );

  blocTest<RequestsBloc, RequestsState>(
    'prekid veze pri otkazivanju ostavlja listu i javlja grešku',
    build: build,
    seed: () => RequestsLoaded(items: [repo.requests.first], providers: const {}),
    act: (bloc) {
      repo.failNext = 1;
      bloc.add(const CancelRequest(RequestId('r-1')));
    },
    expect: () => [
      isA<RequestsLoaded>(),
      isA<RequestsLoaded>()
          .having((s) => s.notice, 'notice', isA<CancelFailed>())
          .having((s) => s.isBusy, 'busy', false),
    ],
  );
}
