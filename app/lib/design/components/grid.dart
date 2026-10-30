import 'package:flutter/material.dart';

import '../tokens.dart';
import 'layout.dart';

/// Colonne d'un [AkGrid] : largeur minimale [width] ; [grow] absorbe la largeur disponible en plus.
class AkGridColumn {
  const AkGridColumn(this.label, this.width, {this.numeric = false, this.grow = false});

  final String label;
  final double width;
  final bool numeric;
  final bool grow;
}

/// Nature d'une ligne : donnée, section (classe, compte, journal) ou total (sous-total, total général).
enum AkGridRowKind { normal, section, total }

class AkGridRow {
  const AkGridRow(this.cells, {this.kind = AkGridRowKind.normal, this.onTap}) : sectionChild = null;

  /// Ligne de section pleine largeur.
  const AkGridRow.section(Widget this.sectionChild) : cells = const [], kind = AkGridRowKind.section, onTap = null;

  final List<Widget> cells;
  final AkGridRowKind kind;
  final VoidCallback? onTap;
  final Widget? sectionChild;
}

/// Tableau de consultation unique pour les longues listes (grand livre, balances, centralisateur) :
/// en-tête figé sur `tableHead`, groupes d'en-têtes, lignes paresseuses de hauteur minimale, lignes de section et de total,
/// défilement horizontal en dessous de la largeur cumulée des colonnes. À placer dans un parent de hauteur bornée.
class AkGrid extends StatelessWidget {
  const AkGrid({super.key, required this.columns, required this.rows, this.groups});

  final List<AkGridColumn> columns;
  final List<AkGridRow> rows;

  /// Regroupements d'en-têtes (libellé, nombre de colonnes) ; libellé vide = pas de regroupement.
  final List<(String, int)>? groups;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final rowH = akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact;
    return LayoutBuilder(
      builder: (context, c) {
        final base = columns.fold<double>(0, (s, col) => s + col.width);
        final extra = c.maxWidth.isFinite && c.maxWidth > base ? c.maxWidth - base : 0.0;
        final widths = [for (final col in columns) col.width + (col.grow ? extra : 0)];
        final total = base + extra;
        // Colonnes qui ouvrent un groupe : filet vertical à gauche.
        final starts = <int>{};
        if (groups != null) {
          var i = 0;
          for (final g in groups!) {
            if (g.$1.isNotEmpty) starts.add(i);
            i += g.$2;
          }
        }
        BoxDecoration? sep(int j) => starts.contains(j) ? BoxDecoration(border: Border(left: BorderSide(color: t.border))) : null;
        EdgeInsets pad(int j) => EdgeInsets.symmetric(horizontal: j == 0 ? AkSpace.s4 : AkSpace.s3);

        Widget headerCell(int j) => Container(
          width: widths[j],
          padding: pad(j),
          alignment: columns[j].numeric ? Alignment.centerRight : Alignment.centerLeft,
          decoration: sep(j),
          child: Text(columns[j].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.tableHead.copyWith(color: t.textMuted)),
        );
        final groupCells = <Widget>[];
        if (groups != null) {
          var i = 0;
          for (final g in groups!) {
            final start = i;
            i += g.$2;
            final w = widths.sublist(start, start + g.$2).fold<double>(0, (s, x) => s + x);
            groupCells.add(
              Container(
                width: w,
                alignment: Alignment.center,
                decoration: sep(start),
                child: Text(g.$1, style: AkText.tableHead.copyWith(color: t.textMuted)),
              ),
            );
          }
        }
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (groups != null) Container(constraints: BoxConstraints(minHeight: rowH), color: t.tableHead, child: Row(children: groupCells)),
            Container(
              constraints: BoxConstraints(minHeight: rowH),
              decoration: BoxDecoration(
                color: t.tableHead,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(children: [for (var j = 0; j < columns.length; j++) headerCell(j)]),
            ),
          ],
        );

        Widget rowAt(int i) {
          final r = rows[i];
          if (r.kind == AkGridRowKind.section) {
            return Container(
              width: total,
              constraints: BoxConstraints(minHeight: rowH),
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: t.tableHead,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: DefaultTextStyle.merge(style: TextStyle(color: t.textStrong), child: r.sectionChild!),
            );
          }
          final isTotal = r.kind == AkGridRowKind.total;
          Widget row = Container(
            constraints: BoxConstraints(minHeight: rowH),
            decoration: BoxDecoration(
              color: isTotal ? t.surfaceSunken : null,
              border: Border(
                top: isTotal ? BorderSide(color: t.borderControl, width: 2) : BorderSide.none,
                bottom: BorderSide(color: t.border),
              ),
            ),
            child: Row(
              children: [
                for (var j = 0; j < columns.length; j++)
                  Container(
                    width: widths[j],
                    padding: pad(j),
                    alignment: columns[j].numeric ? Alignment.centerRight : Alignment.centerLeft,
                    decoration: sep(j),
                    child: j < r.cells.length ? r.cells[j] : null,
                  ),
              ],
            ),
          );
          if (r.onTap != null) row = InkWell(onTap: r.onTap, hoverColor: t.rowSelected, child: row);
          return row;
        }

        final content = Column(
          children: [
            header,
            Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => rowAt(i))),
          ],
        );
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: total, child: content));
      },
    );
  }
}
