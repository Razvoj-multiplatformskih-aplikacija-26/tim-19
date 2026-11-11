/// Gde se čuva token prijave. Aplikacije daju bezbedno skladište platforme (Keystore, Credential Manager);
/// lozinka se nigde ne čuva.
abstract interface class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Token samo u memoriji: za testove i za pregledač, gde prijavu nosi HttpOnly kolačić.
final class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
