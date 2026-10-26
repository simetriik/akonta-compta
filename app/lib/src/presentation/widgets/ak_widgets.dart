import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Carte du système de design : surface blanche, filet, rayon 6, sans ombre.
class AkCard extends StatelessWidget {
  const AkCard({super.key, required this.child, this.padding = const EdgeInsets.all(AkSpace.s4), this.selected = false, this.clip = false});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Carte courante : contour terracotta de 2 px.
  final bool selected;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AkRadius.lgAll,
        border: Border.all(color: selected ? t.brand : t.border, width: selected ? 2 : 1),
      ),
      child: child,
    );
  }
}

/// En-tête d'écran : titre Poppins (un seul par écran), sous-titre et actions à droite.
class AkPageHead extends StatelessWidget {
  const AkPageHead({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s2,
      children: [
        Text(title, style: AkText.titleLg.copyWith(color: t.text)),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(subtitle!, style: AkText.table.copyWith(color: t.textMuted))),
        if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, spacing: AkSpace.s2, children: actions),
      ],
    );
  }
}

enum AkBannerKind { info, success, warning, danger }

/// Bandeau d'information, de succès, d'alerte ou d'erreur (icône + texte + action facultative).
class AkBanner extends StatelessWidget {
  const AkBanner({super.key, required this.kind, required this.child, this.action, this.icon});

  final AkBannerKind kind;
  final Widget child;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (bg, fg, defaultIcon) = switch (kind) {
      AkBannerKind.info => (t.infoTint, t.info, Icons.info_outline),
      AkBannerKind.success => (t.successTint, t.success, Icons.check_circle_outline),
      AkBannerKind.warning => (t.warningTint, t.warning, Icons.warning_amber_outlined),
      AkBannerKind.danger => (t.dangerTint, t.danger, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: AkRadius.lgAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 18, color: fg),
          const SizedBox(width: AkSpace.s2),
          Expanded(child: DefaultTextStyle.merge(style: AkText.table.copyWith(color: t.text), child: child)),
          if (action != null) ...[const SizedBox(width: AkSpace.s2), action!],
        ],
      ),
    );
  }
}

/// Badge de statut générique (texte + icône, rayon 2) : toujours un mot en plus de la couleur.
class AkBadge extends StatelessWidget {
  const AkBadge({super.key, required this.label, required this.color, required this.tint, this.icon, this.outlined = false});

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: AkRadius.smAll,
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
          Text(label, style: AkText.label.copyWith(color: color, letterSpacing: 0)),
        ],
      ),
    );
  }
}

/// Raccourci clavier (ex. « Ctrl K »).
class AkKbd extends StatelessWidget {
  const AkKbd(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: AkRadius.smAll,
        border: Border(
          top: BorderSide(color: t.border),
          left: BorderSide(color: t.border),
          right: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border, width: 2),
        ),
      ),
      child: Text(text, style: AkText.code.copyWith(fontSize: 11, height: 16 / 11, color: t.textMuted)),
    );
  }
}

/// Montant : chiffres tabulaires, aligné à droite.
class AkAmountText extends StatelessWidget {
  const AkAmountText(this.text, {super.key, this.color, this.bold = false});

  final String text;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AkText.amount.copyWith(color: color ?? context.ak.text, fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
    );
  }
}

/// Style du bouton secondaire dangereux (contour et texte cramoisi).
ButtonStyle akDangerOutlinedStyle(BuildContext context) {
  final t = context.ak;
  return OutlinedButton.styleFrom(foregroundColor: t.danger, side: BorderSide(color: t.danger));
}

/// Style du bouton principal dangereux (suppression, rejet).
ButtonStyle akDangerFilledStyle(BuildContext context) {
  final t = context.ak;
  return FilledButton.styleFrom(backgroundColor: t.danger, foregroundColor: t.surface);
}

/// Pastille de compte utilisateur (initiales).
class AkAvatar extends StatelessWidget {
  const AkAvatar(this.name, {super.key, this.size = 28});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.surfaceSunken, shape: BoxShape.circle),
      child: Text(_initials, style: AkText.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0)),
    );
  }
}
