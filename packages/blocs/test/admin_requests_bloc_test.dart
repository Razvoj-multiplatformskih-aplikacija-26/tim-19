import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeRepository repo;

  AdminRequestsBloc build() => AdminRequestsBloc(requests: repo, providers: repo, clients: repo, moderator: kosta);

  Future<void> loaded(AdminRequestsBloc bloc) async {
    bloc.add(const LoadAdminRequests());
    await Future<void>.delayed(Duration.zero);
  }

  AdminRequestsLoaded stateOf(AdminRequestsBloc bloc) => bloc.state as AdminRequestsLoaded;

  setUp(() {
    repo = FakeRepository(
      session: kosta,
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
    setUp: () => repo.stored.clear(),
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
      expect(repo.stored[1].status, RequestStatus.completed);
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
      expect(repo.stored[2].status, RequestStatus.completed);
    },
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'drugi moderator je u međuvremenu zatvorio zahtev: razlog, pa sveži podaci, izbor ostaje',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const AdminRequestSelected(RequestId('r-2')));
      repo.stored[1] = repo.stored[1].copyWith(status: RequestStatus.completed);
      bloc.add(const ModeratorActionRequested(ModeratorAction.reopen, RequestId('r-2')));
    },
    verify: (bloc) {
      final state = stateOf(bloc);
      expect(
        state.notice,
        const ModeratorActionRejected(ModeratorAction.reopen, StaleRequest(RequestStatus.completed)),
      );
      expect(state.selected?.status, RequestStatus.completed);
      expect(state.isBusy, isFalse);
    },
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'učitava po stranama: prva strana, pa „Učitaj još“ do kraja',
    build: () => AdminRequestsBloc(requests: repo, providers: repo, clients: repo, moderator: kosta, pageSize: 2),
    act: (bloc) async {
      await loaded(bloc);
      expect([stateOf(bloc).requests.length, stateOf(bloc).total, stateOf(bloc).hasMore], [2, 3, true]);
      bloc.add(const AdminLoadMore());
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) => expect([stateOf(bloc).requests.length, stateOf(bloc).hasMore], [3, false]),
  );

  blocTest<AdminRequestsBloc, AdminRequestsState>(
    'filter po stanju traži stranu od servera; prazan filter ostaje u tabeli',
    build: build,
    act: (bloc) async {
      await loaded(bloc);
      bloc.add(const AdminStatusFilterChanged(RequestStatus.delivered));
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(bloc).requests.map((r) => r.id.value), ['r-2']);
      expect(stateOf(bloc).total, 1);
      bloc.add(const AdminStatusFilterChanged(RequestStatus.rejected));
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) => expect([stateOf(bloc).requests, stateOf(bloc).statusFilter], [isEmpty, RequestStatus.rejected]),
  );

  test('dostupne akcije prate pravila iz domena', () {
    final state = AdminRequestsLoaded(requests: repo.stored, providers: const {}, clients: const {});
    final delivered = repo.stored[1];
    final sent = repo.stored[0];
    expect(ModeratorAction.values.where((a) => state.canApply(a, delivered)), ModeratorAction.values);
    expect(ModeratorAction.values.where((a) => state.canApply(a, sent)), [ModeratorAction.cancel]);
  });
}
