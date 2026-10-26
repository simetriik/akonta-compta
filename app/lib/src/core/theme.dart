import 'package:flutter/material.dart';

/// Familles de polices embarquées (assets locaux, aucun appel réseau).
abstract final class AkFonts {
  static const ui = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
  static const display = 'Poppins';
}

/// Constantes de marque (kit logo) et couleurs de statut historiques.
/// Les écrans migrent vers [AkTokens] (`context.ak`) qui gère le thème sombre.
abstract final class AkColors {
  static const ink = Color(0xFF1A1A18);
  static const terracotta = Color(0xFFB5472A);
  static const sand = Color(0xFFF7F3EC);
  static const sandDark = Color(0xFFEFE8DC);

  static const draft = Color(0xFF8A5A00);
  static const validated = Color(0xFF2E6B3F);
  static const reviewed = Color(0xFF2B5B84);
  static const toCorrect = Color(0xFFA4133C);
}

/// Jetons de design Akonta (clair et sombre), calqués sur le système de design.
@immutable
class AkTokens extends ThemeExtension<AkTokens> {
  const AkTokens({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceHover,
    required this.text,
    required this.textMuted,
    required this.textDisabled,
    required this.border,
    required this.borderControl,
    required this.borderStrong,
    required this.brand,
    required this.brandHover,
    required this.onBrand,
    required this.brandText,
    required this.brandTint,
    required this.focus,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.info,
    required this.infoTint,
    required this.disabledFill,
    required this.shadowOverlay,
  });

  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color surfaceHover;
  final Color text;
  final Color textMuted;
  final Color textDisabled;
  final Color border;
  final Color borderControl;
  final Color borderStrong;
  final Color brand;
  final Color brandHover;
  final Color onBrand;
  final Color brandText;
  final Color brandTint;
  final Color focus;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;
  final Color info;
  final Color infoTint;
  final Color disabledFill;
  final Color shadowOverlay;

  // Statuts d'écriture : brouillard, validée, revue, à corriger.
  Color get statusDraft => warning;
  Color get statusDraftTint => warningTint;
  Color get statusValid => success;
  Color get statusValidTint => successTint;
  Color get statusReview => info;
  Color get statusReviewTint => infoTint;
  Color get statusFix => danger;
  Color get statusFixTint => dangerTint;

  static const light = AkTokens(
    bg: Color(0xFFF7F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEFE8DC),
    surfaceHover: Color(0xFFF7F3EC),
    text: Color(0xFF1A1A18),
    textMuted: Color(0xFF6B645A),
    textDisabled: Color(0xFF9C9385),
    border: Color(0xFFE2D9CA),
    borderControl: Color(0xFF8E8576),
    borderStrong: Color(0xFF1A1A18),
    brand: Color(0xFFB5472A),
    brandHover: Color(0xFF963A22),
    onBrand: Color(0xFFFFFFFF),
    brandText: Color(0xFFB5472A),
    brandTint: Color(0xFFFBEEE9),
    focus: Color(0xFFB5472A),
    success: Color(0xFF2E6B3F),
    successTint: Color(0xFFE6F0E8),
    warning: Color(0xFF8A5A00),
    warningTint: Color(0xFFFBF0D9),
    danger: Color(0xFFA4133C),
    dangerTint: Color(0xFFFBE9EE),
    info: Color(0xFF2B5B84),
    infoTint: Color(0xFFE7EEF5),
    disabledFill: Color(0xFFEFE8DC),
    shadowOverlay: Color(0x291A1A18),
  );

  static const dark = AkTokens(
    bg: Color(0xFF121211),
    surface: Color(0xFF1C1C1A),
    surfaceSunken: Color(0xFF262521),
    surfaceHover: Color(0xFF24231F),
    text: Color(0xFFF2EDE4),
    textMuted: Color(0xFFB3AA9B),
    textDisabled: Color(0xFF6E675C),
    border: Color(0xFF33312C),
    borderControl: Color(0xFF857D70),
    borderStrong: Color(0xFFF2EDE4),
    brand: Color(0xFFB5472A),
    brandHover: Color(0xFFC9573A),
    onBrand: Color(0xFFFFFFFF),
    brandText: Color(0xFFE8876A),
    brandTint: Color(0xFF3A241C),
    focus: Color(0xFFE8876A),
    success: Color(0xFF7BC48E),
    successTint: Color(0xFF1F3326),
    warning: Color(0xFFE5B860),
    warningTint: Color(0xFF3A2E14),
    danger: Color(0xFFF08A9F),
    dangerTint: Color(0xFF3D1A24),
    info: Color(0xFF8DB8E0),
    infoTint: Color(0xFF1C2B38),
    disabledFill: Color(0xFF2A2925),
    shadowOverlay: Color(0x80000000),
  );

