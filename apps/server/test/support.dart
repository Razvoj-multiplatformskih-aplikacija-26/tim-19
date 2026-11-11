import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart' show IOAdapter, RelicServer;
import 'package:server/server.dart';

// Zajedničko za testove servera nad bazom. Baza mora da radi: docker compose up -d db
// Svaki test fajl ima svoju bazu, a fajlovi idu jedan po jedan (dart_test.yaml).

final config = ServerConfig.fromEnvironment(serverEnvironment());

String get demoPassword => config.demoPassword!;

/// Pravi praznu bazu [name] i na nju primenjuje iste migracije kao compose (dbmate).
Future<Pool<void>> freshTestDatabase(String name) async {
  final admin = Pool<void>.withUrl(config.databaseUrl);
  await admin.execute('DROP DATABASE IF EXISTS $name WITH (FORCE)');
  await admin.execute('CREATE DATABASE $name');
  await admin.close();
  final url = Uri.parse(config.databaseUrl);
  final insideCompose = url.replace(host: 'db', port: 5432, path: '/$name');
  final result = await Process.run('docker', [
    'compose',
    'run',
    '--rm',
    '-e',
    'DATABASE_URL=$insideCompose',
    'migrate',
  ], workingDirectory: '../..');
  if (result.exitCode != 0) throw StateError('dbmate nije uspeo: ${result.stderr}');
  return Pool<void>.withUrl(url.replace(path: '/$name').toString());
}

/// Server nad test bazom na slobodnom portu, sa istim putanjama kao pravi.
final class TestServer {
  TestServer._(this.database, this._server, this.base, this.sessions, this.notifications);

  static Future<TestServer> start(
    Pool<void> database, {
    Duration ttl = const Duration(hours: 1),
    List<String> corsOrigins = const ['http://localhost:8081'],
  }) async {
    final sessions = SessionHandlers(accounts: AccountStore(database), secret: config.jwtSecret, ttl: ttl);
    final notifications = FakeNotifications(apiKey: 'test', log: _silent);
    final handlers = RequestHandlers(database: database, notifications: notifications);
    final server = RelicServer(() => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0));
    await server.mountAndStart(buildHandler(database, sessions, handlers, corsOrigins: corsOrigins));
    return TestServer._(database, server, Uri.parse('http://localhost:${server.port}'), sessions, notifications);
  }

  final Pool<void> database;
  final RelicServer _server;
  final Uri base;
  final SessionHandlers sessions;

  /// Lažni spoljni servis; test proverava da je server poslao obaveštenje.
  final FakeNotifications notifications;

  Uri uri(String path, [Map<String, String>? query]) => base.replace(path: path, queryParameters: query);

  Future<http.Response> logIn(String login, {String app = AppDto.mobile, String? password, bool cookie = false}) =>
      http.post(
        uri(ApiPaths.sessions),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          LoginDto(username: login, password: password ?? demoPassword, app: app, cookie: cookie).toJson(),
        ),
      );

  /// Token prijave za [login]; mobilna aplikacija ako nije rečeno drugačije.
  Future<String> tokenOf(String login, {String app = AppDto.mobile}) async {
    final answer = await logIn(login, app: app);
    if (answer.statusCode != 201) throw StateError('Prijava $login: ${answer.statusCode} ${answer.body}');
    return SessionDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>).token!;
  }

  /// Gasi server; bazu zatvara onaj ko ju je otvorio.
  Future<void> close() => _server.close();
}

Map<String, String> bearer(String token) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

String codeOf(http.Response response) => (jsonDecode(response.body) as Map<String, Object?>)['code']! as String;

Map<String, Object?> bodyOf(http.Response response) => jsonDecode(response.body) as Map<String, Object?>;

/// Tihi log za lažna obaveštenja u testovima.
final IOSink _silent = IOSink(StreamController<List<int>>()..stream.listen((_) {}));
