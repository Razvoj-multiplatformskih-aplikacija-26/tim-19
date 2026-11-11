import 'package:domain/domain.dart';

import 'seed.dart';

/// Lažna implementacija portova u memoriji backoffice-a, sa kašnjenjem i prekidačem za grešku.
/// Podaci nisu sinhronizovani sa mobilnom aplikacijom; pravo, pravilo i prelaz proverava domen.
final class InMemoryBackend implements RequestsRepository, ProvidersRepository, ClientsRepository {
  InMemoryBackend({DateTime? now, this.latency = const Duration(milliseconds: 500), this.session = moderator})
    : _requests = seedRequests(now ?? DateTime.now());

  final Duration latency;

  /// Korisnik u čije ime lažni port radi; na serveru ga daje prijava.
  final User session;
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
  Future<RequestPage> requests({RequestStatus? status, int offset = 0, int limit = 50}) async {
    await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return const RequestPage(items: [], total: 0);
    }
    final visible = [
      for (final r in _requests)
        if (AccessPolicy.canView(session, r) && (status == null || r.status == status)) r,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return RequestPage(items: visible.skip(offset).take(limit).toList(), total: visible.length, offset: offset);
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  /// Zahteve pravi klijent u mobilnoj aplikaciji, ne moderator.
  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async {
    await _roundTrip();
    return const Failure(NotAllowed());
  }

  @override
  Future<Result<CollaborationRequest>> apply(RequestAction action, RequestId id, {required RequestStatus from}) async {
    await _roundTrip();
    final index = _requests.indexWhere((r) => r.id == id);
    if (index < 0) return const Failure(NotFound());
    final stored = _requests[index];
    // Neko je u međuvremenu promenio zahtev.
    if (stored.status != from) return Failure(StaleRequest(stored.status));
    final next = applyAction(action, stored, by: session);
    if (next case Success(:final value)) _requests[index] = value;
    return next;
  }

  /// Moderator vidi sve pružaoce, i neverifikovane.
  @override
  Future<List<CatalogEntry>> catalog() async {
    await _roundTrip();
    return [for (final p in seedProviders) CatalogEntry(provider: p, freeSlots: freeSlots(p, _requests))];
  }

  @override
  Future<CatalogEntry?> entry(ProviderId id) async {
    await _roundTrip();
    final provider = seedProviders.where((p) => p.id == id).firstOrNull;
    return provider == null ? null : CatalogEntry(provider: provider, freeSlots: freeSlots(provider, _requests));
  }

  @override
  Future<List<Client>> allClients() async {
    await _roundTrip();
    return seedClients;
  }
}
