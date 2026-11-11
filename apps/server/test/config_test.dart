import 'package:server/server.dart';
import 'package:test/test.dart';

void main() {
  const env = {
    'DATABASE_URL': 'postgres://u:p@localhost:5435/db',
    'JWT_SECRET': 'dev-only-secret-change-me-0123456789abcdef',
  };

  test('podrazumevane vrednosti', () {
    final config = ServerConfig.fromEnvironment(env);
    expect(config.port, 8080);
    expect(config.sessionTtl, const Duration(hours: 8));
    expect(config.corsOrigins, ['http://localhost:8081']);
    expect(config.secureCookie, isFalse);
  });

  test('istek prijave i dozvoljene adrese iz okruženja', () {
    final config = ServerConfig.fromEnvironment({
      ...env,
      'SESSION_TTL_MINUTES': '1',
      'CORS_ORIGINS': 'http://localhost:8081, http://localhost:8083',
    });
    expect(config.sessionTtl, const Duration(minutes: 1));
    expect(config.corsOrigins, ['http://localhost:8081', 'http://localhost:8083']);
  });

  test('bez baze ili sa kratkom tajnom server ne kreće', () {
    expect(() => ServerConfig.fromEnvironment({'JWT_SECRET': env['JWT_SECRET']!}), throwsStateError);
    expect(() => ServerConfig.fromEnvironment({...env, 'JWT_SECRET': 'kratko'}), throwsStateError);
  });
}
