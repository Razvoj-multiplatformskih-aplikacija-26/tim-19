import 'package:domain/domain.dart';

import 'seed.dart';

/// Lažna implementacija portova u memoriji backoffice-a, sa kašnjenjem i prekidačem za grešku.
/// Podaci nisu sinhronizovani sa mobilnom aplikacijom.
final class InMemoryBackend implements RequestsRepository, ProvidersRepository, ClientsRepository {
  InMemoryBackend({DateTime? now, this.latency = const Duration(milliseconds: 500)})
    : _requests = seedRequests(now ?? DateTime.now());

  final Duration latency;
  final List<CollaborationRequest> _requests;

  /// Koliko sledećih poziva baca grešku.
  int failingRequests = 0;

  /// Koliko sledećih učitavanja svih zahteva vraća prazan odgovor.
  int emptyResponses = 0;

  Future<void> _roundTrip() async {
    await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simuliran prekid veze');
    }
  }

  @override
  Future<List<CollaborationRequest>> requestsOfClient(ClientId clientId) async {
    await _roundTrip();
    return _requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<List<CollaborationRequest>> allRequests() async {
    await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return const [];
    }
    return [..._requests];
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  /// Zahteve pravi klijent u mobilnoj aplikaciji, ne moderator.
  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) => throw UnsupportedError('Moderator ne pravi zahteve');

  @override
  Future<Result<CollaborationRequest>> update(CollaborationRequest request, {required RequestStatus from}) async {
    await _roundTrip();
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index < 0) return const Failure(NotFound());
    // Neko je u međuvremenu promenio zahtev.
    if (_requests[index].status != from) return Failure(StaleRequest(_requests[index].status));
    _requests[index] = request;
    return Success(request);
  }

  @override
  Future<List<Provider>> allProviders() async {
    await _roundTrip();
    return seedProviders;
  }

  @override
  Future<Provider?> providerById(ProviderId id) async {
    await _roundTrip();
    return seedProviders.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<List<Client>> allClients() async {
    await _roundTrip();
    return seedClients;
  }
}
