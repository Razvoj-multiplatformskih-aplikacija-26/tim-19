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
  const CatalogLoaded({required this.entries, this.genre, this.service});

  /// Pružaoci sa slobodnim mestima, kako ih daje port.
  final List<CatalogEntry> entries;
  final Genre? genre;
  final ServiceType? service;

  List<Provider> get providers => [for (final e in entries) e.provider];

  /// Ono što katalog prikazuje: pravilo iz domena bira verifikovane i primenjuje filter.
  List<Provider> get visible => catalog(providers, genre: genre, service: service);

  Provider? byId(ProviderId id) => catalog(providers).where((p) => p.id == id).firstOrNull;

  int freeSlotsOf(Provider provider) => entries.where((e) => e.provider.id == provider.id).firstOrNull?.freeSlots ?? 0;

  CatalogLoaded withFilter({Genre? genre, ServiceType? service}) =>
      CatalogLoaded(entries: entries, genre: genre, service: service);

  @override
  List<Object?> get props => [entries, genre, service];
}
