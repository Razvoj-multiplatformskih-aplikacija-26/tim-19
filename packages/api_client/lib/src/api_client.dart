import 'dart:async';
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:api_mapping/api_mapping.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

import 'platform_client.dart';
import 'token_store.dart';

/// Odgovor servera: prihvaćeno (JSON tela) ili odbijeno greškom iz domena.
sealed class ApiAnswer {
  const ApiAnswer();
}

final class ApiAccepted extends ApiAnswer {
  const ApiAccepted(this.json);

  final Object? json;
}

/// Server je odbio poziv pravilom; greška je ista kao kada pravilo proveri klijent (preko `api_mapping`).
/// Kôd koji ova verzija ne poznaje stiže kao [ServerRejected], ne kao izuzetak.
final class ApiRejected extends ApiAnswer {
  const ApiRejected(this.error);

  final DomainError error;
}

/// Jedini kôd za razgovor sa serverom, zajednički za mobilnu i backoffice, na VM-u i u pregledaču.
///
/// - Prijava: token u zaglavlju `Authorization` (VM) ili HttpOnly kolačić koji šalje pregledač.
/// - Server ne odgovori na vreme ili nije dostupan: [RepositoryException] sa [RepositoryFailure.unreachable],
///   pa ekran ne ostaje u učitavanju bez kraja.
/// - Istekla prijava: [RepositoryFailure.sessionExpired] i događaj na [expirations], da aplikacija vrati
///   korisnika na prijavu iz bilo kog ekrana.
final class ApiClient {
  ApiClient({
    required this.baseUri,
    TokenStore? tokens,
    http.Client? httpClient,
    this.keepsSessionInCookie = platformKeepsSessionInCookie,
    this.timeout = const Duration(seconds: 10),
  }) : tokens = tokens ?? MemoryTokenStore(),
       _http = httpClient ?? platformHttpClient();

  final Uri baseUri;
  final TokenStore tokens;
  final bool keepsSessionInCookie;
  final Duration timeout;
  final http.Client _http;
  final _expirations = StreamController<void>.broadcast();

  Stream<void> get expirations => _expirations.stream;

  Future<ApiAnswer> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);

  Future<ApiAnswer> post(String path, {Map<String, Object?>? body}) => _send('POST', path, body: body);

  Future<ApiAnswer> delete(String path) => _send('DELETE', path);

  Future<ApiAnswer> _send(String method, String path, {Map<String, String>? query, Map<String, Object?>? body}) async {
    final request = http.Request(method, baseUri.replace(path: path, queryParameters: query))
      ..headers['Accept'] = 'application/json';
    if (!keepsSessionInCookie) {
      if (await tokens.read() case final token?) request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await _http.send(request).then(http.Response.fromStream).timeout(timeout);
    } on http.ClientException catch (cause) {
      throw RepositoryException('Server nije dostupan', cause: cause);
    } on TimeoutException catch (cause) {
      throw RepositoryException('Server nije odgovorio na vreme', cause: cause);
    }
    return _answerOf(response);
  }

  ApiAnswer _answerOf(http.Response response) {
    final status = response.statusCode;
    final json = readJson(() => response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes)));
    if (status >= 200 && status < 300) return ApiAccepted(json);
    if (status >= 400 && status < 500 && json is Map<String, Object?>) {
      final problem = readJson(() => ProblemDto.fromJson(json));
      if (problem.code case ErrorCodes.sessionExpired || ErrorCodes.signInRequired) {
        _expirations.add(null);
        throw const RepositoryException('Prijava je istekla', failure: RepositoryFailure.sessionExpired);
      }
      return ApiRejected(problem.toDomainError());
    }
    throw RepositoryException('Server je odgovorio sa $status', failure: RepositoryFailure.serverError);
  }
}

/// Odgovor koji ne može da se pročita je greška servera, ne pad aplikacije.
T readJson<T>(T Function() read) {
  try {
    return read();
  } on FormatException catch (cause) {
    throw RepositoryException('Nečitljiv odgovor', failure: RepositoryFailure.serverError, cause: cause);
  } on TypeError catch (cause) {
    throw RepositoryException('Nečitljiv odgovor', failure: RepositoryFailure.serverError, cause: cause);
  }
}

/// Telo prihvaćenog odgovora; odbijanje tamo gde ga ne očekujemo (npr. pregled) je greška servera.
T accepted<T>(ApiAnswer answer, T Function(Object? json) read) => switch (answer) {
  ApiAccepted(:final json) => readJson(() => read(json)),
  ApiRejected(:final error) => throw RepositoryException(
    'Neočekivano odbijanje: $error',
    failure: RepositoryFailure.serverError,
  ),
};

/// Akcija koja sme da bude odbijena pravilom: odbijanje postaje [Failure] sa istom greškom kao u domenu.
Result<T> resultOf<T>(ApiAnswer answer, T Function(Object? json) read) => switch (answer) {
  ApiAccepted(:final json) => Success(readJson(() => read(json))),
  ApiRejected(:final error) => Failure(error),
};

Map<String, Object?> object(Object? json) => switch (json) {
  final Map<String, Object?> object => object,
  _ => throw FormatException('Očekivan JSON objekat', json),
};

List<Map<String, Object?>> objects(Object? json) => switch (json) {
  final List<Object?> list => [for (final item in list) object(item)],
  _ => throw FormatException('Očekivana JSON lista', json),
};
