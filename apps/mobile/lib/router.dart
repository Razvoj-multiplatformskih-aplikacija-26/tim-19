import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/catalog_screen.dart';
import 'screens/home_shell.dart';
import 'screens/my_requests_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/provider_detail_screen.dart';
import 'screens/request_detail_screen.dart';
import 'screens/settings_screen.dart';

/// Adresa po ekranu:
/// `/katalog`, `/katalog/:providerId`, `/katalog/:providerId/novi-zahtev`,
/// `/zahtevi`, `/zahtevi/:requestId`, `/podesavanja`.
GoRouter createRouter({String initialLocation = '/katalog'}) {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    routes: [
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
