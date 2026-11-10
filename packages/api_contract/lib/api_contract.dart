/// Ugovor između klijenata i servera: putanje, DTO-i, kodovi grešaka i greška kao `application/problem+json`.
///
/// Paket ne uvozi domen, Flutter ni `dart:io`, pa ga koriste i klijenti (VM i pregledač) i server.
library;

export 'src/catalog_dto.dart';
export 'src/error_codes.dart';
export 'src/json.dart' show instantToJson;
export 'src/page_dto.dart';
export 'src/paths.dart';
export 'src/problem_dto.dart';
export 'src/request_dto.dart';
export 'src/session_dto.dart';
