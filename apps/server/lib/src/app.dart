import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

import 'cors.dart';
import 'http.dart';
import 'sessions.dart';

/// Ceo HTTP server: putanje, beleženje zahteva, CORS za pregledač i pretvaranje izuzetaka u `problem+json`.
Handler buildHandler(Pool<void> database, SessionHandlers sessions, {required List<String> corsOrigins}) {
  final signedIn = sessions.signedIn;
  final router = RelicRouter()
    ..get(ApiPaths.health, (request) => _health(database))
    ..post(ApiPaths.sessions, sessions.logIn)
    ..get(ApiPaths.currentSession, signedIn(sessions.current))
    ..delete(ApiPaths.currentSession, signedIn(sessions.logOut))
    ..fallback = respondWith((request) => problemResponse(notFoundRoute));
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(allowOrigins(corsOrigins))
      .addMiddleware(handleErrors())
      .addHandler(router.asHandler);
}

/// Server radi i baza odgovara.
Future<Response> _health(Pool<void> database) async {
  await database.execute('SELECT 1');
  return Response.ok(body: Body.fromString('ok'));
}
