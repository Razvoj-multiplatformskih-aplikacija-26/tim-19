import 'package:domain/domain.dart';

final createdAt = DateTime.utc(2026, 11, 1, 12);

const ana = Client(id: ClientId('c-ana'), name: 'Ana');
const boris = Client(id: ClientId('c-boris'), name: 'Boris');

/// Nalozi prijavljenih korisnika; klijent ima isti identifikator kao profil.
const anaUser = User(id: UserId('c-ana'), name: 'Ana', role: Role.client);
const borisUser = User(id: UserId('c-boris'), name: 'Boris', role: Role.client);
const kosta = User(id: UserId('m-kosta'), name: 'Kosta', role: Role.moderator);

const marko = Provider(
  id: ProviderId('p-marko'),
  name: 'Marko Miks',
  verified: true,
  genres: [Genre.hipHop],
  services: [ServiceType.mixing, ServiceType.mastering],
  priceFrom: 80,
  capacity: 3,
);

const hidden = Provider(
  id: ProviderId('p-hidden'),
  name: 'Neverifikovan',
  verified: false,
  genres: [Genre.pop],
  services: [ServiceType.beat],
  priceFrom: 40,
  capacity: 3,
);

CollaborationRequest request(
  String id,
  RequestStatus status, {
  Client client = ana,
  Provider provider = marko,
  int minutes = 0,
}) => CollaborationRequest(
  id: RequestId(id),
  clientId: client.id,
  providerId: provider.id,
  service: ServiceType.mixing,
  note: 'Miks singla',
  status: status,
  createdAt: createdAt.add(Duration(minutes: minutes)),
);

/// Lažni port za testove, bez kašnjenja.
/// Lažni port za testove, bez kašnjenja. Radi kao mali server: pravo, pravilo i prelaz proverava domen.
final class FakeRepository implements RequestsRepository, ProvidersRepository, ClientsRepository {
  FakeRepository({List<CollaborationRequest>? requests, this.providers = const [marko, hidden], this.session = anaUser})
    : stored = [...?requests];

  /// Zahtevi „u bazi“ lažnog porta.
  final List<CollaborationRequest> stored;
  final List<Provider> providers;

  /// Korisnik u čije ime lažni port radi (na serveru ga daje prijava).
  final User session;
  int failNext = 0;
  int _nextId = 1;

  void _maybeFail() {
    if (failNext > 0) {
      failNext--;
      throw const RepositoryException('Simuliran prekid');
    }
  }

  @override
  Future<RequestPage> requests({RequestStatus? status, int offset = 0, int limit = 50}) async {
    _maybeFail();
    final visible = [
      for (final r in stored)
        if (AccessPolicy.canView(session, r) && (status == null || r.status == status)) r,
    ];
    return RequestPage(items: visible.skip(offset).take(limit).toList(), total: visible.length, offset: offset);
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    _maybeFail();
    return stored.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async {
    _maybeFail();
    final provider = providers.firstWhere((p) => p.id == draft.providerId);
    final result = createRequest(
      draft,
      by: session,
      provider: provider,
      existing: stored,
      id: RequestId('new-${_nextId++}'),
      now: createdAt,
    );
    if (result case Success(:final value)) stored.add(value);
    return result;
  }

  @override
  Future<Result<CollaborationRequest>> apply(RequestAction action, RequestId id, {required RequestStatus from}) async {
    _maybeFail();
    final index = stored.indexWhere((r) => r.id == id);
    if (index < 0) return const Failure(NotFound());
    // Kao server: izmena nad zastarelim stanjem se odbija.
    if (stored[index].status != from) return Failure(StaleRequest(stored[index].status));
    final next = applyAction(action, stored[index], by: session);
    if (next case Success(:final value)) stored[index] = value;
    return next;
  }

  @override
  Future<List<CatalogEntry>> catalog() async {
    _maybeFail();
    return [for (final p in providers) CatalogEntry(provider: p, freeSlots: freeSlots(p, stored))];
  }

  @override
  Future<CatalogEntry?> entry(ProviderId id) async {
    final p = providers.where((p) => p.id == id).firstOrNull;
    return p == null ? null : CatalogEntry(provider: p, freeSlots: freeSlots(p, stored));
  }

  @override
  Future<List<Client>> allClients() async {
    _maybeFail();
    return const [ana, boris];
  }
}
