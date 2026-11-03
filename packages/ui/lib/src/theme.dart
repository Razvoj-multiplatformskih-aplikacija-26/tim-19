import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

abstract final class SoundTheme {
  static const seed = Color(0xFF6C3BD1);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'Inter',
      package: 'ui',
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: rounded),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), shape: rounded),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// Boja oznake stanja: aktivna stanja u bojama teme, odbijen i otkazan u boji greške.
  static Color statusColor(ColorScheme scheme, RequestStatus status) => switch (status) {
    RequestStatus.sent => scheme.tertiary,
    RequestStatus.accepted => scheme.primary,
    RequestStatus.inProgress => scheme.secondary,
    RequestStatus.delivered => scheme.brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
    RequestStatus.completed => scheme.outline,
    RequestStatus.rejected || RequestStatus.cancelled => scheme.error,
  };
}
