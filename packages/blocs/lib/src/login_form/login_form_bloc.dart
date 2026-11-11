import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'login_form_event.dart';
part 'login_form_state.dart';

/// Forma za prijavu. Pogrešnu lozinku i pogrešnu aplikaciju javlja server; poruku bira ekran.
final class LoginFormBloc extends Bloc<LoginFormEvent, LoginFormState> {
  LoginFormBloc({required this.sessions, required this.app}) : super(const LoginIdle()) {
    on<LoginSubmitted>((event, emit) async {
      if (state is LoginSubmitting) return;
      if (event.username.trim().isEmpty || event.password.isEmpty) return emit(const LoginIncomplete());
      emit(const LoginSubmitting());
      try {
        final result = await sessions.signIn(username: event.username.trim(), password: event.password, app: app);
        emit(switch (result) {
          Success(:final value) => LoginSucceeded(value),
          Failure(:final error) => LoginRejected(error),
        });
      } on RepositoryException catch (cause) {
        emit(LoginFailed(cause));
      }
    });
  }

  final SessionRepository sessions;
  final ClientApp app;
}
