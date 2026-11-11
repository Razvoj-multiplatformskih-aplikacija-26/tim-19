import 'dart:async';

import 'package:domain/domain.dart';

import 'seed.dart';

/// Lažna prijava za testove i demo bez servera. Nalozi su isti kao na serveru, lozinka je [password];
/// pravo na backoffice proverava isti [AccessPolicy] kao server.
final class FakeSessions implements SessionRepository {
  FakeSessions({User? signedIn}) : _current = signedIn;

  static const password = 'demo';

  static const accounts = {
    'moderator1': moderator,
    'klijent1': User(id: UserId('c-sava'), name: 'Sava Radošević', role: Role.client),
    'pruzalac1': User(id: UserId('p-marko'), name: 'Marko „Mix“ Petrović', role: Role.provider),
  };

  User? _current;
  final _expirations = StreamController<void>.broadcast();

  /// Za proveru isteka prijave bez servera.
  void expire() => _expirations.add(null);

  @override
  Future<Result<User>> signIn({required String username, required String password, required ClientApp app}) async {
    final user = accounts[username];
    if (user == null || password != FakeSessions.password) return const Failure(InvalidCredentials());
    final result = signInTo(app, user);
    if (result case Success(:final value)) _current = value;
    return result;
  }

  @override
  Future<User?> current() async => _current;

  @override
  Future<void> signOut() async => _current = null;

  @override
  Stream<void> get expirations => _expirations.stream;
}
