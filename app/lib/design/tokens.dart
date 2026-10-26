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
    required this.dangerSolid,
    required this.dangerSolidHover,
    required this.onDanger,
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
  final Color dangerSolid;
  final Color dangerSolidHover;
  final Color onDanger;

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
    dangerSolid: Color(0xFFA4133C),
    dangerSolidHover: Color(0xFF86102F),
    onDanger: Color(0xFFFFFFFF),
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
    dangerSolid: Color(0xFFC21E4B),
    dangerSolidHover: Color(0xFFD63A63),
    onDanger: Color(0xFFFFFFFF),
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
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s12 = 48.0;

  /// Hauteur commune de tous les champs et boutons (ordinateur).
  static const control = 40.0;

  /// Contrôles tactiles (écrans < 600 px).
  static const controlTouch = 48.0;

  /// Contrôles dans une grille ou un tableau dense.
  static const controlDense = 32.0;
  static const rowCompact = 32.0;
  static const rowTouch = 48.0;
  static const railWidth = 232.0;
  static const topbarHeight = 56.0;

  /// Largeur de lecture confortable du contenu sur grand écran.
  static const pageMaxWidth = 1400.0;
  static const formMaxWidth = 640.0;
}

/// Ombres : une seule, discrète, pour les surfaces flottantes (menus, dialogues).
abstract final class AkShadow {
  static List<BoxShadow> overlay(Color color) => [BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 4))];
}

/// Échelle typographique. Taille minimale : 14 px partout.
/// IBM Plex Sans pour l'interface, IBM Plex Mono (chiffres tabulaires) pour les montants et les codes,
/// Poppins pour le seul grand titre de chaque écran.
abstract final class AkText {
  static const _tnum = [FontFeature.tabularFigures()];

  static const titleLg = TextStyle(fontFamily: AkFonts.display, fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600);
  static const title = TextStyle(fontFamily: AkFonts.ui, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const heading = TextStyle(fontFamily: AkFonts.ui, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const table = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const amount = TextStyle(fontFamily: AkFonts.mono, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, fontFeatures: _tnum);
  static const code = TextStyle(fontFamily: AkFonts.mono, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  static const wordmark = TextStyle(fontFamily: AkFonts.display, fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600, letterSpacing: 0.28);
}
