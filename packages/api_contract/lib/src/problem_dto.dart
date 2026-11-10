import 'json.dart';

/// Greška sa servera kao `application/problem+json` (RFC 9457): HTTP [status], stabilan [code] i podaci pravila
/// (granica, stanje, uloga…). Poruku za korisnika pravi klijent iz koda i podataka, ne iz [title].
final class ProblemDto {
  const ProblemDto({
    required this.status,
    required this.code,
    required this.title,
    this.value,
    this.max,
    this.state,
    this.from,
    this.to,
    this.role,
    this.service,
    this.app,
  });

  static const mediaType = 'application/problem+json';

  static String typeOf(String code) => 'tag:raf.rs,2026:soundconnect/problem/$code';

  /// HTTP status.
  final int status;
  final String code;

  /// Kratak opis za programera (na engleskom); korisnik ga ne vidi.
  final String title;

  /// Izmerena vrednost, npr. dužina napomene.
  final int? value;

  /// Granica pravila, npr. najveća dužina, broj revizija ili kapacitet pružaoca.
  final int? max;

  /// Stanje zahteva na koje se greška odnosi (trenutno stanje).
  final String? state;

  /// Prelaz koji nije dozvoljen: iz [from] u [to].
  final String? from;
  final String? to;

  /// Uloga koja je pokušala prelaz.
  final String? role;

  /// Usluga koju pružalac ne nudi.
  final String? service;

  /// Aplikacija u koju se korisnik prijavljivao.
  final String? app;

  Map<String, Object?> toJson() => {
    'type': typeOf(code),
    'title': title,
    'status': status,
    'code': code,
    'value': ?value,
    'max': ?max,
    'state': ?state,
    'from': ?from,
    'to': ?to,
    'role': ?role,
    'service': ?service,
    'app': ?app,
  };

  factory ProblemDto.fromJson(Map<String, Object?> json) => ProblemDto(
    status: jsonInt(json, 'status'),
    code: jsonString(json, 'code'),
    title: jsonOptionalString(json, 'title') ?? '',
    value: jsonOptionalInt(json, 'value'),
    max: jsonOptionalInt(json, 'max'),
    state: jsonOptionalString(json, 'state'),
    from: jsonOptionalString(json, 'from'),
    to: jsonOptionalString(json, 'to'),
    role: jsonOptionalString(json, 'role'),
    service: jsonOptionalString(json, 'service'),
    app: jsonOptionalString(json, 'app'),
  );

  @override
  String toString() => 'ProblemDto($status $code)';
}
