import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'screens/catalog_screen.dart';
import 'screens/home_shell.dart';
import 'screens/my_requests_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/provider_detail_screen.dart';
import 'screens/request_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';

/// Adresa po ekranu:
/// `/` (početni ekran po ulozi), `/prijava`, `/katalog`, `/katalog/:providerId`, `/katalog/:providerId/novi-zahtev`,
/// `/zahtevi`, `/zahtevi/:requestId`, `/podesavanja`.
///
/// Prijava odlučuje kuda korisnik sme: bez prijave samo `/prijava`, a posle prijave (ili isteka) [SessionBloc]
/// menja stanje i ruter ga sam preusmerava.
GoRouter createRouter({required SessionBloc session, String? initialLocation}) {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation ?? '/',
    refreshListenable: _SessionChanges(session.stream),
    redirect: (context, state) => _redirect(session.state, state),
    routes: [
      GoRoute(
        path: '/pokretanje',
        builder: (context, state) => const LoadingView(label: 'Provera prijave…'),
      ),
      // Početni ekran zavisi od uloge: klijent u katalog, pružalac u zahteve upućene njemu.
      GoRoute(
        path: '/',
        redirect: (context, state) => switch (session.state) {
          SignedIn(:final user) => homeOf(user),
          _ => null,
        },
      ),
      GoRoute(path: '/prijava', builder: (context, state) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/katalog',
                builder: (context, state) => const CatalogScreen(),
                routes: [
                  GoRoute(
                    path: ':providerId',
                    parentNavigatorKey: root,
                    builder: (context, state) =>
                        ProviderDetailScreen(id: ProviderId(state.pathParameters['providerId']!)),
                    routes: [
                      GoRoute(
                        path: 'novi-zahtev',
                        parentNavigatorKey: root,
                        builder: (context, state) =>
                            NewRequestScreen(providerId: ProviderId(state.pathParameters['providerId']!)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/zahtevi',
                builder: (context, state) => const MyRequestsScreen(),
                routes: [
                  GoRoute(
                    path: ':requestId',
                    parentNavigatorKey: root,
                    builder: (context, state) => RequestDetailScreen(id: RequestId(state.pathParameters['requestId']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/podesavanja', builder: (context, state) => const SettingsScreen())],
          ),
        ],
      ),
    ],
  );
}

/// Početni ekran po ulozi: klijent bira u katalogu, pružalac radi sa zahtevima upućenim njemu.
String homeOf(User user) => AccessPolicy.canSendRequests(user) ? '/katalog' : '/zahtevi';

String? _redirect(SessionState session, GoRouterState state) {
  final at = state.matchedLocation;
  final wanted = state.uri.queryParameters['posle'];
  return switch (session) {
    // Dok se sačuvana prijava proverava, pamti se kuda je korisnik krenuo.
    SessionUnknown() when at != '/pokretanje' => Uri(
      path: '/pokretanje',
      queryParameters: {'posle': '${state.uri}'},
    ).toString(),
    SessionUnknown() => null,
    SignedOut() when at != '/prijava' => Uri(path: '/prijava', queryParameters: {'posle': ?wanted}).toString(),
    SignedOut() => null,
    SignedIn(:final user) when at == '/prijava' || at == '/pokretanje' => wanted ?? homeOf(user),
    SignedIn() => null,
  };
}

/// Ruter ponovo proverava preusmerenje kad god se prijava promeni.
final class _SessionChanges extends ChangeNotifier {
  _SessionChanges(Stream<SessionState> changes) {
    _subscription = changes.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
