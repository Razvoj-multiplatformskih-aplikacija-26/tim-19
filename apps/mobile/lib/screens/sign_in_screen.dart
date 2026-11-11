import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';

/// Prijava u mobilnu aplikaciju (klijenti i pružaoci). Ekran samo šalje unos i crta stanje forme.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => LoginFormBloc(sessions: context.read<AppDependencies>().sessions, app: ClientApp.mobile),
    child: BlocConsumer<LoginFormBloc, LoginFormState>(
      listener: (context, state) {
        if (state case LoginSucceeded(:final user)) context.read<SessionBloc>().add(SessionStarted(user));
      },
      builder: (context, form) {
        final session = context.watch<SessionBloc>().state;
        return Scaffold(
          body: SafeArea(
            child: SignInForm(
              title: 'SoundConnect',
              subtitle: 'Prijava za klijente i pružaoce usluga',
              busy: form is LoginSubmitting || form is LoginSucceeded,
              notice: form is LoginIdle && session is SignedOut ? signOutMessage(session.reason) : null,
              error: switch (form) {
                LoginIncomplete() => signInIncompleteMessage,
                LoginRejected(:final error) => domainErrorMessage(error),
                LoginFailed(:final cause) => failureMessage(cause),
                _ => null,
              },
              onSubmit: (username, password) =>
                  context.read<LoginFormBloc>().add(LoginSubmitted(username: username, password: password)),
            ),
          ),
        );
      },
    ),
  );
}

/// Zašto je korisnik na prijavi; `null` pri prvom pokretanju.
String? signOutMessage(SignOutReason? reason) => switch (reason) {
  null => null,
  SignOutReason.signedOut => 'Odjavljeni ste.',
  SignOutReason.expired => sessionExpiredMessage,
  SignOutReason.unreachable => 'Server nije dostupan, pa prijava nije proverena. Pokušajte ponovo.',
  SignOutReason.wrongApp => domainErrorMessage(const WrongApp(ClientApp.mobile)),
};
