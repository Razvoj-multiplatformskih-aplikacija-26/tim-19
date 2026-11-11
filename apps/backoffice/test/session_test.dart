import 'package:backoffice/app.dart';
import 'package:backoffice/data/fake_sessions.dart';
import 'package:backoffice/data/seed.dart';
import 'package:backoffice/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BackofficeDependencies> start(WidgetTester tester, {bool signedIn = false}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final deps = BackofficeDependencies.fake(
    latency: const Duration(milliseconds: 50),
    signedIn: signedIn ? moderator : null,
  );
  await tester.pumpWidget(BackofficeApp(dependencies: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> signIn(WidgetTester tester, String username) async {
  await tester.enterText(find.byKey(const Key('korisnicko-ime')), username);
  await tester.enterText(find.byKey(const Key('lozinka')), FakeSessions.password);
  await tester.tap(find.byKey(const Key('prijavi-se')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('korisnik mobilne aplikacije ne ulazi u backoffice i aplikacija kaže zašto', (tester) async {
    await start(tester);
    expect(find.text('Prijava za moderatore'), findsOneWidget);
    await signIn(tester, 'klijent1');
    expect(find.textContaining('Backoffice je za moderatore'), findsOneWidget);
    await signIn(tester, 'pruzalac1');
    expect(find.textContaining('Backoffice je za moderatore'), findsOneWidget);
    expect(find.text('Zahtevi za saradnju'), findsNothing);
  });

  testWidgets('moderator se prijavljuje i vidi tabelu, a odjava vraća na prijavu', (tester) async {
    await start(tester);
    await signIn(tester, 'moderator1');
    expect(find.text('Zahtevi za saradnju'), findsOneWidget);
    expect(find.text('r-1'), findsWidgets);
    await tester.tap(find.byKey(const Key('nalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('odjava')));
    await tester.pumpAndSettle();
    expect(find.text('Odjavljeni ste.'), findsOneWidget);
  });

  testWidgets('sačuvana prijava ostaje, a istek vraća na prijavu sa porukom', (tester) async {
    final deps = await start(tester, signedIn: true);
    expect(find.text('Zahtevi za saradnju'), findsOneWidget);
    deps.fakeSessions!.expire();
    await tester.pumpAndSettle();
    expect(find.text('Prijava je istekla. Prijavite se ponovo.'), findsOneWidget);
  });
}
