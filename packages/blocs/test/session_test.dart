import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fakes.dart';

/// Lažni port za prijavu: zna jedan nalog po korisničkom imenu, lozinka je svuda „tajna“.
final class FakeSessions implements SessionRepository {
  FakeSessions({this.saved});

  /// Prijava sačuvana na uređaju (posle ponovnog pokretanja).
  User? saved;
  bool unreachable = false;
  int signOuts = 0;
  final _expirations = StreamController<void>.broadcast();

  static const accounts = {'klijent1': anaUser, 'moderator1': kosta};

  void expire() => _expirations.add(null);

  @override
  Future<Result<User>> signIn({required String username, required String password, required ClientApp app}) async {
    if (unreachable) throw const RepositoryException('Server nije dostupan');
    final user = accounts[username];
    if (user == null || password != 'tajna') return const Failure(InvalidCredentials());
    // Kao server: pravo na aplikaciju proverava AccessPolicy iz domena.
    return signInTo(app, user);
  }

  @override
  Future<User?> current() async {
    if (unreachable) throw const RepositoryException('Server nije dostupan');
    return saved;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    saved = null;
  }

  @override
  Stream<void> get expirations => _expirations.stream;
}

void main() {
  group('SessionBloc', () {
    late FakeSessions sessions;

    SessionBloc mobile() => SessionBloc(sessions: sessions, app: ClientApp.mobile);

    setUp(() => sessions = FakeSessions());

    blocTest<SessionBloc, SessionState>(
      'prijava sačuvana na uređaju ostaje posle ponovnog pokretanja',
      setUp: () => sessions.saved = anaUser,
      build: mobile,
      act: (bloc) => bloc.add(const SessionRestoreRequested()),
      expect: () => [const SignedIn(anaUser)],
    );

    blocTest<SessionBloc, SessionState>(
      'bez sačuvane prijave: ekran za prijavu',
      build: mobile,
      act: (bloc) => bloc.add(const SessionRestoreRequested()),
      expect: () => [const SignedOut()],
    );

    blocTest<SessionBloc, SessionState>(
      'sačuvana prijava druge uloge ne ulazi i briše se',
      setUp: () => sessions.saved = kosta,
      build: mobile,
      act: (bloc) => bloc.add(const SessionRestoreRequested()),
      expect: () => [const SignedOut(reason: SignOutReason.wrongApp)],
      verify: (_) => expect(sessions.signOuts, 1),
    );

    blocTest<SessionBloc, SessionState>(
      'server nije dostupan pri pokretanju: ekran to kaže',
      setUp: () => sessions.unreachable = true,
      build: mobile,
      act: (bloc) => bloc.add(const SessionRestoreRequested()),
      expect: () => [const SignedOut(reason: SignOutReason.unreachable)],
    );

    blocTest<SessionBloc, SessionState>(
      'istekla prijava iz bilo kog poziva vraća na prijavu sa razlogom',
      build: mobile,
      seed: () => const SignedIn(anaUser),
      act: (bloc) => sessions.expire(),
      expect: () => [const SignedOut(reason: SignOutReason.expired)],
    );

    blocTest<SessionBloc, SessionState>(
      'odjava briše prijavu',
      build: mobile,
      seed: () => const SignedIn(anaUser),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [const SignedOut(reason: SignOutReason.signedOut)],
      verify: (_) => expect(sessions.signOuts, 1),
    );
  });

  group('LoginFormBloc', () {
    late FakeSessions sessions;

    LoginFormBloc form(ClientApp app) => LoginFormBloc(sessions: sessions, app: app);

    setUp(() => sessions = FakeSessions());

    blocTest<LoginFormBloc, LoginFormState>(
      'uspešna prijava',
      build: () => form(ClientApp.mobile),
      act: (bloc) => bloc.add(const LoginSubmitted(username: ' klijent1 ', password: 'tajna')),
      expect: () => [const LoginSubmitting(), const LoginSucceeded(anaUser)],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'prazna polja se ne šalju',
      build: () => form(ClientApp.mobile),
      act: (bloc) => bloc.add(const LoginSubmitted(username: '', password: '')),
      expect: () => [const LoginIncomplete()],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'pogrešna lozinka',
      build: () => form(ClientApp.mobile),
      act: (bloc) => bloc.add(const LoginSubmitted(username: 'klijent1', password: 'x')),
      expect: () => [const LoginSubmitting(), const LoginRejected(InvalidCredentials())],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'korisnik mobilne aplikacije u backoffice-u: odbijen sa razlogom',
      build: () => form(ClientApp.backoffice),
      act: (bloc) => bloc.add(const LoginSubmitted(username: 'klijent1', password: 'tajna')),
      expect: () => [const LoginSubmitting(), const LoginRejected(WrongApp(ClientApp.backoffice))],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'server nije dostupan',
      setUp: () => sessions.unreachable = true,
      build: () => form(ClientApp.mobile),
      act: (bloc) => bloc.add(const LoginSubmitted(username: 'klijent1', password: 'tajna')),
      expect: () => [const LoginSubmitting(), isA<LoginFailed>()],
    );
  });
}
