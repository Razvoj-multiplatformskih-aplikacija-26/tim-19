import 'package:domain/domain.dart';

import 'seed.dart';

/// Lažna implementacija portova u memoriji, sa kašnjenjem i prekidačima za grešku i prazan odgovor.
final class InMemoryBackend implements RequestsRepository, ProvidersRepository {
  InMemoryBackend({DateTime? now, this.latency = const Duration(milliseconds: 700)})
    : _requests = seedRequests(now ?? DateTime.now());

  final Duration latency;
  final List<CollaborationRequest> _requests;
  final List<Provider> _providers = [...seedProviders];

  /// Koliko sledećih poziva baca grešku.
  int failingRequests = 0;

  /// Koliko sledećih poziva liste vraća prazan odgovor.
  int emptyResponses = 0;
  int _nextId = 1;

  Future<void> _roundTrip() async {
    await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simuliran prekid veze');
    }
  }

  bool _answersEmpty() {
    if (emptyResponses == 0) return false;
    emptyResponses--;
    return true;
  }

  @override
  Future<List<CollaborationRequest>> requestsOfClient(ClientId clientId) async {
    await _roundTrip();
    if (_answersEmpty()) return const [];
    return _requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<List<CollaborationRequest>> allRequests() async {
    await _roundTrip();
    return [..._requests];
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async {
    await _roundTrip();
    final provider = _providers.where((p) => p.id == draft.providerId).firstOrNull;
    if (provider == null) return const Failure(ProviderNotListed());
    final result = createRequest(
      draft,
      provider: provider,
      existing: _requests,
      id: RequestId('local-${_nextId++}'),
      now: DateTime.now(),
    );
    if (result case Success(:final value)) _requests.add(value);
    return result;
  }

  @override
  Future<Result<CollaborationRequest>> update(CollaborationRequest request, {required RequestStatus from}) async {
    await _roundTrip();
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index < 0) return const Failure(NotFound());
    final stored = _requests[index];
    // Neko je u međuvremenu promenio zahtev (u KT2 to proverava server).
    if (stored.status != from) {
      return Failure(InvalidTransition(from: stored.status, to: request.status, actor: Actor.client));
    }
    _requests[index] = request;
    return Success(request);
  }

  @override
  Future<List<Provider>> allProviders() async {
    await _roundTrip();
    return [..._providers];
  }

  @override
  Future<Provider?> providerById(ProviderId id) async {
    await _roundTrip();
    return _providers.where((p) => p.id == id).firstOrNull;
  }
}
