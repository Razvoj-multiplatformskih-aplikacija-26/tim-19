import 'package:flutter/foundation.dart';

/// Adresa servera bez izmene koda: Android emulator vidi računar kao `10.0.2.2`, ostali kao `localhost`.
/// Za telefon u mreži: `flutter run --dart-define=SERVER_URL=http://192.168.1.10:8080`.
Uri serverAddress() {
  const configured = String.fromEnvironment('SERVER_URL');
  if (configured.isNotEmpty) return Uri.parse(configured);
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  return Uri.parse('http://$host:8080');
}
