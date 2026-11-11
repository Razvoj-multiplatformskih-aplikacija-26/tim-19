part of 'session_bloc.dart';

/// Zašto korisnik nije prijavljen; ekran za prijavu bira poruku.
enum SignOutReason { signedOut, expired, unreachable, wrongApp }

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => const [];
}

/// Sačuvana prijava se još proverava.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SignedOut extends SessionState {
  const SignedOut({this.reason});

  final SignOutReason? reason;

  @override
  List<Object?> get props => [reason];
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}
