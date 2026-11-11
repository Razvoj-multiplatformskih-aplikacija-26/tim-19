import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'session_event.dart';
part 'session_state.dart';

/// Ko je prijavljen u ovu aplikaciju. Prijavu čuva port (bezbedno skladište platforme ili kolačić), pa ona
/// ostaje posle ponovnog pokretanja i osvežavanja stranice; istek iz bilo kog poziva vraća na prijavu.
final class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({required this.sessions, required this.app}) : super(const SessionUnknown()) {
    on<SessionRestoreRequested>(_onRestore);
    on<SessionStarted>(_onStarted);
    on<SignOutRequested>((event, emit) async {
      await _signOutQuietly();
      emit(const SignedOut(reason: SignOutReason.signedOut));
    });
    on<SessionExpired>((event, emit) async {
      if (state is! SignedIn) return;
      await _signOutQuietly();
      emit(const SignedOut(reason: SignOutReason.expired));
    });
    _expirations = sessions.expirations.listen((_) => add(const SessionExpired()));
  }

  final SessionRepository sessions;

  /// Aplikacija u kojoj Bloc radi; pravo na nju proverava [AccessPolicy].
  final ClientApp app;
  late final StreamSubscription<void> _expirations;

  Future<void> _onRestore(SessionRestoreRequested event, Emitter<SessionState> emit) async {
    try {
      final user = await sessions.current();
      if (user == null) return emit(const SignedOut());
      add(SessionStarted(user));
    } on RepositoryException {
      emit(const SignedOut(reason: SignOutReason.unreachable));
    }
  }

  Future<void> _onStarted(SessionStarted event, Emitter<SessionState> emit) async {
    if (AccessPolicy.canSignIn(event.user, app)) return emit(SignedIn(event.user));
    // Sačuvana prijava druge uloge (npr. posle izmene naloga): ne ulazi, i kaže zašto.
    await _signOutQuietly();
    emit(const SignedOut(reason: SignOutReason.wrongApp));
  }

  Future<void> _signOutQuietly() async {
    try {
      await sessions.signOut();
    } on RepositoryException catch (cause, stackTrace) {
      addError(cause, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _expirations.cancel();
    return super.close();
  }
}
