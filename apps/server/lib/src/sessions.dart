import 'package:api_contract/api_contract.dart';
import 'package:api_mapping/api_mapping.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:relic/relic.dart' hide Result;

import 'account_store.dart';
import 'http.dart';
import 'passwords.dart';

/// Prijava koju je izdao ovaj server: ko je korisnik i do kada važi.
final class Session {
  const Session({required this.user, required this.expiresAt});

  final User user;
  final DateTime expiresAt;
}

/// Prijavljeni korisnik tekućeg zahteva; postavlja ga [SessionHandlers.signedIn].
final currentSession = ContextProperty<Session>('session');

const _signInRequired = ProblemDto(status: 401, code: ErrorCodes.signInRequired, title: 'Sign in required');
const _sessionExpired = ProblemDto(status: 401, code: ErrorCodes.sessionExpired, title: 'Session expired');
const _algorithm = JWTAlgorithm.HS256;

/// Prijava, provera prijave pri svakom pozivu i odjava.
///
/// Server zna ko poziva samo iz potpisanog tokena koji je sam izdao (JWT sa `sub`, `role` i `exp`), nikad iz tela
/// zahteva. Mobilna i desktop šalju token u zaglavlju `Authorization: Bearer`, pregledač u HttpOnly kolačiću.
final class SessionHandlers {
  SessionHandlers({required this.accounts, required String secret, required this.ttl, this.secureCookie = false})
    : _key = SecretKey(secret),
      _noAccountHash = hashPassword('nalog ne postoji');

  final AccountStore accounts;

  /// Koliko važi prijava (`SESSION_TTL_MINUTES`).
  final Duration ttl;
  final bool secureCookie;
  final SecretKey _key;

  /// Za nepostojeći nalog i dalje se računa heš, da vreme odgovora ne otkrije koji nalozi postoje.
  final Future<String> _noAccountHash;

  /// Propušta samo poziv sa važećom prijavom; inače 401 `sign-in-required` ili `session-expired`.
  Handler signedIn(Handler handler) => (Request request) async {
    final token = _tokenOf(request);
    if (token == null) return _unauthorized(_signInRequired);
    final session = _verify(token);
    if (session == null) return _unauthorized(_sessionExpired);
    currentSession[request] = session;
    return handler(request);
  };

  /// Prijava nije obavezna (javni katalog), ali se koristi kada postoji.
  Handler optionallySignedIn(Handler handler) => (Request request) async {
    final session = switch (_tokenOf(request)) {
      final token? => _verify(token),
      null => null,
    };
    if (session != null) currentSession[request] = session;
    return handler(request);
  };

  /// `POST /api/v1/sessions`: proveri lozinku, pa pravo na aplikaciju (`wrong-app`), pa izdaj prijavu.
  Future<Response> logIn(Request request) async {
    final body = LoginDto.fromJson(await readObject(request));
    final app = appFromDto(body.app) ?? (throw FormatException('Nepoznata aplikacija', body.app));
    final account = await accounts.account(body.username);
    final matches = await verifyPassword(body.password, account?.passwordHash ?? await _noAccountHash);
    if (account == null || !matches) return _unauthorized(const InvalidCredentials().toProblem());
    if (signInTo(app, account.user) case Failure(:final error)) return problem(error);
    final user = account.user;
    final token = JWT({
      'name': user.name,
      'role': user.role.name,
    }, subject: user.id.value).sign(_key, algorithm: _algorithm, expiresIn: ttl);
    final expiresAt = _verify(token)!.expiresAt;
    final dto = SessionDto(user: user.toDto(), expiresAt: expiresAt, token: body.cookie ? null : token);
    final response = json(201, dto.toJson());
    if (!body.cookie) return response;
    return response.copyWith(
      headers: response.headers.transform((headers) => headers.setCookie = _cookie(token, maxAge: ttl.inSeconds)),
    );
  }

  /// `GET /api/v1/sessions/current`: ko je prijavljen i do kada (obnova prijave pri pokretanju aplikacije).
  Future<Response> current(Request request) async {
    final session = currentSession.get(request);
    return json(200, SessionDto(user: session.user.toDto(), expiresAt: session.expiresAt).toJson());
  }

  /// `DELETE /api/v1/sessions/current`: odjava. Pregledaču se briše kolačić; ostali brišu token kod sebe.
  Future<Response> logOut(Request request) async =>
      Response.noContent(headers: Headers.build((headers) => headers.setCookie = _cookie('', maxAge: 0)));

  SetCookieHeader _cookie(String value, {required int maxAge}) => SetCookieHeader(
    name: ApiCookies.session,
    value: value,
    path: Uri.parse('/'),
    maxAge: maxAge,
    httpOnly: true,
    secure: secureCookie,
    sameSite: SameSite.lax,
  );

  Response _unauthorized(ProblemDto problem) {
    final response = problemResponse(problem);
    return response.copyWith(
      headers: response.headers.transform((headers) => headers['WWW-Authenticate'] = ['Bearer']),
    );
  }

  /// Važeća prijava ili `null` (istekla, tuđi potpis, drugi algoritam, pogrešan oblik).
  Session? _verify(String token) {
    try {
      if (JWT.decode(token).header?['alg'] != _algorithm.name) return null;
      return switch (JWT.verify(token, _key).payload) {
        {'sub': final String id, 'name': final String name, 'role': final String role, 'exp': final int exp} => Session(
          user: User(id: UserId(id), name: name, role: Role.values.byName(role)),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        ),
        _ => null,
      };
    } on JWTException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  String? _tokenOf(Request request) => switch (request.headers.authorization) {
    BearerAuthorizationHeader(:final token) => token,
    _ => request.headers.cookie?.getCookie(ApiCookies.session)?.value,
  };
}
