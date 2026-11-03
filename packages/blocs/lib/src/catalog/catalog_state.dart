part of 'catalog_bloc.dart';

sealed class CatalogState extends Equatable {
  const CatalogState();

  @override
  List<Object?> get props => const [];
}

final class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

final class CatalogError extends CatalogState {
  const CatalogError(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}

final class CatalogLoaded extends CatalogState {
  const CatalogLoaded({required this.providers, required this.requests, this.genre, this.service});

  final List<Provider> providers;

  /// Zahtevi svih klijenata, za računanje slobodnih mesta.
  final List<CollaborationRequest> requests;
  final Genre? genre;
  final ServiceType? service;

  /// Ono što katalog prikazuje: pravilo iz domena bira verifikovane i primenjuje filter.
  List<Provider> get visible => catalog(providers, genre: genre, service: service);

  Provider? byId(ProviderId id) => catalog(providers).where((p) => p.id == id).firstOrNull;

  int freeSlotsOf(Provider provider) => freeSlots(provider, requests);

  CatalogLoaded withFilter({Genre? genre, ServiceType? service}) =>
      CatalogLoaded(providers: providers, requests: requests, genre: genre, service: service);

  @override
  List<Object?> get props => [providers, requests, genre, service];
}
