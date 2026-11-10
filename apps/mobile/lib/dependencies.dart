import 'package:domain/domain.dart';

import 'data/in_memory_backend.dart';
import 'data/seed.dart';

/// Jedino mesto koje bira implementaciju portova. Ekrani vide samo portove.
final class AppDependencies {
  const AppDependencies({
    required this.user,
    required this.client,
    required this.requests,
    required this.providers,
    this.fake,
  });

  factory AppDependencies.fake({Duration latency = const Duration(milliseconds: 700)}) {
    final backend = InMemoryBackend(latency: latency);
    return AppDependencies(user: meUser, client: me, requests: backend, providers: backend, fake: backend);
  }

  /// Prijavljeni korisnik; do prijave u KT2 zakucan.
  final User user;

  /// Profil prijavljenog klijenta.
  final Client client;
  final RequestsRepository requests;
  final ProvidersRepository providers;

  /// Prekidači za demo grešaka; `null` kada port nije lažan.
  final InMemoryBackend? fake;
}
