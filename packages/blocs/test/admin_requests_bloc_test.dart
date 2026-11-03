import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeRepository repo;

  AdminRequestsBloc build() => AdminRequestsBloc(requests: repo, providers: repo, clients: repo);

  Future<void> loaded(AdminRequestsBloc bloc) async {
    bloc.add(const LoadAdminRequests());
    await Future<void>.delayed(Duration.zero);
  }

  AdminRequestsLoaded stateOf(AdminRequestsBloc bloc) => bloc.state as AdminRequestsLoaded;

  setUp(() {
    repo = FakeRepository(
      requests: [
        request('r-1', RequestStatus.sent, client: ana),
        request('r-2', RequestStatus.delivered, client: boris, minutes: 10),
        request('r-3', RequestStatus.completed, client: ana, minutes: 20),
      ],
    );
  });

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'učitava sve zahteve, najnovije prve',
    build: build,
    act: loaded,
    verify: (bloc) => expect(stateOf(bloc).visible.map((r) => r.id.value), ['r-3', 'r-2', 'r-1']),
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'prazan prikaz bez zahteva',
    setUp: () => repo.requests.clear(),
    build: build,
    act: loaded,
    expect: () => [const AdminRequestsLoading(), const AdminRequestsEmpty()],
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'filter po stanju, pretraga po klijentu i sortiranje',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const AdminSearchChanged('ana'));
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(bloc).visible.map((r) => r.id.value), ['r-3', 'r-1']);
      bloc.add(const AdminSortChanged(AdminColumn.status));
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(bloc).visible.map((r) => r.id.value), ['r-1', 'r-3']);
      bloc.add(const AdminStatusFilterChanged(RequestStatus.completed));
    },
    verify: (bloc) => expect(stateOf(bloc).visible.map((r) => r.id.value), ['r-3']),
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'strelice pomeraju izbor po vidljivim redovima i ne izlaze van liste',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const AdminSelectionMoved(1));
      bloc.add(const AdminSelectionMoved(1));
      bloc.add(const AdminSelectionMoved(1));
      bloc.add(const AdminSelectionMoved(1));
    },
    verify: (bloc) => expect(stateOf(bloc).selectedId, const RequestId('r-1')),
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'zatvara isporučen zahtev kao završen i zadržava izbor',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const AdminRequestSelected(RequestId('r-2')));
      bloc.add(const ModeratorActionRequested(ModeratorAction.close, RequestId('r-2')));
    },
    verify: (bloc) {
      final state = stateOf(bloc);
      expect(state.selected?.status, RequestStatus.completed);
      expect(state.notice, isA<ModeratorActionDone>());
      expect(state.isBusy, isFalse);
      expect(repo.requests[1].status, RequestStatus.completed);
    },
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'pravilo iz domena ne dozvoljava otkazivanje završenog zahteva',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const ModeratorActionRequested(ModeratorAction.cancel, RequestId('r-3')));
    },
    verify: (bloc) {
      expect(
        stateOf(bloc).notice,
        const ModeratorActionRejected(ModeratorAction.cancel, RequestClosed(RequestStatus.completed)),
      );
      expect(repo.requests[2].status, RequestStatus.completed);
    },
  );

  test('dostupne akcije prate pravila iz domena', () {
    final state = AdminRequestsLoaded(requests: repo.requests, providers: const {}, clients: const {});
    final delivered = repo.requests[1];
    final sent = repo.requests[0];
    expect(ModeratorAction.values.where((a) => state.canApply(a, delivered)), ModeratorAction.values);
    expect(ModeratorAction.values.where((a) => state.canApply(a, sent)), [ModeratorAction.cancel]);
  });
}
