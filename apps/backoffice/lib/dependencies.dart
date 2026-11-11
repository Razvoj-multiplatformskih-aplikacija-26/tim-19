import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'data/fake_sessions.dart';
import 'data/in_memory_backend.dart';
import 'data/secure_token_store.dart';
import 'data/seed.dart' as seed;

/// Jedino mesto koje bira implementaciju portova. Ekrani i Bloc-ovi vide samo portove.
final class BackofficeDependencies {
  const BackofficeDependencies({
    required this.sessions,
    required this.requests,
    required this.providers,
    required this.clients,
    this.fake,
    this.fakeSessions,
  });

  /// Server, preko zajedničkog `api_client`-a. Na Windows-u token čuva Credential Manager; u pregledaču
  /// prijavu nosi HttpOnly kolačić, pa token ne postoji u skladištu dostupnom skriptama.
  factory BackofficeDependencies.server({required Uri baseUri}) {
    final api = ApiClient(baseUri: baseUri, tokens: kIsWeb ? MemoryTokenStore() : const SecureTokenStore());
    return BackofficeDependencies(
      sessions: HttpSessionRepository(api),
      requests: HttpRequestsRepository(api),
      providers: HttpProvidersRepository(api),
      clients: HttpClientsRepository(api),
    );
  }

  /// Lažni port u memoriji (testovi, demo bez servera). [signedIn] je sačuvana prijava pri pokretanju.
  factory BackofficeDependencies.fake({
    Duration latency = const Duration(milliseconds: 500),
    User? signedIn = seed.moderator,
  }) {
    final backend = InMemoryBackend(latency: latency);
    final sessions = FakeSessions(signedIn: signedIn);
    return BackofficeDependencies(
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

/// Adresa servera bez izmene koda: `localhost:8080` na Windows-u i u pregledaču, ili `--dart-define=SERVER_URL=…`.
Uri serverAddress() {
  const configured = String.fromEnvironment('SERVER_URL');
  return Uri.parse(configured.isEmpty ? 'http://localhost:8080' : configured);
}
