import 'package:domain/domain.dart';

import 'seed.dart';

/// Lažna implementacija portova u memoriji, sa kašnjenjem i prekidačima za grešku i prazan odgovor.
/// Radi kao mali server: pravo, pravilo i prelaz proverava isti domenski kôd.
final class InMemoryBackend implements RequestsRepository, ProvidersRepository {
  InMemoryBackend({DateTime? now, this.latency = const Duration(milliseconds: 700), this.session = meUser})
    : _requests = seedRequests(now ?? DateTime.now());

  final Duration latency;

  /// Korisnik u čije ime lažni port radi; na serveru ga daje prijava.
  final User session;
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
  Future<RequestPage> requests({RequestStatus? status, int offset = 0, int limit = 50}) async {
    await _roundTrip();
    if (_answersEmpty()) return const RequestPage(items: [], total: 0);
    final visible = [
      for (final r in _requests)
        if (AccessPolicy.canView(session, r) && (status == null || r.status == status)) r,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return RequestPage(items: visible.skip(offset).take(limit).toList(), total: visible.length, offset: offset);
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id && AccessPolicy.canView(session, r)).firstOrNull;
  }

  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async {
    await _roundTrip();
    final provider = _providers.where((p) => p.id == draft.providerId).firstOrNull;
    if (provider == null) return const Failure(ProviderNotListed());
    final result = createRequest(
      draft,
      by: session,
      provider: provider,
      existing: _requests,
      id: RequestId('local-${_nextId++}'),
      now: DateTime.now(),
    );
    if (result case Success(:final value)) _requests.add(value);
    return result;
  }

  @override
  Future<Result<CollaborationRequest>> apply(RequestAction action, RequestId id, {required RequestStatus from}) async {
    await _roundTrip();
    final index = _requests.indexWhere((r) => r.id == id);
    if (index < 0) return const Failure(NotFound());
    final stored = _requests[index];
    if (!AccessPolicy.canView(session, stored)) return const Failure(NotAllowed());
    // Neko je u međuvremenu promenio zahtev.
    if (stored.status != from) return Failure(StaleRequest(stored.status));
    final next = applyAction(action, stored, by: session);
    if (next case Success(:final value)) _requests[index] = value;
    return next;
  }

  @override
  Future<List<CatalogEntry>> catalog() async {
    await _roundTrip();
    return [
      for (final p in _providers.where(isListedInCatalog))
        CatalogEntry(provider: p, freeSlots: freeSlots(p, _requests)),
    ];
  }

  @override
  Future<CatalogEntry?> entry(ProviderId id) async {
    await _roundTrip();
    final provider = _providers.where(isListedInCatalog).where((p) => p.id == id).firstOrNull;
    return provider == null ? null : CatalogEntry(provider: provider, freeSlots: freeSlots(provider, _requests));
  }
}
