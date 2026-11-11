part of 'session_bloc.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// Pri pokretanju: obnovi sačuvanu prijavu, ako je ima i ako važi.
final class SessionRestoreRequested extends SessionEvent {
  const SessionRestoreRequested();
}

/// Korisnik se upravo prijavio (forma za prijavu).
final class SessionStarted extends SessionEvent {
  const SessionStarted(this.user);

  final User user;
}

final class SignOutRequested extends SessionEvent {
  const SignOutRequested();
}

/// Server je rekao da je prijava istekla.
final class SessionExpired extends SessionEvent {
  const SessionExpired();
}
