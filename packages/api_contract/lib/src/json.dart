// Čitanje JSON-a sa proverom tipa. Pogrešan oblik daje FormatException, a server ga vraća kao 400 bad-request.

Map<String, Object?> jsonObject(Object? value) => switch (value) {
  final Map<String, Object?> object => object,
  _ => throw FormatException('Očekivan JSON objekat', value),
};

List<Map<String, Object?>> jsonObjects(Map<String, Object?> json, String key) => switch (json[key]) {
  final List<Object?> list => [for (final item in list) jsonObject(item)],
  _ => throw FormatException('Očekivana lista „$key“', json),
};

List<String> jsonStrings(Map<String, Object?> json, String key) => switch (json[key]) {
  final List<Object?> list => [
    for (final item in list)
      if (item is String) item else throw FormatException('Očekivana lista tekstova „$key“', json),
  ],
  _ => throw FormatException('Očekivana lista „$key“', json),
};

String jsonString(Map<String, Object?> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('Očekivan tekst „$key“', json),
};

String? jsonOptionalString(Map<String, Object?> json, String key) => switch (json[key]) {
  null => null,
  final String value => value,
  _ => throw FormatException('Očekivan tekst „$key“', json),
};

int jsonInt(Map<String, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  _ => throw FormatException('Očekivan ceo broj „$key“', json),
};

int? jsonOptionalInt(Map<String, Object?> json, String key) => switch (json[key]) {
  null => null,
  final int value => value,
  _ => throw FormatException('Očekivan ceo broj „$key“', json),
};

bool jsonBool(Map<String, Object?> json, String key) => switch (json[key]) {
  final bool value => value,
  _ => throw FormatException('Očekivano da/ne „$key“', json),
};

/// Trenutak u vremenu, uvek sa zonom (ISO 8601 u UTC, npr. `2026-11-03T12:48:01Z`).
DateTime jsonInstant(Map<String, Object?> json, String key) {
  final value = jsonString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Očekivano vreme sa zonom „$key“, npr. 2026-11-03T12:48:01Z', value);
  }
  return parsed;
}

String instantToJson(DateTime instant) => instant.toUtc().toIso8601String();
