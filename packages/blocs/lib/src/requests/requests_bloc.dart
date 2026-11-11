import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

import '../limits.dart';

part 'requests_event.dart';
part 'requests_state.dart';

/// Zahtevi prijavljenog korisnika mobilne aplikacije i akcije nad njima: klijent svoje zahteve, pružalac
/// zahteve upućene njemu. Isti Bloc radi nad serverom i nad lažnim portom.
final class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  RequestsBloc({required this.requests, required this.providers, required this.user, this.clients})
    : super(const RequestsLoading()) {
    on<LoadRequests>((event, emit) async {
      emit(const RequestsLoading());
      await _reload(emit);
    });
    on<RetryLoad>((event, emit) async {
      emit(const RequestsLoading());
      await _reload(emit);
    });
    on<RequestActionRequested>(_onAction);
    on<RequestsNoticeShown>((event, emit) {
      final current = state;
      if (current is RequestsLoaded && current.notice != null) emit(current.copyWith(notice: null));
    });
  }

  final RequestsRepository requests;
  final ProvidersRepository providers;

  /// Imena klijenata; potrebna pružaocu (zahtevi upućeni njemu), klijentu nisu.
  final ClientsRepository? clients;

  /// Prijavljeni korisnik; pravo na akciju proverava domen u njegovo ime.
  final User user;

  /// Akcije koje ima smisla ponuditi u mobilnoj aplikaciji, po ulozi.
  List<RequestAction> get _offered => switch (user.role) {
    Role.client => const [RequestAction.cancel, RequestAction.complete, RequestAction.revise],
    Role.provider => const [RequestAction.accept, RequestAction.reject],
    Role.moderator => const [],
  };

  Future<void> _onAction(RequestActionRequested event, Emitter<RequestsState> emit) async {
    final current = state;
    if (current is! RequestsLoaded || current.isBusy) return;
    final request = current.byId(event.id);
    if (request == null) return;
    // Domen proverava pre slanja; server ponovo proverava i konačno odlučuje.
    if (applyAction(event.action, request, by: user) case Failure(:final error)) {
      emit(current.copyWith(notice: RequestActionRejected(event.action, error)));
      return;
    }
    emit(current.copyWith(notice: null, busyId: event.id));
    try {
      final saved = await requests.apply(event.action, request.id, from: request.status);
      switch (saved) {
        case Success(:final value):
          await _reload(emit, notice: RequestActionDone(event.action, value));
        case Failure(:final error):
          // Server je odbio (npr. zahtev je u međuvremenu prihvaćen): razlog, pa sveži podaci.
          await _reload(emit, notice: RequestActionRejected(event.action, error));
      }
    } on Exception catch (cause) {
      emit(current.copyWith(notice: RequestActionFailed(event.action, cause)));
    }
  }

  Future<void> _reload(Emitter<RequestsState> emit, {RequestsNotice? notice}) async {
    try {
      final mine = (await requests.requests(limit: maxListed)).items;
      if (mine.isEmpty) {
        emit(const RequestsEmpty());
        return;
      }
      final entries = await providers.catalog();
      final names = switch (clients) {
        final clients? when AccessPolicy.canViewClients(user) => await clients.allClients(),
        _ => const <Client>[],
      };
      final sorted = [...mine]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(
        RequestsLoaded(
          items: sorted,
          providers: {for (final e in entries) e.provider.id: e.provider},
          clients: {for (final c in names) c.id: c},
          actions: {
            for (final r in sorted)
              r.id: [
                for (final action in _offered)
                  if (applyAction(action, r, by: user).isSuccess) action,
              ],
          },
          notice: notice,
        ),
      );
    } on Exception catch (cause) {
      emit(RequestsError(cause));
    }
  }
}
