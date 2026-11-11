import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

import 'http.dart';

/// Ceo HTTP server: putanje, beleženje zahteva i pretvaranje izuzetaka u `problem+json`.
Handler buildHandler(Pool<void> database) {
  final router = RelicRouter()
    ..get(ApiPaths.health, (request) => _health(database))
    ..fallback = respondWith((request) => problemResponse(notFoundRoute));
  return const Pipeline().addMiddleware(logRequests()).addMiddleware(handleErrors()).addHandler(router.asHandler);
}

/// Server radi i baza odgovara.
Future<Response> _health(Pool<void> database) async {
  await database.execute('SELECT 1');
  return Response.ok(body: Body.fromString('ok'));
}
