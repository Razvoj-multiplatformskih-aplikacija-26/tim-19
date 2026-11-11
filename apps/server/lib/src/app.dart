import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

import 'cors.dart';
import 'handlers.dart';
import 'http.dart';
import 'sessions.dart';

/// Ceo HTTP server: putanje, beleženje zahteva, CORS za pregledač i pretvaranje izuzetaka u `problem+json`.
/// Bez prijave je dostupan samo katalog (u KT4 ide na javni veb); sve ostalo traži prijavu.
Handler buildHandler(
  Pool<void> database,
  SessionHandlers sessions,
  RequestHandlers handlers, {
  required List<String> corsOrigins,
}) {
  final signedIn = sessions.signedIn;
  final optional = sessions.optionallySignedIn;
  final router = RelicRouter()
    ..get(ApiPaths.health, (request) => _health(database))
    ..post(ApiPaths.sessions, sessions.logIn)
    ..get(ApiPaths.currentSession, signedIn(sessions.current))
    ..delete(ApiPaths.currentSession, signedIn(sessions.logOut))
    ..get(ApiPaths.providers, optional(handlers.providers))
    ..get(ApiPaths.provider(':id'), optional(handlers.provider))
    ..get(ApiPaths.clients, signedIn(handlers.clients))
    ..get(ApiPaths.requests, signedIn(handlers.requests))
    ..post(ApiPaths.requests, signedIn(handlers.create))
    ..get(ApiPaths.request(':id'), signedIn(handlers.find))
    ..post(ApiPaths.cancellation(':id'), signedIn(handlers.cancel))
    ..post(ApiPaths.completion(':id'), signedIn(handlers.complete))
    ..post(ApiPaths.revision(':id'), signedIn(handlers.revise))
    ..post(ApiPaths.acceptance(':id'), signedIn(handlers.accept))
    ..post(ApiPaths.rejection(':id'), signedIn(handlers.reject))
    ..post(ApiPaths.closure(':id'), signedIn(handlers.close))
    ..post(ApiPaths.reopening(':id'), signedIn(handlers.reopen))
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
