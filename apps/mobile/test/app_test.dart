import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/dependencies.dart';
import 'package:ui/ui.dart';

const latency = Duration(milliseconds: 100);

Future<AppDependencies> start(WidgetTester tester, String location, {void Function(AppDependencies)? before}) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final deps = AppDependencies.fake(latency: latency);
  before?.call(deps);
  await tester.pumpWidget(SoundConnectApp(dependencies: deps, initialLocation: location));
  return deps;
}

void main() {
  group('Moji zahtevi', () {
    testWidgets('učitavanje, pa podaci', (tester) async {
      await start(tester, '/zahtevi');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(StatusChip), findsWidgets);
      expect(find.text('Poslat'), findsWidgets);
    });

    testWidgets('greška sa dugmetom „Pokušaj ponovo“', (tester) async {
      await start(tester, '/zahtevi', before: (deps) => deps.fake!.failingRequests = 1);
      await tester.pumpAndSettle();
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();
      expect(find.byType(StatusChip), findsWidgets);
    });

    testWidgets('prazan prikaz', (tester) async {
      await start(tester, '/zahtevi', before: (deps) => deps.fake!.emptyResponses = 1);
      await tester.pumpAndSettle();
      expect(find.text('Još nema zahteva'), findsOneWidget);
    });
  });

  testWidgets('otkazivanje traži potvrdu u dijalogu', (tester) async {
    await start(tester, '/zahtevi/r-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otkaži zahtev'));
    await tester.pumpAndSettle();
    expect(find.text('Otkazati zahtev?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Otkaži zahtev'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je otkazan.'), findsOneWidget);
    expect(find.text('Otkazan'), findsOneWidget);
    expect(find.text('Otkaži zahtev'), findsNothing);
  });

  testWidgets('prihvaćen zahtev nema dugme za otkazivanje i objašnjava pravilo', (tester) async {
    await start(tester, '/zahtevi/r-3');
    await tester.pumpAndSettle();
    expect(find.text('Otkaži zahtev'), findsNothing);
    expect(find.text('Zahtev može da se otkaže samo dok ga pružalac nije prihvatio.'), findsOneWidget);
  });

  group('Forma za novi zahtev', () {
    testWidgets('pravilo dužine napomene, poruka na srpskom', (tester) async {
      await start(tester, '/katalog/p-nikola/novi-zahtev');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note')), 'a' * (maxNoteLength + 1));
      await tester.pump();
      expect(
        find.text('Napomena je predugačka: ${maxNoteLength + 1} od najviše $maxNoteLength znakova.'),
        findsOneWidget,
      );
    });

    testWidgets('prazna napomena se prijavljuje pri slanju', (tester) async {
      await start(tester, '/katalog/p-nikola/novi-zahtev');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pošalji zahtev'));
      await tester.pump();
      expect(find.text('Opišite šta vam treba.'), findsOneWidget);
    });

    testWidgets('šalje zahtev i otvara njegov detalj', (tester) async {
      await start(tester, '/katalog/p-nikola/novi-zahtev');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note')), 'Bit za singl, 90 BPM');
      await tester.tap(find.text('Pošalji zahtev'));
      await tester.pumpAndSettle();
      expect(find.text('Bit za singl, 90 BPM'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Poslat'), findsOneWidget);
    });
  });

  testWidgets('pružalac bez slobodnih mesta ne prima zahtev', (tester) async {
    await start(tester, '/katalog/p-marko');
    await tester.pumpAndSettle();
    expect(find.text('Nema slobodnih mesta'), findsWidgets);
  });

  testWidgets('katalog ne prikazuje neverifikovane pružaoce', (tester) async {
    await start(tester, '/katalog');
    await tester.pumpAndSettle();
    expect(find.text('Novi Producent'), findsNothing);
    expect(find.text('Nikola Beats'), findsOneWidget);
  });
}
