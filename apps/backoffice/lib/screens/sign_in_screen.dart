import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';

/// Prijava u backoffice. Korisnik mobilne aplikacije dobija razlog („Backoffice je za moderatore…“) sa servera.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        LoginFormBloc(sessions: context.read<BackofficeDependencies>().sessions, app: ClientApp.backoffice),
    child: BlocConsumer<LoginFormBloc, LoginFormState>(
      listener: (context, state) {
        if (state case LoginSucceeded(:final user)) context.read<SessionBloc>().add(SessionStarted(user));
      },
      builder: (context, form) {
        final session = context.watch<SessionBloc>().state;
        return Scaffold(
          body: SignInForm(
            title: 'SoundConnect backoffice',
            subtitle: 'Prijava za moderatore',
            busy: form is LoginSubmitting || form is LoginSucceeded,
            notice: form is LoginIdle && session is SignedOut ? _signOutMessage(session.reason) : null,
            error: switch (form) {
              LoginIncomplete() => signInIncompleteMessage,
              LoginRejected(:final error) => domainErrorMessage(error),
              LoginFailed(:final cause) => failureMessage(cause),
              _ => null,
            },
            onSubmit: (username, password) =>
                context.read<LoginFormBloc>().add(LoginSubmitted(username: username, password: password)),
          ),
        );
      },
    ),
  );
}

String? _signOutMessage(SignOutReason? reason) => switch (reason) {
  null => null,
  SignOutReason.signedOut => 'Odjavljeni ste.',
  SignOutReason.expired => sessionExpiredMessage,
  SignOutReason.unreachable => 'Server nije dostupan, pa prijava nije proverena. Pokušajte ponovo.',
  SignOutReason.wrongApp => domainErrorMessage(const WrongApp(ClientApp.backoffice)),
};
