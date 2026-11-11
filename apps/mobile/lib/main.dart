import 'package:flutter/material.dart';

import 'app.dart';
import 'data/secure_token_store.dart';
import 'dependencies.dart';
import 'server_address.dart';

/// Podrazumevano radi nad serverom. Bez servera: `flutter run --dart-define=LAZNI_PODACI=true`
/// (isti ekrani i Bloc-ovi, druga implementacija portova).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const fake = bool.fromEnvironment('LAZNI_PODACI');
  final dependencies = fake
      ? AppDependencies.fake(signedIn: null)
      : AppDependencies.server(baseUri: serverAddress(), tokens: const SecureTokenStore());
  runApp(SoundConnectApp(dependencies: dependencies));
}
