import 'identifiers.dart';
import 'model.dart';
import 'request_status.dart';
import 'result.dart';

/// Port ka zahtevima. Lažna implementacija živi u svakoj aplikaciji, a u KT2 dolazi HTTP implementacija.
abstract interface class RequestsRepository {
  Future<List<CollaborationRequest>> requestsOfClient(ClientId clientId);

  Future<List<CollaborationRequest>> allRequests();

  Future<CollaborationRequest?> getById(RequestId id);

  Future<Result<CollaborationRequest>> create(NewRequest draft);

  /// Čuva novo stanje; [from] je stanje koje je klijent video, da bi server odbio zastarelu izmenu.
  Future<Result<CollaborationRequest>> update(CollaborationRequest request, {required RequestStatus from});
}

abstract interface class ProvidersRepository {
  Future<List<Provider>> allProviders();

  Future<Provider?> providerById(ProviderId id);
}

abstract interface class ClientsRepository {
  Future<List<Client>> allClients();
}

/// Port nije mogao da odgovori (mreža, server); nije greška pravila.
final class RepositoryException implements Exception {
  const RepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RepositoryException: $message';
}
