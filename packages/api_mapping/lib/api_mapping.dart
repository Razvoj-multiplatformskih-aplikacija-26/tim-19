/// Prevod između domena i ugovora: modeli u oba smera i greške (`DomainError` ↔ `ProblemDto`).
///
/// Jedino mesto prevoda; koriste ga klijenti (preko `api_client`) i server.
library;

export 'src/catalog_mapping.dart';
export 'src/error_mapping.dart';
export 'src/request_mapping.dart';
export 'src/user_mapping.dart';
