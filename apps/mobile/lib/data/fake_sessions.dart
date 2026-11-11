import 'dart:async';

import 'package:domain/domain.dart';

import 'in_memory_backend.dart';
import 'seed.dart';

/// Lažna prijava za testove i demo bez servera. Nalozi su isti kao na serveru, lozinka je [password].
/// Prijava menja korisnika u čije ime radi lažni port, kao što na serveru prijava određuje ko poziva.
final class FakeSessions implements SessionRepository {
  FakeSessions(this._backend, {User? signedIn}) : _current = signedIn {
    if (signedIn != null) _backend.session = signedIn;
  }

  static const password = 'demo';

  static const accounts = {'klijent1': meUser, 'pruzalac1': markoUser, 'moderator1': moderatorUser};

  final InMemoryBackend _backend;
  User? _current;
  final _expirations = StreamController<void>.broadcast();

  /// Za proveru isteka prijave bez servera.
  void expire() => _expirations.add(null);

  @override
  Future<Result<User>> signIn({required String username, required String password, required ClientApp app}) async {
    final user = accounts[username];
    if (user == null || password != FakeSessions.password) return const Failure(InvalidCredentials());
    final result = signInTo(app, user);
    if (result case Success(:final value)) {
      _current = value;
      _backend.session = value;
    }
    return result;
  }

  @override
  Future<User?> current() async => _current;

  @override
  Future<void> signOut() async => _current = null;

  @override
  Stream<void> get expirations => _expirations.stream;
}
