part of 'catalog_bloc.dart';

sealed class CatalogEvent {
  const CatalogEvent();
}

final class LoadCatalog extends CatalogEvent {
  const LoadCatalog();
}

final class RetryCatalog extends CatalogEvent {
  const RetryCatalog();
}

/// Novi filter; `null` znači „svi“.
final class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged({this.genre, this.service});

  final Genre? genre;
  final ServiceType? service;
}
