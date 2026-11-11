import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'screens/requests_screen.dart';
import 'screens/sign_in_screen.dart';

/// Backoffice za moderatore. Bez prijave prikazuje prijavu; prijava ostaje posle ponovnog pokretanja
/// (Windows) i osvežavanja stranice (pregledač), a istek ili odjava vraćaju na prijavu.
class BackofficeApp extends StatefulWidget {
  const BackofficeApp({super.key, required this.dependencies});

  final BackofficeDependencies dependencies;

  @override
  State<BackofficeApp> createState() => _BackofficeAppState();
}

class _BackofficeAppState extends State<BackofficeApp> {
  late final SessionBloc _session = SessionBloc(sessions: widget.dependencies.sessions, app: ClientApp.backoffice)
    ..add(const SessionRestoreRequested());

  @override
  void dispose() {
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
    value: widget.dependencies,
    child: BlocProvider.value(
      value: _session,
      child: MaterialApp(
        title: 'SoundConnect backoffice',
        debugShowCheckedModeBanner: false,
        theme: SoundTheme.light(),
        darkTheme: SoundTheme.dark(),
        home: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, session) => switch (session) {
            SessionUnknown() => const Scaffold(body: LoadingView(label: 'Provera prijave…')),
            SignedOut() => const SignInScreen(),
            // Novi Bloc za svaku prijavu, da drugi nalog ne nasledi tuđe podatke.
            SignedIn(:final user) => BlocProvider(
              key: ValueKey(user.id),
              create: (_) => AdminRequestsBloc(
                requests: widget.dependencies.requests,
                providers: widget.dependencies.providers,
                clients: widget.dependencies.clients,
                moderator: user,
              )..add(const LoadAdminRequests()),
              child: const RequestsScreen(),
            ),
          },
        ),
      ),
    ),
  );
}
