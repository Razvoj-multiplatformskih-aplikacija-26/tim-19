import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'admin_requests_event.dart';
part 'admin_requests_state.dart';

/// Posao moderatora: svi zahtevi, sortiranje, filter, pretraga, izbor i akcije koje menjaju stanje.
///
/// Zahtevi stižu sa servera po stranama od [pageSize]; filter po stanju radi server, a „Učitaj još“ dovlači
/// sledeću stranu. Sortiranje i pretraga rade nad učitanim redovima.
final class AdminRequestsBloc extends Bloc<AdminRequestsEvent, AdminRequestsState> {
  AdminRequestsBloc({
    required this.requests,
    required this.providers,
    required this.clients,
    required this.moderator,
    this.pageSize = 50,
  }) : super(const AdminRequestsLoading()) {
    on<LoadAdminRequests>((event, emit) => _load(emit));
    on<RetryAdminRequests>((event, emit) => _load(emit));
    on<AdminSortChanged>((event, emit) {
      _whenLoaded(emit, (s) {
        final ascending = s.sortColumn == event.column ? !s.ascending : event.column != AdminColumn.createdAt;
        return s.copyWith(sortColumn: event.column, ascending: ascending);
      });
    });
    on<AdminStatusFilterChanged>((event, emit) async {
      _whenLoaded(emit, (s) => s.copyWith(statusFilter: event.status));
      await _load(emit, quiet: true);
    });
    on<AdminLoadMore>(_onLoadMore);
    on<AdminSearchChanged>((event, emit) => _whenLoaded(emit, (s) => s.copyWith(query: event.query)));
    on<AdminRequestSelected>((event, emit) => _whenLoaded(emit, (s) => s.copyWith(selectedId: event.id)));
    on<AdminSelectionMoved>((event, emit) => _whenLoaded(emit, (s) => s.moveSelection(event.delta)));
    on<AdminNoticeShown>((event, emit) => _whenLoaded(emit, (s) => s.copyWith(notice: null)));
    on<ModeratorActionRequested>(_onAction);
  }

  final RequestsRepository requests;
  final ProvidersRepository providers;
  final ClientsRepository clients;

  /// Prijavljeni moderator; akcije se proveravaju u njegovo ime.
  final User moderator;

  /// Koliko zahteva staje na jednu stranu.
  final int pageSize;

  void _whenLoaded(Emitter<AdminRequestsState> emit, AdminRequestsLoaded Function(AdminRequestsLoaded) change) {
    final current = state;
    if (current is AdminRequestsLoaded) emit(change(current));
  }

  /// Učitava prvu stranu (po filteru stanja, ako ga ima). Sa [quiet] nema prikaza učitavanja (osvežavanje posle odbijanja), a [notice]
  /// ostaje u novom stanju; filter, sortiranje i izbor se zadržavaju.
  Future<void> _load(Emitter<AdminRequestsState> emit, {bool quiet = false, AdminNotice? notice}) async {
    final previous = state;
    final status = previous is AdminRequestsLoaded ? previous.statusFilter : null;
    if (!quiet) emit(const AdminRequestsLoading());
    try {
      final page = await requests.requests(status: status, limit: pageSize);
      // Prazan ekran samo kad zahteva uopšte nema; prazan filter ostaje u tabeli da može da se promeni.
      if (page.total == 0 && status == null) {
        emit(const AdminRequestsEmpty());
        return;
      }
      final allProviders = [for (final e in await providers.catalog()) e.provider];
      final allClients = await clients.allClients();
      final loaded = AdminRequestsLoaded(
        requests: page.items,
        total: page.total,
        providers: {for (final p in allProviders) p.id: p},
        clients: {for (final c in allClients) c.id: c},
      );
      emit(
        previous is AdminRequestsLoaded
            ? loaded.copyWith(
                sortColumn: previous.sortColumn,
                ascending: previous.ascending,
                statusFilter: previous.statusFilter,
                query: previous.query,
                selectedId: previous.selectedId,
                notice: notice,
              )
            : loaded.copyWith(notice: notice),
      );
    } on Exception catch (cause) {
      emit(AdminRequestsError(cause));
    }
  }

  Future<void> _onLoadMore(AdminLoadMore event, Emitter<AdminRequestsState> emit) async {
    final current = state;
    if (current is! AdminRequestsLoaded || !current.hasMore || current.loadingMore) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final page = await requests.requests(
        status: current.statusFilter,
        offset: current.requests.length,
        limit: pageSize,
      );
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      final known = {for (final r in latest.requests) r.id};
      emit(
        latest.copyWith(
          requests: [...latest.requests, ...page.items.where((r) => !known.contains(r.id))],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on Exception catch (cause) {
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      emit(latest.copyWith(loadingMore: false, notice: AdminLoadFailed(cause)));
    }
  }

  Future<void> _onAction(ModeratorActionRequested event, Emitter<AdminRequestsState> emit) async {
    final current = state;
    if (current is! AdminRequestsLoaded || current.isBusy) return;
    final request = current.byId(event.id);
    if (request == null) return;
    // Domen proverava pre slanja; server ponovo proverava i konačno odlučuje.
    final next = applyAction(event.action.asRequestAction, request, by: moderator);
    if (next case Failure(:final error)) {
      emit(current.copyWith(notice: ModeratorActionRejected(event.action, error)));
      return;
    }
    emit(current.copyWith(busyId: event.id));
    try {
      final saved = await requests.apply(event.action.asRequestAction, request.id, from: request.status);
      // Za vreme čekanja moderator je mogao da promeni izbor ili filter.
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      switch (saved) {
        case Success(:final value):
          emit(latest.replaced(value).copyWith(busyId: null, notice: ModeratorActionDone(event.action, value)));
        case Failure(:final error):
          // Server je odbio (npr. drugi moderator je već zatvorio zahtev): razlog, pa sveži podaci.
          emit(latest.copyWith(busyId: null));
          await _load(emit, quiet: true, notice: ModeratorActionRejected(event.action, error));
      }
    } on Exception catch (cause) {
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      emit(latest.copyWith(busyId: null, notice: ModeratorActionFailed(event.action, cause)));
    }
  }
}
