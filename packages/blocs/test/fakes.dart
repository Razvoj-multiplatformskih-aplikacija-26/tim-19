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
final class FakeRepository implements RequestsRepository, ProvidersRepository, ClientsRepository {
  FakeRepository({List<CollaborationRequest>? requests, this.providers = const [marko, hidden], this.session = anaUser})
    : requests = [...?requests];

  final List<CollaborationRequest> requests;
  final List<Provider> providers;

  /// Korisnik u čije ime lažni port pravi zahteve (na serveru ga daje prijava).
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
  Future<List<CollaborationRequest>> requestsOfClient(ClientId clientId) async {
    _maybeFail();
    return requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<List<CollaborationRequest>> allRequests() async {
    _maybeFail();
    return [...requests];
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    _maybeFail();
    return requests.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async {
    _maybeFail();
    final provider = providers.firstWhere((p) => p.id == draft.providerId);
    final result = createRequest(
      draft,
      by: session,
      provider: provider,
      existing: requests,
      id: RequestId('new-${_nextId++}'),
      now: createdAt,
    );
    if (result case Success(:final value)) requests.add(value);
    return result;
  }

  @override
  Future<Result<CollaborationRequest>> update(CollaborationRequest request, {required RequestStatus from}) async {
    _maybeFail();
    final index = requests.indexWhere((r) => r.id == request.id);
    if (index < 0) return const Failure(NotFound());
    // Kao server: izmena nad zastarelim stanjem se odbija.
    if (requests[index].status != from) return Failure(StaleRequest(requests[index].status));
    requests[index] = request;
    return Success(request);
  }

  @override
  Future<List<Provider>> allProviders() async {
    _maybeFail();
    return providers;
  }

  @override
  Future<Provider?> providerById(ProviderId id) async => providers.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<Client>> allClients() async {
    _maybeFail();
    return const [ana, boris];
  }
}
