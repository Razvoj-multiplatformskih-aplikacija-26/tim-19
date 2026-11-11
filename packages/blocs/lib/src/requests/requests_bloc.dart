import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

import '../limits.dart';

part 'requests_event.dart';
part 'requests_state.dart';

/// Glavni tok klijenta: učitava njegove zahteve i otkazuje poslat zahtev.
final class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  RequestsBloc({required this.requests, required this.providers, required this.user}) : super(const RequestsLoading()) {
    on<LoadRequests>((event, emit) async {
      emit(const RequestsLoading());
      await _reload(emit);
    });
    on<RetryLoad>((event, emit) async {
      emit(const RequestsLoading());
      await _reload(emit);
    });
    on<CancelRequest>(_onCancel);
    on<RequestsNoticeShown>((event, emit) {
      final current = state;
      if (current is RequestsLoaded && current.notice != null) emit(current.copyWith(notice: null));
    });
  }

  final RequestsRepository requests;
  final ProvidersRepository providers;

  /// Prijavljeni klijent; vidi i otkazuje samo svoje zahteve.
  final User user;

  Future<void> _onCancel(CancelRequest event, Emitter<RequestsState> emit) async {
    final current = state;
    if (current is! RequestsLoaded || current.isBusy) return;
    final request = current.byId(event.id);
    if (request == null) return;
    final next = cancelByClient(request, by: user);
    if (next case Failure(:final error)) {
      emit(current.copyWith(notice: CancelRejected(error)));
      return;
    }
    emit(current.copyWith(notice: null, busyId: event.id));
    try {
      final saved = await requests.apply(RequestAction.cancel, request.id, from: request.status);
      switch (saved) {
        case Success(:final value):
          await _reload(emit, notice: RequestCancelled(value));
        case Failure(:final error):
          emit(current.copyWith(notice: CancelRejected(error)));
      }
    } on Exception catch (cause) {
      emit(current.copyWith(notice: CancelFailed(cause)));
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
      final sorted = [...mine]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(
        RequestsLoaded(items: sorted, providers: {for (final e in entries) e.provider.id: e.provider}, notice: notice),
      );
    } on Exception catch (cause) {
      emit(RequestsError(cause));
    }
  }
}
