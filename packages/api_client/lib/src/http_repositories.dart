import 'package:api_contract/api_contract.dart';
import 'package:api_mapping/api_mapping.dart';
import 'package:domain/domain.dart';

import 'api_client.dart';

/// Zahtevi preko servera; isti port kao lažna implementacija iz KT1, pa Bloc-ovi i ekrani ne znaju razliku.
final class HttpRequestsRepository implements RequestsRepository {
  const HttpRequestsRepository(this._api);

  final ApiClient _api;

  @override
  Future<RequestPage> requests({RequestStatus? status, int offset = 0, int limit = 50}) async {
    final answer = await _api.get(
      ApiPaths.requests,
      query: {
        ApiQuery.limit: '$limit',
        ApiQuery.offset: '$offset',
        if (status != null) ApiQuery.status: status.toDto(),
      },
    );
    return accepted(answer, (json) {
      final page = PageDto.fromJson(object(json), RequestDto.fromJson);
      // Zahtev u stanju koje ova verzija ne poznaje se preskače, ostali ostaju.
      return RequestPage(items: requestsFromDtos(page.items), total: page.total, offset: page.offset);
    });
  }

  @override
  Future<CollaborationRequest?> getById(RequestId id) async {
    final answer = await _api.get(ApiPaths.request(id.value));
    if (answer case ApiRejected(error: NotFound() || NotAllowed())) return null;
    return accepted(answer, (json) => RequestDto.fromJson(object(json)).toDomain());
  }

  @override
  Future<Result<CollaborationRequest>> create(NewRequest draft) async =>
      _result(await _api.post(ApiPaths.requests, body: draft.toDto().toJson()));

  @override
  Future<Result<CollaborationRequest>> apply(RequestAction action, RequestId id, {required RequestStatus from}) async {
    final path = switch (action) {
      RequestAction.cancel => ApiPaths.cancellation(id.value),
      RequestAction.complete => ApiPaths.completion(id.value),
      RequestAction.revise => ApiPaths.revision(id.value),
      RequestAction.accept => ApiPaths.acceptance(id.value),
      RequestAction.reject => ApiPaths.rejection(id.value),
      RequestAction.close => ApiPaths.closure(id.value),
      RequestAction.reopen => ApiPaths.reopening(id.value),
    };
    return _result(await _api.post(path, body: ActionDto(from: from.toDto()).toJson()));
  }

  /// Zahtev koji je server prihvatio, a ova verzija ne razume (novo stanje), je [ServerRejected]: korisnik
  /// dobija poruku da osveži ekran umesto pada aplikacije.
  Result<CollaborationRequest> _result(ApiAnswer answer) =>
      switch (resultOf(answer, (json) => RequestDto.fromJson(object(json)).toDomain())) {
        Success(value: final request?) => Success(request),
        Success(value: null) => const Failure(ServerRejected('unknown-status')),
        Failure(:final error) => Failure(error),
      };
}

/// Katalog sa slobodnim mestima koja računa server.
final class HttpProvidersRepository implements ProvidersRepository {
  const HttpProvidersRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<CatalogEntry>> catalog() async =>
      accepted(await _api.get(ApiPaths.providers), (json) => [for (final item in objects(json)) _entry(item)]);

  @override
  Future<CatalogEntry?> entry(ProviderId id) async {
    final answer = await _api.get(ApiPaths.provider(id.value));
    if (answer case ApiRejected(error: NotFound())) return null;
    return accepted(answer, (json) => _entry(object(json)));
  }

  CatalogEntry _entry(Map<String, Object?> json) {
    final dto = ProviderDto.fromJson(json);
    return CatalogEntry(provider: dto.toDomain(), freeSlots: dto.freeSlots);
  }
}

/// Imena klijenata za tabelu moderatora.
final class HttpClientsRepository implements ClientsRepository {
  const HttpClientsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Client>> allClients() async => accepted(
    await _api.get(ApiPaths.clients),
    (json) => [for (final item in objects(json)) ClientDto.fromJson(item).toDomain()],
  );
}

/// Prijava preko servera. Token čuva [ApiClient.tokens] (bezbedno skladište platforme), a u pregledaču
/// prijavu nosi HttpOnly kolačić. Lozinka se ne čuva.
final class HttpSessionRepository implements SessionRepository {
  const HttpSessionRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<User>> signIn({required String username, required String password, required ClientApp app}) async {
    final login = LoginDto(username: username, password: password, app: app.toDto(), cookie: _api.keepsSessionInCookie);
    final result = resultOf(
      await _api.post(ApiPaths.sessions, body: login.toJson()),
      (json) => SessionDto.fromJson(object(json)),
    );
    switch (result) {
      case Success(value: final session):
        if (session.token case final token?) await _api.tokens.write(token);
        return Success(readJson(session.user.toDomain));
      case Failure(:final error):
        return Failure(error);
    }
  }

  @override
  Future<User?> current() async {
    if (!_api.keepsSessionInCookie && await _api.tokens.read() == null) return null;
    try {
      final answer = await _api.get(ApiPaths.currentSession);
      return accepted<User>(answer, (json) => SessionDto.fromJson(object(json)).user.toDomain());
    } on RepositoryException catch (error) {
      if (error.failure != RepositoryFailure.sessionExpired) rethrow;
      await _api.tokens.clear();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.delete(ApiPaths.currentSession);
    } on RepositoryException {
      // Odjava uspeva i bez mreže: token se briše na uređaju, a na serveru ionako ističe.
    } finally {
      await _api.tokens.clear();
    }
  }

  @override
  Stream<void> get expirations => _api.expirations;
}
