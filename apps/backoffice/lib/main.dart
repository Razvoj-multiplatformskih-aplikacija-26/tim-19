import 'package:flutter/material.dart';

import 'app.dart';
import 'dependencies.dart';

/// Podrazumevano radi nad serverom, na Windows-u i u pregledaču (`flutter run -d chrome --web-port 8081`, adresa iz
/// CORS_ORIGINS). Bez servera: `--dart-define=LAZNI_PODACI=true`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const fake = bool.fromEnvironment('LAZNI_PODACI');
  final dependencies = fake
      ? BackofficeDependencies.fake(signedIn: null)
      : BackofficeDependencies.server(baseUri: serverAddress());
  runApp(BackofficeApp(dependencies: dependencies));
}
