import 'package:flutter/material.dart';

import '../tokens.dart';
import 'feedback.dart';
import 'layout.dart';

/// Colonne d'un [AkTable] : largeur fixe ([width]) ou proportionnelle ([flex]) ; [numeric] aligne à droite en Plex Mono.
class AkColumn<R> {
  const AkColumn({required this.label, required this.cell, this.width, this.flex = 1, this.numeric = false, this.footer});

  /// Colonne texte : [text] fournit le contenu de la cellule.
  AkColumn.text({required this.label, required String Function(R) text, this.width, this.flex = 1, this.numeric = false, this.footer})
    : cell = ((context, r) => Text(
        text(r),
        overflow: TextOverflow.ellipsis,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
        style: numeric ? AkText.amount.copyWith(color: context.ak.text) : AkText.table.copyWith(color: context.ak.text),
      ));

  final String label;
  final Widget Function(BuildContext context, R row) cell;
  final double? width;
  final int flex;
  final bool numeric;

  /// Texte du pied de totaux (facultatif) ; aligné comme la colonne.
  final String? footer;
}

/// Tableau dense pour les balances, grands livres et listes : en-tête teinté, lignes de 32 px (48 px sur mobile),
/// montants à droite, pied de totaux facultatif, défilement horizontal sous [minWidth].
class AkTable<R> extends StatelessWidget {
  const AkTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.minWidth = 640,
    this.emptyMessage = 'Aucune ligne',
    this.rowColor,
    this.footerLabel,
    this.shrinkWrap = false,
    this.bare = false,
  });

  final List<AkColumn<R>> columns;
  final List<R> rows;
  final void Function(R row)? onRowTap;
  final double minWidth;
  final String emptyMessage;

  /// Teinte d'une ligne (ex. ligne en erreur).
  final Color? Function(R row)? rowColor;

  /// Si non nul, une ligne de pied (totaux) est ajoutée avec les `footer` des colonnes.
  final String? footerLabel;
  final bool shrinkWrap;

  /// Sans cadre de carte : le tableau s'insère dans une carte parente (onglets, panneaux).
  final bool bare;

  Widget _cells(BuildContext context, List<Widget> cells) {
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: AkSpace.s3),
          columns[i].width != null
              ? SizedBox(
                  width: columns[i].width,
                  child: Align(alignment: columns[i].numeric ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                )
              : Expanded(
                  flex: columns[i].flex,
                  child: Align(alignment: columns[i].numeric ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final rowH = akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact;
    final header = Container(
      height: rowH,
      color: t.tableHead,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
      child: _cells(context, [
        for (final c in columns)
          Text(
            c.label,
            overflow: TextOverflow.ellipsis,
            textAlign: c.numeric ? TextAlign.right : TextAlign.start,
            style: AkText.tableHead.copyWith(color: t.textMuted),
          ),
      ]),
    );
    Widget row(R r) {
      final content = Container(
        constraints: BoxConstraints(minHeight: rowH),
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: 2),
        decoration: BoxDecoration(
          color: rowColor?.call(r),
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: _cells(context, [for (final c in columns) c.cell(context, r)]),
      );
      return onRowTap == null ? content : InkWell(hoverColor: t.rowSelected, onTap: () => onRowTap!(r), child: content);
    }

    final hasFooter = footerLabel != null;
    Widget footer() => Container(
      constraints: BoxConstraints(minHeight: rowH),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: 2),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.borderControl, width: 2)),
      ),
      child: _cells(context, [
        for (var i = 0; i < columns.length; i++)
          Text(
            i == 0 && columns[i].footer == null ? footerLabel! : (columns[i].footer ?? ''),
            overflow: TextOverflow.ellipsis,
            textAlign: columns[i].numeric ? TextAlign.right : TextAlign.start,
            style: (columns[i].numeric ? AkText.amountTotal : AkText.tableHead).copyWith(color: t.textStrong),
          ),
      ]),
    );

    final body = rows.isEmpty
        ? Padding(padding: const EdgeInsets.all(AkSpace.s6), child: AkEmptyState(emptyMessage))
        : Column(children: [for (final r in rows) row(r)]);
    final table = Column(mainAxisSize: MainAxisSize.min, children: [header, body, if (hasFooter && rows.isNotEmpty) footer()]);

    final scrollable = LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
    if (bare) return scrollable;
    return AkCard(padding: EdgeInsets.zero, clip: true, child: scrollable);
  }
}
