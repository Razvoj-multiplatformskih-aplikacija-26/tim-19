import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'admin_requests_event.dart';
part 'admin_requests_state.dart';

/// Posao moderatora: svi zahtevi, sortiranje, filter, pretraga, izbor i akcije koje menjaju stanje.
final class AdminRequestsBloc extends Bloc<AdminRequestsEvent, AdminRequestsState> {
  AdminRequestsBloc({required this.requests, required this.providers, required this.clients, required this.moderator})
    : super(const AdminRequestsLoading()) {
    on<LoadAdminRequests>((event, emit) => _load(emit));
    on<RetryAdminRequests>((event, emit) => _load(emit));
    on<AdminSortChanged>((event, emit) {
      _whenLoaded(emit, (s) {
        final ascending = s.sortColumn == event.column ? !s.ascending : event.column != AdminColumn.createdAt;
        return s.copyWith(sortColumn: event.column, ascending: ascending);
      });
    });
    on<AdminStatusFilterChanged>((event, emit) => _whenLoaded(emit, (s) => s.copyWith(statusFilter: event.status)));
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

  void _whenLoaded(Emitter<AdminRequestsState> emit, AdminRequestsLoaded Function(AdminRequestsLoaded) change) {
    final current = state;
    if (current is AdminRequestsLoaded) emit(change(current));
  }

  Future<void> _load(Emitter<AdminRequestsState> emit) async {
    final previous = state;
    emit(const AdminRequestsLoading());
    try {
      final all = await requests.allRequests();
      if (all.isEmpty) {
        emit(const AdminRequestsEmpty());
        return;
      }
      final allProviders = await providers.allProviders();
      final allClients = await clients.allClients();
      final loaded = AdminRequestsLoaded(
        requests: all,
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
              )
            : loaded,
      );
    } on Exception catch (cause) {
      emit(AdminRequestsError(cause));
    }
  }

  Future<void> _onAction(ModeratorActionRequested event, Emitter<AdminRequestsState> emit) async {
    final current = state;
    if (current is! AdminRequestsLoaded || current.isBusy) return;
    final request = current.byId(event.id);
    if (request == null) return;
    final next = switch (event.action) {
      ModeratorAction.cancel => moderatorCancel(request, by: moderator),
      ModeratorAction.close => moderatorClose(request, by: moderator),
      ModeratorAction.reopen => moderatorReopen(request, by: moderator),
    };
    if (next case Failure(:final error)) {
      emit(current.copyWith(notice: ModeratorActionRejected(event.action, error)));
      return;
    }
    emit(current.copyWith(busyId: event.id));
    try {
      final saved = await requests.update(next.valueOrNull!, from: request.status);
      // Za vreme čekanja moderator je mogao da promeni izbor ili filter.
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      switch (saved) {
        case Success(:final value):
          emit(latest.replaced(value).copyWith(busyId: null, notice: ModeratorActionDone(event.action, value)));
        case Failure(:final error):
          emit(latest.copyWith(busyId: null, notice: ModeratorActionRejected(event.action, error)));
      }
    } on Exception catch (cause) {
      final latest = state is AdminRequestsLoaded ? state as AdminRequestsLoaded : current;
      emit(latest.copyWith(busyId: null, notice: ModeratorActionFailed(event.action, cause)));
    }
  }
}
