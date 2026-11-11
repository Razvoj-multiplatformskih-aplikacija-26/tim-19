part of 'login_form_bloc.dart';

sealed class LoginFormState extends Equatable {
  const LoginFormState();

  @override
  List<Object?> get props => const [];
}

final class LoginIdle extends LoginFormState {
  const LoginIdle();
}

/// Korisničko ime ili lozinka nisu uneti.
final class LoginIncomplete extends LoginFormState {
  const LoginIncomplete();
}

final class LoginSubmitting extends LoginFormState {
  const LoginSubmitting();
}

final class LoginSucceeded extends LoginFormState {
  const LoginSucceeded(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Server je odbio prijavu: [InvalidCredentials] ili [WrongApp].
final class LoginRejected extends LoginFormState {
  const LoginRejected(this.error);

  final DomainError error;

  @override
  List<Object?> get props => [error];
}

/// Server nije dostupan.
final class LoginFailed extends LoginFormState {
  const LoginFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}
