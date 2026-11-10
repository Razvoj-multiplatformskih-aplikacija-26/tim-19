import 'package:domain/domain.dart';

import 'data/in_memory_backend.dart';
import 'data/seed.dart' as seed;

/// Jedino mesto koje bira implementaciju portova. Ekrani vide samo portove.
final class BackofficeDependencies {
  const BackofficeDependencies({
    required this.moderator,
    required this.requests,
    required this.providers,
    required this.clients,
    this.fake,
  });

  factory BackofficeDependencies.fake({Duration latency = const Duration(milliseconds: 500)}) {
    final backend = InMemoryBackend(latency: latency);
    return BackofficeDependencies(
      moderator: seed.moderator,
      requests: backend,
      providers: backend,
      clients: backend,
      fake: backend,
    );
  }

  final User moderator;
  final RequestsRepository requests;
  final ProvidersRepository providers;
  final ClientsRepository clients;

  /// Prekidači za demo grešaka; `null` kada port nije lažan.
  final InMemoryBackend? fake;
}
