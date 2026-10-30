import 'package:flutter/material.dart';

/// Familles de polices embarquées (assets locaux, aucun appel réseau).
abstract final class AkFonts {
  static const ui = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
  static const display = 'Poppins';
}

/// Encres fixes de la marque (logo) : identiques dans les deux thèmes.
abstract final class AkColors {
  static const navy = Color(0xFF1E2A5A);
  static const orange = Color(0xFFF28C28);
}

/// Jetons de design Akonta (clair et sombre), repris du système de design « bleu nuit et orange ».
/// Rôles : le bleu nuit structure (rail, titres), l'orange désigne l'action (un seul bouton principal par écran).
@immutable
class AkTokens extends ThemeExtension<AkTokens> {
  const AkTokens({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.surfaceHover,
    required this.tableHead,
    required this.rowActive,
    required this.rowSelected,
    required this.border,
    required this.borderControl,
    required this.textStrong,
    required this.text,
    required this.textMuted,
    required this.textDisabled,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.accentSoft,
    required this.focus,
    required this.railBg,
    required this.railText,
    required this.railActiveBg,
    required this.railActiveText,
    required this.railIndicator,
    required this.draftFg,
    required this.draftBg,
    required this.reviewFg,
    required this.reviewBg,
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
    required this.toastBg,
    required this.toastFg,
    required this.scrim,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  /// Survol d'une ligne ou d'une entrée de liste.
  final Color surfaceHover;
  final Color tableHead;

  /// Ligne active de la grille de saisie.
  final Color rowActive;

  /// Ligne sélectionnée ou survolée d'un tableau.
  final Color rowSelected;
  final Color border;

  /// Bordure d'un contrôle (3:1 minimum) et filets forts de totaux.
  final Color borderControl;
  final Color textStrong;
  final Color text;
  final Color textMuted;
  final Color textDisabled;

  /// Unique couleur d'action : fond du bouton principal, jamais en texte sur fond clair.
  final Color accent;
  final Color accentHover;
  final Color onAccent;
  final Color accentSoft;
  final Color focus;
  final Color railBg;
  final Color railText;
  final Color railActiveBg;
  final Color railActiveText;
  final Color railIndicator;
  final Color draftFg;
  final Color draftBg;
  final Color reviewFg;
  final Color reviewBg;
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
  final Color toastBg;
  final Color toastFg;
  final Color scrim;

  // Statuts d'écriture : brouillard, validée, revue, à corriger.
  Color get statusDraft => draftFg;
  Color get statusDraftTint => draftBg;
  Color get statusValid => success;
  Color get statusValidTint => successTint;
  Color get statusReview => reviewFg;
  Color get statusReviewTint => reviewBg;
  Color get statusFix => danger;
  Color get statusFixTint => dangerTint;

  static const light = AkTokens(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEFF3),
    surfaceHover: Color(0xFFE8ECF7),
    tableHead: Color(0xFFF0F2F6),
    rowActive: Color(0xFFFFF5EA),
    rowSelected: Color(0xFFE8ECF7),
    border: Color(0xFFDCDFE6),
    borderControl: Color(0xFF7D8597),
    textStrong: Color(0xFF1E2A5A),
    text: Color(0xFF262D40),
    textMuted: Color(0xFF5A6274),
    textDisabled: Color(0xFF868D9C),
    accent: Color(0xFFF28C28),
    accentHover: Color(0xFFE07A14),
    onAccent: Color(0xFF1E2A5A),
    accentSoft: Color(0xFFFCE1C4),
    focus: Color(0xFFC9620A),
    railBg: Color(0xFF1E2A5A),
    railText: Color(0xFFC5CCE3),
    railActiveBg: Color(0xFF2C3A72),
    railActiveText: Color(0xFFFFFFFF),
    railIndicator: Color(0xFFF28C28),
    draftFg: Color(0xFF4A5468),
    draftBg: Color(0xFFECEEF2),
    reviewFg: Color(0xFF6A3D9A),
    reviewBg: Color(0xFFF1EAF8),
    success: Color(0xFF1B6B44),
    successTint: Color(0xFFE3F3EA),
    warning: Color(0xFF7A5200),
    warningTint: Color(0xFFFFF3D1),
    danger: Color(0xFFB0251B),
    dangerTint: Color(0xFFFCE8E6),
    info: Color(0xFF1F5C99),
    infoTint: Color(0xFFE4EEF9),
    disabledFill: Color(0xFFEDEFF3),
    shadowOverlay: Color(0x1F141B3D),
    dangerSolid: Color(0xFFB0251B),
    dangerSolidHover: Color(0xFF8F1D15),
    onDanger: Color(0xFFFFFFFF),
    toastBg: Color(0xFF1E2A5A),
    toastFg: Color(0xFFFFFFFF),
    scrim: Color(0x7A0D1222),
  );

  static const dark = AkTokens(
    bg: Color(0xFF0D1222),
    surface: Color(0xFF151B31),
    surfaceRaised: Color(0xFF1C2340),
    surfaceSunken: Color(0xFF0A0E1B),
    surfaceHover: Color(0xFF1F2850),
    tableHead: Color(0xFF1A2039),
    rowActive: Color(0xFF2A2116),
    rowSelected: Color(0xFF1F2850),
    border: Color(0xFF2A3352),
    borderControl: Color(0xFF6E7898),
    textStrong: Color(0xFFF2F4FA),
    text: Color(0xFFDCE1EC),
    textMuted: Color(0xFF9CA4B8),
    textDisabled: Color(0xFF737C93),
    accent: Color(0xFFF5A04A),
    accentHover: Color(0xFFF7B26A),
    onAccent: Color(0xFF1A1206),
    accentSoft: Color(0xFF5A3A16),
    focus: Color(0xFFF5A04A),
    railBg: Color(0xFF10162E),
    railText: Color(0xFFC5CCE3),
    railActiveBg: Color(0xFF222B4D),
    railActiveText: Color(0xFFFFFFFF),
    railIndicator: Color(0xFFF5A04A),
    draftFg: Color(0xFFB3BACB),
    draftBg: Color(0xFF232A41),
    reviewFg: Color(0xFFC7A6EE),
    reviewBg: Color(0xFF2C2142),
    success: Color(0xFF6FD3A0),
    successTint: Color(0xFF123226),
    warning: Color(0xFFF2C35A),
    warningTint: Color(0xFF33280E),
    danger: Color(0xFFFF9A90),
    dangerTint: Color(0xFF3A1716),
    info: Color(0xFF8DBDF2),
    infoTint: Color(0xFF132A45),
    disabledFill: Color(0xFF0A0E1B),
    shadowOverlay: Color(0x80000000),
    dangerSolid: Color(0xFFFF9A90),
    dangerSolidHover: Color(0xFFFFB1A9),
    onDanger: Color(0xFF2A0C0A),
    toastBg: Color(0xFFE8ECF7),
    toastFg: Color(0xFF151B31),
    scrim: Color(0xA3050810),
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

/// Rayons : badges 4, champs, boutons et cartes 8, dialogues et toasts 12 (`radius-full` pour les interrupteurs).
abstract final class AkRadius {
  static const sm = Radius.circular(4);
  static const md = Radius.circular(8);
  static const lg = Radius.circular(12);
  static const smAll = BorderRadius.all(sm);
  static const mdAll = BorderRadius.all(md);
  static const lgAll = BorderRadius.all(lg);
}

/// Points de rupture : mobile < [medium], tablette [medium]–[expanded], bureau ≥ [expanded], large ≥ [wide].
abstract final class AkBreakpoint {
  static const medium = 600.0;
  static const expanded = 900.0;
  static const wide = 1440.0;
}

/// Espacements (base 4 px) et dimensions du système.
abstract final class AkSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;

  /// Hauteur commune de tous les champs et boutons (ordinateur).
  static const control = 40.0;

  /// Contrôles tactiles (écrans < 900 px).
  static const controlTouch = 48.0;

  /// Contrôles dans une grille ou un tableau dense (souris uniquement).
  static const controlDense = 32.0;
  static const rowCompact = 32.0;
  static const rowComfort = 40.0;
  static const rowTouch = 48.0;
  static const railWidth = 232.0;
  static const railCollapsed = 72.0;
  static const topbarHeight = 56.0;

  /// Largeur de lecture du contenu sur grand écran ; [pageWideMaxWidth] pour les écrans tabulaires très larges.
  static const pageMaxWidth = 1440.0;
  static const pageWideMaxWidth = 1920.0;
  static const formMaxWidth = 960.0;

  /// Largeurs de dialogue : trois tailles, rien d'autre.
  static const dialogS = 400.0;
  static const dialogM = 560.0;
  static const dialogL = 800.0;

  /// Tailles d'icône.
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;

  /// Colonnes types des tableaux.
  static const colIndex = 40.0;
  static const colDate = 112.0;
  static const colJournal = 64.0;
  static const colPiece = 112.0;
  static const colAccount = 320.0;
  static const colThirdParty = 160.0;
  static const colLabel = 240.0;
  static const colAmount = 152.0;
  static const colBalance = 176.0;
  static const colStatus = 136.0;
  static const colAction = 48.0;
}

/// Ombres : [overlay] pour ce qui flotte (menus, autocomplétion, toasts), [dialog] pour les dialogues.
abstract final class AkShadow {
  static List<BoxShadow> overlay(Color color) => [BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 8))];
  static List<BoxShadow> dialog(Color color) => [BoxShadow(color: color, blurRadius: 48, offset: const Offset(0, 24))];
}

/// Échelle typographique par rôles. Taille minimale : 14 px partout.
/// IBM Plex Sans pour l'interface, IBM Plex Mono (chiffres tabulaires) pour les montants et les codes,
/// Poppins pour le seul titre d'écran.
abstract final class AkText {
  static const _tnum = [FontFeature.tabularFigures()];

  static const titleLg = TextStyle(fontFamily: AkFonts.display, fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600, letterSpacing: -0.24);
  static const title = TextStyle(fontFamily: AkFonts.ui, fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w600);
  static const heading = TextStyle(fontFamily: AkFonts.ui, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: AkFonts.ui, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily: AkFonts.ui, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const table = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const tableHead = TextStyle(fontFamily: AkFonts.ui, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const amount = TextStyle(fontFamily: AkFonts.mono, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  static const amountTotal = TextStyle(fontFamily: AkFonts.mono, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, fontFeatures: _tnum);
  static const keyFigure = TextStyle(fontFamily: AkFonts.mono, fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600, fontFeatures: _tnum);
  static const code = TextStyle(fontFamily: AkFonts.mono, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  static const wordmark = TextStyle(fontFamily: AkFonts.display, fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600, letterSpacing: 0.28);
}
