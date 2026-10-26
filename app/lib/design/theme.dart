import 'package:flutter/material.dart';

import 'tokens.dart';

/// Thème clair Akonta.
/// [touch] : contrôles de 44 px pour les écrans étroits (mobile).
ThemeData buildAkontaTheme({bool touch = false}) => _buildTheme(AkTokens.light, Brightness.light, touch);

/// Thème sombre Akonta.
ThemeData buildAkontaDarkTheme({bool touch = false}) => _buildTheme(AkTokens.dark, Brightness.dark, touch);

ThemeData _buildTheme(AkTokens t, Brightness brightness, bool touch) {
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

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: AkRadius.mdAll,
    borderSide: BorderSide(color: color, width: width),
  );

  const shape = RoundedRectangleBorder(borderRadius: AkRadius.mdAll);
  const buttonPadding = EdgeInsets.symmetric(horizontal: AkSpace.s3);
  final buttonSize = Size(0, touch ? AkSpace.controlTouch : AkSpace.control);

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
    visualDensity: touch ? VisualDensity.standard : VisualDensity.compact,
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
      contentPadding: EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: touch ? AkSpace.s3 : 9),
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
      style:
          FilledButton.styleFrom(
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
      style: TextButton.styleFrom(foregroundColor: t.brandText, minimumSize: buttonSize, padding: buttonPadding, shape: shape, textStyle: AkText.bodyStrong),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: t.textMuted, shape: shape),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AkRadius.lgAll,
        side: BorderSide(color: t.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: t.shadowOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: AkRadius.lgAll,
        side: BorderSide(color: t.border),
      ),
      titleTextStyle: AkText.title.copyWith(color: t.text),
      contentTextStyle: AkText.body.copyWith(color: t.text),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: t.shadowOverlay,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AkRadius.mdAll,
        side: BorderSide(color: t.border),
      ),
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
    listTileTheme: ListTileThemeData(iconColor: t.textMuted, textColor: t.text, selectedColor: t.brandText, selectedTileColor: t.brandTint),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: t.borderControl, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: AkRadius.smAll),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brand : Colors.transparent),
      checkColor: WidgetStatePropertyAll(t.onBrand),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AkRadius.mdAll)),
        side: WidgetStatePropertyAll(BorderSide(color: t.borderControl)),
        textStyle: const WidgetStatePropertyAll(AkText.table),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brandTint : t.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brandText : t.text),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.brand, linearTrackColor: t.border),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: t.text, borderRadius: AkRadius.mdAll),
      textStyle: AkText.caption.copyWith(color: t.bg),
    ),
  );
}
