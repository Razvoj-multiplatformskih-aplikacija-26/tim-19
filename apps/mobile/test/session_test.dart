import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/data/fake_sessions.dart';
import 'package:mobile/data/seed.dart';
import 'package:mobile/dependencies.dart';

const latency = Duration(milliseconds: 50);

Future<AppDependencies> start(WidgetTester tester, {bool signedIn = false, String? location}) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final deps = AppDependencies.fake(latency: latency, signedIn: signedIn ? meUser : null);
  await tester.pumpWidget(SoundConnectApp(dependencies: deps, initialLocation: location));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> signIn(WidgetTester tester, String username, {String password = FakeSessions.password}) async {
  await tester.enterText(find.byKey(const Key('korisnicko-ime')), username);
  await tester.enterText(find.byKey(const Key('lozinka')), password);
  await tester.tap(find.byKey(const Key('prijavi-se')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bez prijave aplikacija traži prijavu, pa klijent stiže u katalog', (tester) async {
    await start(tester, location: '/zahtevi');
    expect(find.text('Prijavi se'), findsOneWidget);
    await signIn(tester, 'klijent1');
    expect(find.text('Moji zahtevi'), findsWidgets);
  });

  testWidgets('prazna polja i pogrešna lozinka daju poruku, bez tehničkog teksta', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('prijavi-se')));
    await tester.pumpAndSettle();
    expect(find.text('Unesite korisničko ime i lozinku.'), findsOneWidget);
    await signIn(tester, 'klijent1', password: 'pogresna');
    expect(find.text('Pogrešno korisničko ime ili lozinka.'), findsOneWidget);
  });

  testWidgets('moderator ne ulazi u mobilnu i aplikacija kaže zašto', (tester) async {
    await start(tester);
    await signIn(tester, 'moderator1');
    expect(find.textContaining('Mobilna aplikacija je za klijente i pružaoce'), findsOneWidget);
    expect(find.text('Prijavi se'), findsOneWidget);
  });

  testWidgets('sačuvana prijava ostaje posle pokretanja, a odjava vraća na prijavu', (tester) async {
    await start(tester, signedIn: true, location: '/podesavanja');
    expect(find.text('Sava Radošević'), findsOneWidget);
    await tester.tap(find.byKey(const Key('odjava')));
    await tester.pumpAndSettle();
    expect(find.text('Odjavljeni ste.'), findsOneWidget);
  });

  testWidgets('istekla prijava vraća na prijavu sa porukom', (tester) async {
    final deps = await start(tester, signedIn: true, location: '/zahtevi');
    deps.fakeSessions!.expire();
    await tester.pumpAndSettle();
    expect(find.text('Prijava je istekla. Prijavite se ponovo.'), findsOneWidget);
    expect(find.text('Prijavi se'), findsOneWidget);
  });

  testWidgets('pružalac vidi zahteve upućene njemu, sa imenom klijenta, i prihvata poslat', (tester) async {
    await start(tester);
    await signIn(tester, 'pruzalac1');
    expect(find.text('Upućeni zahtevi'), findsOneWidget);
    expect(find.text('Sava Radošević'), findsWidgets);
    await tester.tap(find.text('Poslat').first);
    await tester.pumpAndSettle();
    expect(find.text('Odbij'), findsOneWidget);
    expect(find.text('Otkaži zahtev'), findsNothing);
    await tester.tap(find.text('Prihvati'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je prihvaćen.'), findsOneWidget);
    expect(find.text('Prihvaćen'), findsOneWidget);
  });

  testWidgets('pružalac u katalogu nema dugme za slanje zahteva', (tester) async {
    await start(tester);
    await signIn(tester, 'pruzalac1');
    await tester.tap(find.text('Katalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jelena Vokal'));
    await tester.pumpAndSettle();
    expect(find.text('Pošalji zahtev'), findsNothing);
  });

  testWidgets('klijent traži reviziju isporučenog zahteva', (tester) async {
    await start(tester, signedIn: true, location: '/zahtevi');
    await tester.tap(find.text('Isporučen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traži reviziju'));
    await tester.pumpAndSettle();
    expect(find.text('Tražiti reviziju?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Traži reviziju'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je vraćen na doradu.'), findsOneWidget);
    expect(find.text('U izradi'), findsOneWidget);
  });
}
