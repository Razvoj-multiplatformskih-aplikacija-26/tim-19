import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'router.dart';

class SoundConnectApp extends StatefulWidget {
  const SoundConnectApp({super.key, required this.dependencies, this.initialLocation});

  final AppDependencies dependencies;
  final String? initialLocation;

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final SessionBloc _session = SessionBloc(sessions: widget.dependencies.sessions, app: ClientApp.mobile)
    ..add(const SessionRestoreRequested());
  late final GoRouter _router = createRouter(session: _session, initialLocation: widget.initialLocation);
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Poslednji prijavljeni korisnik. Njegovi Bloc-ovi ostaju dok ruter ne pređe na prijavu, da ekran koji se
  /// zatvara ne ostane bez podataka; nova prijava pravi nove Bloc-ove.
  User? _lastUser;

  @override
  void dispose() {
    _router.dispose();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
    value: widget.dependencies,
    child: BlocProvider.value(
      value: _session,
      child: MaterialApp.router(
        title: 'SoundConnect',
        debugShowCheckedModeBanner: false,
        theme: SoundTheme.light(),
        darkTheme: SoundTheme.dark(),
        scaffoldMessengerKey: _messenger,
        routerConfig: _router,
        builder: (context, child) => BlocBuilder<SessionBloc, SessionState>(
          builder: (context, session) {
            if (session case SignedIn(:final user)) _lastUser = user;
            final user = _lastUser;
            if (user == null) return child!;
            return _SignedInScope(
              key: ValueKey(user.id),
              user: user,
              dependencies: widget.dependencies,
              messenger: _messenger,
              child: child!,
            );
          },
        ),
      ),
    ),
  );
}

/// Bloc-ovi prijavljenog korisnika. Pravi ih iznova svaka prijava, pa drugi nalog ne vidi tuđe podatke.
class _SignedInScope extends StatelessWidget {
  const _SignedInScope({
    super.key,
    required this.user,
    required this.dependencies,
    required this.messenger,
    required this.child,
  });

  final User user;
  final AppDependencies dependencies;
  final GlobalKey<ScaffoldMessengerState> messenger;
  final Widget child;

  void _onNotice(BuildContext context, RequestsState state) {
    if (state is! RequestsLoaded) return;
    final notice = state.notice;
    if (notice == null) return;
    final text = switch (notice) {
      RequestActionDone(:final action) => actionDoneMessage(action),
      RequestActionRejected(:final error) => domainErrorMessage(error),
      RequestActionFailed(:final cause) => failureMessage(cause),
    };
    messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    // Akcija ili odbijanje sa servera menjaju slobodna mesta kod pružaoca.
    if (notice is! RequestActionFailed) context.read<CatalogBloc>().add(const LoadCatalog());
    context.read<RequestsBloc>().add(const RequestsNoticeShown());
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => RequestsBloc(
          requests: dependencies.requests,
          providers: dependencies.providers,
          clients: dependencies.clients,
          user: user,
        )..add(const LoadRequests()),
      ),
      BlocProvider(create: (_) => CatalogBloc(providers: dependencies.providers)..add(const LoadCatalog())),
    ],
    child: BlocListener<RequestsBloc, RequestsState>(
      listenWhen: (previous, current) => current is RequestsLoaded && current.notice != null,
      listener: _onNotice,
      child: child,
    ),
  );
}
