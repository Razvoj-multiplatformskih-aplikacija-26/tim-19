import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';

import 'data/fake_sessions.dart';
import 'data/in_memory_backend.dart';
import 'data/seed.dart';

/// Jedino mesto koje bira implementaciju portova. Ekrani i Bloc-ovi vide samo portove, pa ne znaju da li
/// podaci dolaze sa servera ili iz lažne implementacije.
final class AppDependencies {
  const AppDependencies({
    required this.sessions,
    required this.requests,
    required this.providers,
    required this.clients,
    this.fake,
    this.fakeSessions,
  });

  /// Server, preko zajedničkog `api_client`-a; token u bezbednom skladištu platforme ([tokens]).
  factory AppDependencies.server({required Uri baseUri, required TokenStore tokens}) {
    final api = ApiClient(baseUri: baseUri, tokens: tokens);
    return AppDependencies(
      sessions: HttpSessionRepository(api),
      requests: HttpRequestsRepository(api),
      providers: HttpProvidersRepository(api),
      clients: HttpClientsRepository(api),
    );
  }

  /// Lažni port u memoriji (testovi, demo bez servera). [signedIn] je sačuvana prijava pri pokretanju.
  factory AppDependencies.fake({Duration latency = const Duration(milliseconds: 700), User? signedIn = meUser}) {
    final backend = InMemoryBackend(latency: latency);
    final sessions = FakeSessions(backend, signedIn: signedIn);
    return AppDependencies(
      sessions: sessions,
      requests: backend,
      providers: backend,
      clients: backend,
      fake: backend,
      fakeSessions: sessions,
    );
  }

  final SessionRepository sessions;
  final RequestsRepository requests;
  final ProvidersRepository providers;
  final ClientsRepository clients;

  /// Prekidači za demo grešaka; `null` kada port nije lažan.
  final InMemoryBackend? fake;
  final FakeSessions? fakeSessions;
}
