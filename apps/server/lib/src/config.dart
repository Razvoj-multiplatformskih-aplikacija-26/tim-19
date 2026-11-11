import 'dart:convert';

/// Podešavanja servera iz okruženja (`.env` u korenu repozitorijuma ili promenljive iz `compose.yaml`).
final class ServerConfig {
  const ServerConfig({
    required this.host,
    required this.port,
    required this.databaseUrl,
    required this.corsOrigins,
    required this.jwtSecret,
    this.sessionTtl = const Duration(hours: 8),
    this.secureCookie = false,
    this.demoPassword,
    this.notifyApiKey,
  });

  factory ServerConfig.fromEnvironment(Map<String, String> environment) => ServerConfig(
    host: environment['HOST'] ?? '127.0.0.1',
    port: int.parse(environment['PORT'] ?? '8080'),
    databaseUrl: environment['DATABASE_URL'] ?? (throw StateError('DATABASE_URL nije postavljen. $_copyEnv')),
    corsOrigins: [
      for (final origin in (environment['CORS_ORIGINS'] ?? 'http://localhost:8081').split(','))
        if (origin.trim().isNotEmpty) origin.trim(),
    ],
    jwtSecret: _jwtSecret(environment['JWT_SECRET']),
    sessionTtl: Duration(minutes: int.parse(environment['SESSION_TTL_MINUTES'] ?? '480')),
    secureCookie: environment['COOKIE_SECURE'] == 'true',
    demoPassword: environment['DEMO_PASSWORD'],
    notifyApiKey: environment['NOTIFY_API_KEY'],
  );

  final String host;
  final int port;
  final String databaseUrl;

  /// Adrese sa kojih pregledač sme da zove server (backoffice u pregledaču).
  final List<String> corsOrigins;

  /// Tajna za potpis prijave (JWT); samo na serveru.
  final String jwtSecret;

  /// Koliko važi prijava; posle toga klijent dobija `session-expired`.
  final Duration sessionTtl;
  final bool secureCookie;

  /// Lozinka demo naloga pri prvom punjenju baze; u bazi ostaje samo heš.
  final String? demoPassword;

  /// Ključ spoljnog servisa za obaveštenja; samo na serveru, nikad u aplikaciji.
  final String? notifyApiKey;
}

const _copyEnv = 'Kopirajte .env.example u .env u korenu repozitorijuma.';

String _jwtSecret(String? secret) => switch (secret) {
  null => throw StateError('JWT_SECRET nije postavljen. $_copyEnv'),
  final secret when utf8.encode(secret).length < 32 => throw StateError('JWT_SECRET mora imati bar 32 bajta.'),
  final secret => secret,
};