  @override
  AkTokens copyWith() => this;

  @override
  AkTokens lerp(ThemeExtension<AkTokens>? other, double t) => t < 0.5 ? this : (other as AkTokens? ?? this);
}

extension AkThemeContext on BuildContext {
  /// Jetons de design du thème courant (clair ou sombre).
  AkTokens get ak => Theme.of(this).extension<AkTokens>() ?? AkTokens.light;
}

/// Rayons : badges 2, champs et boutons 4, cartes et dialogues 6 (pas de pilules).
abstract final class AkRadius {
  static const sm = Radius.circular(2);
  static const md = Radius.circular(4);
  static const lg = Radius.circular(6);
  static const smAll = BorderRadius.all(sm);
  static const mdAll = BorderRadius.all(md);
  static const lgAll = BorderRadius.all(lg);
}

/// Espacements (base 4 px) et dimensions de la maquette.
abstract final class AkSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const controlCompact = 32.0;
  static const controlTouch = 44.0;
  static const rowCompact = 32.0;
  static const rowTouch = 48.0;
  static const railWidth = 216.0;
  static const topbarHeight = 56.0;
}

/// Styles de texte nommés comme dans le système de design.
abstract final class AkText {
  static const _tnum = [FontFeature.tabularFigures()];

  static const titleLg = TextStyle(fontFamily: AkFonts.display, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600);
  static const title = TextStyle(fontFamily: AkFonts.ui, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const heading = TextStyle(fontFamily: AkFonts.ui, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontFamily: AkFonts.ui, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.12);
  static const caption = TextStyle(fontFamily: AkFonts.ui, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400);
  static const table = TextStyle(fontFamily: AkFonts.ui, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const amount = TextStyle(fontFamily: AkFonts.ui, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, fontFeatures: _tnum);
  static const code = TextStyle(fontFamily: AkFonts.mono, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const wordmark = TextStyle(fontFamily: AkFonts.display, fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600, letterSpacing: 0.28);
}

/// Thème clair Akonta.
ThemeData buildAkontaTheme() => _buildTheme(AkTokens.light, Brightness.light);

/// Thème sombre Akonta.
ThemeData buildAkontaDarkTheme() => _buildTheme(AkTokens.dark, Brightness.dark);

ThemeData _buildTheme(AkTokens t, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.brand,
    onPrimary: t.onBrand,
    primaryContainer: t.brandTint,
    onPrimaryContainer: t.brandText,
    secondary: t.textMuted,
    onSecondary: t.surface,
    error: t.danger,
    onError: t.surface,
    errorContainer: t.dangerTint,
    onErrorContainer: t.danger,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.textMuted,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surfaceSunken,
    surfaceContainerHigh: t.surfaceSunken,
    surfaceContainerHighest: t.surfaceSunken,
    outline: t.borderControl,
    outlineVariant: t.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: t.text,
    onInverseSurface: t.bg,
    inversePrimary: t.brandText,
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
  final textTheme = base
      .apply(fontFamily: AkFonts.ui, bodyColor: t.text, displayColor: t.text)
      .copyWith(
        headlineSmall: AkText.titleLg.copyWith(color: t.text),
        titleLarge: AkText.title.copyWith(color: t.text),
        titleMedium: AkText.heading.copyWith(color: t.text),
        titleSmall: AkText.bodyStrong.copyWith(color: t.text),
        bodyLarge: AkText.body.copyWith(color: t.text),
        bodyMedium: AkText.body.copyWith(color: t.text),
        bodySmall: AkText.caption.copyWith(color: t.textMuted),
        labelLarge: AkText.bodyStrong.copyWith(color: t.text),
        labelMedium: AkText.label.copyWith(color: t.textMuted),
        labelSmall: AkText.caption.copyWith(color: t.textMuted),
      );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: AkRadius.mdAll, borderSide: BorderSide(color: color, width: width));

  const shape = RoundedRectangleBorder(borderRadius: AkRadius.mdAll);
  const buttonPadding = EdgeInsets.symmetric(horizontal: AkSpace.s3);
  const buttonSize = Size(0, AkSpace.controlCompact);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [t],
    fontFamily: AkFonts.ui,
    textTheme: textTheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.surface,
    dividerColor: t.border,
    focusColor: t.focus.withValues(alpha: 0.12),
    hoverColor: t.surfaceHover,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.compact,
    appBarTheme: AppBarTheme(
      backgroundColor: t.surface,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: t.border)),
      titleTextStyle: AkText.title.copyWith(color: t.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: t.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s2),
      border: inputBorder(t.borderControl),
      enabledBorder: inputBorder(t.borderControl),
      focusedBorder: inputBorder(t.focus, 2),
      errorBorder: inputBorder(t.danger),
      focusedErrorBorder: inputBorder(t.danger, 2),
      disabledBorder: inputBorder(t.border),
      labelStyle: AkText.label.copyWith(color: t.textMuted),
      floatingLabelStyle: AkText.label.copyWith(color: t.textMuted),
      hintStyle: AkText.body.copyWith(color: t.textDisabled),
      helperStyle: AkText.caption.copyWith(color: t.textMuted),
      errorStyle: AkText.caption.copyWith(color: t.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.brand,
        foregroundColor: t.onBrand,
        disabledBackgroundColor: t.disabledFill,
        disabledForegroundColor: t.textDisabled,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: AkText.bodyStrong,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return t.disabledFill;
          if (s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed)) return t.brandHover;
          return t.brand;
        }),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.brand,
        foregroundColor: t.onBrand,
        elevation: 0,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: AkText.bodyStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.borderStrong),
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: AkText.bodyStrong,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.brandText,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: AkText.bodyStrong,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: t.textMuted, shape: shape),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AkRadius.lgAll, side: BorderSide(color: t.border)),
    ),
    dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: t.shadowOverlay,
      shape: RoundedRectangleBorder(borderRadius: AkRadius.lgAll, side: BorderSide(color: t.border)),
      titleTextStyle: AkText.title.copyWith(color: t.text),
      contentTextStyle: AkText.body.copyWith(color: t.text),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: t.shadowOverlay,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AkRadius.mdAll, side: BorderSide(color: t.border)),
      textStyle: AkText.body.copyWith(color: t.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.text,
      contentTextStyle: AkText.body.copyWith(color: t.bg),
      shape: const RoundedRectangleBorder(borderRadius: AkRadius.mdAll),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.surfaceSunken,
      selectedColor: t.brandTint,
      side: BorderSide(color: t.border),
      labelStyle: AkText.label.copyWith(color: t.text),
      shape: const RoundedRectangleBorder(borderRadius: AkRadius.smAll),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(t.surfaceSunken),
      headingTextStyle: AkText.label.copyWith(color: t.textMuted),
      dataTextStyle: AkText.table.copyWith(color: t.text),
      dataRowMinHeight: AkSpace.rowCompact,
      dataRowMaxHeight: AkSpace.rowCompact + 8,
      headingRowHeight: AkSpace.rowCompact,
      dividerThickness: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: t.text,
      unselectedLabelColor: t.textMuted,
      indicatorColor: t.brand,
      dividerColor: t.border,
      labelStyle: AkText.bodyStrong,
      unselectedLabelStyle: AkText.body,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.textMuted,
      textColor: t.text,
      selectedColor: t.brandText,
      selectedTileColor: t.brandTint,
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: t.borderControl, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: AkRadius.smAll),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brand : Colors.transparent),
      checkColor: WidgetStatePropertyAll(t.onBrand),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.brand, linearTrackColor: t.border),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: t.text, borderRadius: AkRadius.mdAll),
      textStyle: AkText.caption.copyWith(color: t.bg),
    ),
  );
}
