import 'package:backoffice/app.dart';
import 'package:backoffice/dependencies.dart';
import 'package:backoffice/widgets/detail_panel.dart';
import 'package:backoffice/widgets/request_list.dart';
import 'package:backoffice/widgets/request_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

Future<BackofficeDependencies> start(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  void Function(BackofficeDependencies)? before,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final deps = BackofficeDependencies.fake(latency: const Duration(milliseconds: 50));
  before?.call(deps);
  await tester.pumpWidget(BackofficeApp(dependencies: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

/// Klik na prvi red daje fokus tabeli i otvara detalj.
Future<void> focusTable(WidgetTester tester) async {
  await tester.tap(find.text('r-1').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('široki prozor prikazuje tabelu sa svim zahtevima', (tester) async {
    await start(tester);
    expect(find.byType(RequestTable), findsOneWidget);
    expect(find.text('20 od 20'), findsOneWidget);
  });

  testWidgets('strelice pomeraju izbor, Enter otvara detalj, Esc ga zatvara', (tester) async {
    await start(tester);
    await focusTable(tester);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(DetailPanel), findsNothing);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(DetailPanel), findsOneWidget);
    expect(find.text('Zahtev r-2'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(find.text('Zahtev r-1'), findsOneWidget);
  });

  testWidgets('Ctrl+F fokusira pretragu, a pretraga filtrira po klijentu', (tester) async {
    await start(tester);
    await press(tester, LogicalKeyboardKey.keyF, control: true);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'tara');
    await tester.pumpAndSettle();
    expect(find.text('3 od 20'), findsOneWidget);
  });

  testWidgets('Ctrl+K otkazuje izabrani zahtev posle potvrde', (tester) async {
    await start(tester);
    await focusTable(tester);
    await press(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.text('Otkazati zahtev?'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Zahtev r-1 je otkazan.'), findsOneWidget);
    expect(find.descendant(of: find.byType(DetailPanel), matching: find.text('Otkazan')), findsOneWidget);
  });

  testWidgets('Ctrl+Enter zatvara isporučen zahtev kao završen', (tester) async {
    await start(tester);
    await focusTable(tester);
    await press(tester, LogicalKeyboardKey.arrowDown, control: false);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Zahtev r-4'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Zahtev r-4 je zatvoren kao završen.'), findsOneWidget);
  });

  testWidgets('pravilo iz domena odbija akciju nad završenim zahtevom', (tester) async {
    await start(tester);
    await tester.enterText(find.byType(TextField), 'r-8');
    await tester.pumpAndSettle();
    await tester.tap(find.text('r-8').last);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.text('Otkazati zahtev?'), findsNothing);
    expect(find.text('Zahtev je u stanju „Završen“ i više se ne menja.'), findsWidgets);
  });

  testWidgets('uzak prozor prikazuje listu i zadržava izbor', (tester) async {
    await start(tester);
    await focusTable(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.binding.setSurfaceSize(const Size(600, 900));
    await tester.pumpAndSettle();
    expect(find.byType(RequestList), findsOneWidget);
    expect(find.byType(RequestTable), findsNothing);
    final tile = tester.widgetList<ListTile>(find.byType(ListTile)).firstWhere((t) => t.selected);
    expect((tile.subtitle! as Text).data, startsWith('r-2'));
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Zahtev r-2'), findsOneWidget);
  });

  testWidgets('sortiranje klikom na zaglavlje kolone', (tester) async {
    await start(tester, size: const Size(1400, 1400));
    await tester.tap(find.text('Klijent'));
    await tester.pumpAndSettle();
    double top(String client) => tester.getTopLeft(find.text(client).first).dy;
    // Rastuće po imenu klijenta: Iva, Luka, …, Vuk.
    expect(top('Iva Marković'), lessThan(top('Luka Ilić')));
    expect(top('Luka Ilić'), lessThan(top('Vuk Stojanović')));
    await tester.tap(find.text('Klijent'));
    await tester.pumpAndSettle();
    expect(top('Vuk Stojanović'), lessThan(top('Iva Marković')));
  });

  testWidgets('greška sa dugmetom „Pokušaj ponovo“ i prazan prikaz', (tester) async {
    await start(tester, before: (deps) => deps.fake!.failingRequests = 1);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();
    expect(find.byType(StatusChip), findsWidgets);
  });

  testWidgets('prazan prikaz', (tester) async {
    await start(tester, before: (deps) => deps.fake!.emptyResponses = 1);
    expect(find.text('Nema zahteva'), findsOneWidget);
  });
}
