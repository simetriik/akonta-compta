import 'package:flutter/material.dart';

import '../tokens.dart';

/// Vrai sur les écrans étroits (mobile, < 600 px) : marge de 16 px, une tâche par écran.
bool akIsCompact(BuildContext context) => MediaQuery.sizeOf(context).width < AkBreakpoint.medium;

/// Vrai sous 900 px (mobile et tablette) : contrôles tactiles de 48 px, lignes de tableau de 48 px.
bool akIsTouch(BuildContext context) => MediaQuery.sizeOf(context).width < AkBreakpoint.expanded;

/// Marge latérale des écrans : 24 px sur ordinateur, 16 px sur mobile.
double akPageMargin(BuildContext context) => akIsCompact(context) ? AkSpace.s4 : AkSpace.s6;

/// Hauteur d'un champ ou d'un bouton : 40 px sur ordinateur, 48 px sous 900 px.
double akControlHeight(BuildContext context) => akIsTouch(context) ? AkSpace.controlTouch : AkSpace.control;

/// Carte : surface blanche, filet, rayon 8, sans ombre.
class AkCard extends StatelessWidget {
  const AkCard({super.key, required this.child, this.padding = const EdgeInsets.all(AkSpace.s4), this.selected = false, this.clip = false, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Carte courante : contour de 2 px à la couleur du focus.
  final bool selected;
  final bool clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final body = Padding(padding: padding, child: child);
    return Material(
      color: t.surface,
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: AkRadius.mdAll,
        side: BorderSide(color: selected ? t.focus : t.border, width: selected ? 2 : 1),
      ),
      child: onTap == null ? body : InkWell(onTap: onTap, hoverColor: t.surfaceHover, child: body),
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
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s2,
      children: [
        Text(title, style: AkText.titleLg.copyWith(color: t.textStrong)),
        if (subtitle != null) Text(subtitle!, style: AkText.table.copyWith(color: t.textMuted)),
        if (actions.isNotEmpty) Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: actions),
      ],
    );
  }
}

/// Titre de section dans un écran ou une carte.
class AkSectionTitle extends StatelessWidget {
  const AkSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: AkText.title.copyWith(color: context.ak.textStrong)),
        ),
        ?trailing,
      ],
    );
  }
}

/// Zone de contenu d'un écran : marges, largeur de lecture bornée et défilement vertical.
class AkPage extends StatelessWidget {
  const AkPage({super.key, required this.children, this.maxWidth = AkSpace.pageMaxWidth, this.scroll = true});

  final List<Widget> children;
  final double maxWidth;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final m = akPageMargin(context);
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    final padded = Padding(padding: EdgeInsets.fromLTRB(m, AkSpace.s4, m, AkSpace.s6), child: content);
    final bounded = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padded,
      ),
    );
    return scroll ? SingleChildScrollView(child: bounded) : bounded;
  }
}

/// Carte indicateur : un chiffre clé, son libellé et une précision facultative.
/// Une carte qui signale un problème colore son libellé ([problem]), jamais le chiffre ni le fond.
class AkStat extends StatelessWidget {
  const AkStat({super.key, required this.label, required this.value, this.caption, this.icon, this.problem = false, this.onTap});

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final bool problem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final labelColor = problem ? t.statusFix : t.textMuted;
    return AkCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: AkSpace.iconSm, color: labelColor), const SizedBox(width: AkSpace.s2)],
              Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AkText.label.copyWith(color: labelColor))),
            ],
          ),
          const SizedBox(height: AkSpace.s1),
          Text(value, style: AkText.keyFigure.copyWith(color: t.textStrong)),
          if (caption != null) Text(caption!, style: AkText.caption.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

/// Ligne de liste : titre, sous-titre, élément de tête et de queue ; hauteur minimale confort (48 px au toucher).
class AkListRow extends StatelessWidget {
  const AkListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap});

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final row = Container(
      constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowComfort),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s1),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AkSpace.s3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(style: AkText.body.copyWith(color: t.text), child: title),
                if (subtitle != null) DefaultTextStyle.merge(style: AkText.caption.copyWith(color: t.textMuted), child: subtitle!),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AkSpace.s3), trailing!],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, hoverColor: t.rowSelected, child: row);
  }
}
