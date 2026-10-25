import 'package:flutter/material.dart';

/// Palette de la marque Akonta (kit logo : encre, terracotta, sable) et couleurs de statut.
abstract final class AkColors {
  static const ink = Color(0xFF1A1A18);
  static const terracotta = Color(0xFFB5472A);
  static const sand = Color(0xFFF7F3EC);
  static const sandDark = Color(0xFFE9E2D6);

  // Statuts colorés : brouillard, validée, revue, à corriger (conception §12.3)
  static const draft = Color(0xFFB7791F);
  static const validated = Color(0xFF2F7D4F);
  static const reviewed = Color(0xFF2B5FA3);
  static const toCorrect = Color(0xFFB3261E);
}

/// Thème Material 3 : sobre, lisible, dense sur desktop.
ThemeData buildAkontaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AkColors.terracotta,
    primary: AkColors.terracotta,
    surface: Colors.white,
    onSurface: AkColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AkColors.sand,
    visualDensity: VisualDensity.compact,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AkColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    ),
    cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero),
    dividerTheme: const DividerThemeData(color: AkColors.sandDark, space: 1),
  );
}
