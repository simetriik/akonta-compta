import 'package:flutter/material.dart';

import '../tokens.dart';

/// Vrai sur les écrans étroits (< 600 px) : contrôles tactiles de 48 px, marge de 16 px.
bool akIsCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// Marge latérale des écrans : 24 px sur ordinateur, 16 px sur mobile.
double akPageMargin(BuildContext context) => akIsCompact(context) ? AkSpace.s4 : AkSpace.s6;

/// Hauteur d'un champ ou d'un bouton : 40 px sur ordinateur, 48 px sur mobile.
double akControlHeight(BuildContext context) => akIsCompact(context) ? AkSpace.controlTouch : AkSpace.control;

/// Carte : surface blanche, filet, rayon 6, sans ombre.
class AkCard extends StatelessWidget {
  const AkCard({super.key, required this.child, this.padding = const EdgeInsets.all(AkSpace.s4), this.selected = false, this.clip = false, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Carte courante : contour terracotta de 2 px.
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
        borderRadius: AkRadius.lgAll,
        side: BorderSide(color: selected ? t.brand : t.border, width: selected ? 2 : 1),
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
        Text(title, style: AkText.titleLg.copyWith(color: t.text)),
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
          child: Text(text, style: AkText.heading.copyWith(color: context.ak.text)),
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
