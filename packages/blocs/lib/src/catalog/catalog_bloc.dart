import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

/// Katalog verifikovanih pružalaca sa filterom po žanru i usluzi.
final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required this.providers, required this.requests}) : super(const CatalogLoading()) {
    on<LoadCatalog>((event, emit) => _load(emit));
    on<RetryCatalog>((event, emit) => _load(emit));
    on<CatalogFilterChanged>((event, emit) {
      final current = state;
      if (current is CatalogLoaded) emit(current.withFilter(genre: event.genre, service: event.service));
    });
  }

  final ProvidersRepository providers;
  final RequestsRepository requests;

  Future<void> _load(Emitter<CatalogState> emit) async {
    final previous = state;
    emit(const CatalogLoading());
    try {
      final all = await providers.allProviders();
      final taken = await requests.allRequests();
      emit(
        CatalogLoaded(
          providers: all,
          requests: taken,
          genre: previous is CatalogLoaded ? previous.genre : null,
          service: previous is CatalogLoaded ? previous.service : null,
        ),
      );
    } on Exception catch (cause) {
      emit(CatalogError(cause));
    }
  }
}
