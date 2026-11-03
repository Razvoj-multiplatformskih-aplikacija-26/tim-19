import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool get usesCommandKey => defaultTargetPlatform == TargetPlatform.macOS;

String get commandKeyLabel => usesCommandKey ? '⌘' : 'Ctrl';

SingleActivator command(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, meta: usesCommandKey, control: !usesCommandKey, shift: shift);

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.delta);

  final int delta;
}

class OpenDetailIntent extends Intent {
  const OpenDetailIntent();
}

class CloseDetailIntent extends Intent {
  const CloseDetailIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class CancelSelectedIntent extends Intent {
  const CancelSelectedIntent();
}

class CloseSelectedIntent extends Intent {
  const CloseSelectedIntent();
}

class ReopenSelectedIntent extends Intent {
  const ReopenSelectedIntent();
}

class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}

/// Prečice koje rade bilo gde na ekranu.
Map<ShortcutActivator, Intent> globalShortcuts() => {
  command(LogicalKeyboardKey.keyF): const FocusSearchIntent(),
  command(LogicalKeyboardKey.keyK): const CancelSelectedIntent(),
  command(LogicalKeyboardKey.enter): const CloseSelectedIntent(),
  command(LogicalKeyboardKey.enter, shift: true): const ReopenSelectedIntent(),
  const SingleActivator(LogicalKeyboardKey.escape): const CloseDetailIntent(),
  const SingleActivator(LogicalKeyboardKey.f1): const ShowShortcutsIntent(),
};

/// Prečice tabele; rade samo dok je tabela u fokusu, da ne smetaju polju za pretragu.
Map<ShortcutActivator, Intent> tableShortcuts() => {
  const SingleActivator(LogicalKeyboardKey.arrowUp): const MoveSelectionIntent(-1),
  const SingleActivator(LogicalKeyboardKey.arrowDown): const MoveSelectionIntent(1),
  const SingleActivator(LogicalKeyboardKey.enter): const OpenDetailIntent(),
  const CharacterActivator('?'): const ShowShortcutsIntent(),
};

List<(String, String)> shortcutDescriptions() => [
  ('↑  ↓', 'Kretanje kroz zahteve'),
  ('Enter', 'Otvori detalj izabranog zahteva'),
  ('Esc', 'Zatvori detalj'),
  ('$commandKeyLabel F', 'Pretraga'),
  ('$commandKeyLabel K', 'Otkaži izabrani zahtev'),
  ('$commandKeyLabel Enter', 'Zatvori isporučen zahtev kao završen'),
  ('$commandKeyLabel Shift Enter', 'Vrati isporučen zahtev u izradu'),
  ('F1  ili  ?', 'Pregled prečica'),
];
