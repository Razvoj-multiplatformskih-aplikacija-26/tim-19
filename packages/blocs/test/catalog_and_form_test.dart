import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  group('CatalogBloc', () {
    late FakeRepository repo;

    setUp(() => repo = FakeRepository(requests: [request('r-1', RequestStatus.sent, client: boris)]));

    blocTest<CatalogBloc, CatalogState>(
      'prikazuje samo verifikovane i računa slobodna mesta nad zahtevima svih klijenata',
      build: () => CatalogBloc(providers: repo, requests: repo),
      act: (bloc) => bloc.add(const LoadCatalog()),
      verify: (bloc) {
        final state = bloc.state as CatalogLoaded;
        expect(state.visible, [marko]);
        expect(state.freeSlotsOf(marko), 2);
        expect(state.byId(hidden.id), isNull);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'filter po usluzi koju niko ne nudi daje prazan katalog',
      build: () => CatalogBloc(providers: repo, requests: repo),
      act: (bloc) async {
        bloc.add(const LoadCatalog());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogFilterChanged(service: ServiceType.vocals));
      },
      verify: (bloc) => expect((bloc.state as CatalogLoaded).visible, isEmpty),
    );
  });

  group('NewRequestBloc', () {
    late FakeRepository repo;

    NewRequestBloc build() => NewRequestBloc(requests: repo, provider: marko, user: anaUser);

    setUp(() => repo = FakeRepository());

    blocTest<NewRequestBloc, NewRequestState>(
      'proverava dužinu napomene dok korisnik kuca',
      build: build,
      act: (bloc) => bloc.add(NoteChanged('a' * (maxNoteLength + 1))),
      verify: (bloc) => expect(bloc.state.noteError, const NoteTooLong(maxNoteLength + 1, max: maxNoteLength)),
    );

    blocTest<NewRequestBloc, NewRequestState>(
      'prazna napomena se prijavljuje tek pri slanju',
      build: build,
      act: (bloc) async {
        bloc.add(const NoteChanged(''));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.noteError, isNull);
        bloc.add(const SubmitNewRequest());
      },
      verify: (bloc) {
        expect(bloc.state.noteError, const NoteEmpty());
        expect(repo.requests, isEmpty);
      },
    );

    blocTest<NewRequestBloc, NewRequestState>(
      'šalje ispravan zahtev',
      build: build,
      act: (bloc) async {
        bloc.add(const ServiceChanged(ServiceType.mastering));
        bloc.add(const NoteChanged('Mastering EP-a'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SubmitNewRequest());
      },
      verify: (bloc) {
        expect(bloc.state.status, NewRequestStatus.done);
        expect(bloc.state.created?.service, ServiceType.mastering);
        expect(repo.requests.single.status, RequestStatus.sent);
      },
    );

    blocTest<NewRequestBloc, NewRequestState>(
      'port odbija zahtev kada pružalac nema mesta',
      setUp: () => repo.requests.addAll([
        for (var i = 0; i < marko.capacity; i++) request('r$i', RequestStatus.inProgress, client: boris),
      ]),
      build: build,
      act: (bloc) async {
        bloc.add(const NoteChanged('Miks'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SubmitNewRequest());
      },
      verify: (bloc) {
        expect(bloc.state.status, NewRequestStatus.editing);
        expect(bloc.state.submitError, const NoFreeSlots(capacity: 3));
      },
    );
  });
}
