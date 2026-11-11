import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

/// Katalog verifikovanih pružalaca sa filterom po žanru i usluzi. Slobodna mesta dolaze iz porta
/// (računa ih server nad zahtevima svih klijenata), jer klijent tuđe zahteve ne vidi.
final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required this.providers}) : super(const CatalogLoading()) {
    on<LoadCatalog>((event, emit) => _load(emit));
    on<RetryCatalog>((event, emit) => _load(emit));
    on<CatalogFilterChanged>((event, emit) {
      final current = state;
      if (current is CatalogLoaded) emit(current.withFilter(genre: event.genre, service: event.service));
    });
  }

  final ProvidersRepository providers;

  Future<void> _load(Emitter<CatalogState> emit) async {
    final previous = state;
    emit(const CatalogLoading());
    try {
      final entries = await providers.catalog();
      emit(
        CatalogLoaded(
          entries: entries,
          genre: previous is CatalogLoaded ? previous.genre : null,
          service: previous is CatalogLoaded ? previous.service : null,
        ),
      );
    } on Exception catch (cause) {
      emit(CatalogError(cause));
    }
  }
}
