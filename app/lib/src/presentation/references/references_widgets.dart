import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

/// Barre d'outils d'un onglet : filtres à gauche, action principale à droite (sous les filtres sur mobile).
class ListToolbar extends StatelessWidget {
  const ListToolbar({super.key, this.filters = const [], this.action});

  final List<Widget> filters;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final compact = akIsCompact(context);
    final filterWrap = Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: filters);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filters.isNotEmpty) filterWrap,
                if (filters.isNotEmpty && action != null) const SizedBox(height: AkSpace.s2),
                ?action,
              ],
            )
          : Row(
              children: [
                Expanded(child: filterWrap),
                if (action != null) ...[const SizedBox(width: AkSpace.s3), action!],
              ],
            ),
    );
  }
}

/// Champ de recherche compact (32 px, 48 px sur mobile).
class ToolbarSearchField extends StatelessWidget {
  const ToolbarSearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: akIsCompact(context) ? double.infinity : 280,
      child: Semantics(
        label: hint,
        child: AkTextField(dense: true, hint: hint, prefixIcon: const Icon(Icons.search, size: 18), onChanged: onChanged),
      ),
    );
  }
}

/// Ligne de liste : filet bas, hauteur tactile sur mobile.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.child, this.onTap, this.indent = 0});

  final Widget child;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact + 8),
      padding: EdgeInsets.fromLTRB(AkSpace.s4 + indent, 4, AkSpace.s2, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.ak.border)),
      ),
      child: child,
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Mention « Désactivé » (icône + mot) pour un élément retiré de l'usage.
class InactiveBadge extends StatelessWidget {
  const InactiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkBadge(label: 'Désactivé', color: t.textMuted, tint: t.surfaceSunken, icon: Icons.block);
  }
}

Widget formError(String error, {Key? key}) => Padding(
  padding: const EdgeInsets.only(top: AkSpace.s2),
  child: AkBanner(
    kind: AkBannerKind.danger,
    child: Text(error, key: key),
  ),
);

Future<String?> promptText(BuildContext context, String title, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AkDialog(
      title: title,
      content: AkTextField(controller: c, autofocus: true),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx)),
        AkButton.primary('Valider', onPressed: () => Navigator.pop(ctx, c.text)),
      ],
    ),
  );
}

/// Liste déroulante compacte de barre d'outils (largeur bornée).
Widget toolbarDropdown<T>({required T? value, required String hint, required List<AkOption<T>> items, required ValueChanged<T?> onChanged}) => SizedBox(
  width: 160,
  child: AkDropdown<T>(value: value, hint: hint, dense: true, items: items, onChanged: onChanged),
);
