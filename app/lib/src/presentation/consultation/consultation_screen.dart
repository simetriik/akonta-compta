import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/consultation_repository.dart';
import '../../data/entities_repository.dart';
import '../../data/references_repository.dart';
import '../../domain/models.dart';
import '../widgets/ak_widgets.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

/// Consultation du dossier courant : grand livre, balances, balance âgée, centralisateur ; période libre, comparaison N-1, exports (§10.6).
class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _ConsultationBody(entity: entity));
}

class _ConsultationBody extends ConsumerStatefulWidget {
  const _ConsultationBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_ConsultationBody> createState() => _ConsultationBodyState();
}

class _ConsultationBodyState extends ConsumerState<_ConsultationBody> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);
  late final _from = TextEditingController(text: '01/01/${DateTime.now().year}');
  late final _to = TextEditingController(text: Fmt.date(DateTime.now()));
  final _accountFrom = TextEditingController();
  final _accountTo = TextEditingController();
  int? _classNo;
  String _side = 'debit';
  bool _compare = false;
  bool _exporting = false;

  ConsultationParams? _params() {
    final from = Fmt.parseDate(_from.text), to = Fmt.parseDate(_to.text);
    if (from == null || to == null || to.isBefore(from)) return null;
    final fys = ref.read(fiscalYearsProvider(widget.entity.id)).value ?? const [];
    final fy = fys.where((f) => !from.isBefore(f.startDate) && !from.isAfter(f.endDate)).firstOrNull;
    return ConsultationParams(
      entityId: widget.entity.id,
      from: from,
      to: to,
      accountFrom: _accountFrom.text.trim().isEmpty ? null : _accountFrom.text.trim(),
      accountTo: _accountTo.text.trim().isEmpty ? null : _accountTo.text.trim(),
      classNo: _classNo,
      side: _side,
      fiscalYearId: fy?.id,
    );
  }

  ConsultationParams? _previousYear(ConsultationParams p) {
    try {
      return ConsultationParams(entityId: p.entityId, from: DateTime(p.from.year - 1, p.from.month, p.from.day), to: DateTime(p.to.year - 1, p.to.month, p.to.day), accountFrom: p.accountFrom, accountTo: p.accountTo, classNo: p.classNo, side: p.side);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fiscalYearsProvider(widget.entity.id));
    final p = _params();
    final t = context.ak;
    final margin = akPageMargin(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AkPageHead(title: 'Consultation', subtitle: widget.entity.dossierLabel, actions: [_exportMenu(context)]),
        const SizedBox(height: AkSpace.s3),
        Expanded(
          child: AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                tabs: const [Tab(text: 'Grand livre'), Tab(text: 'Balance générale'), Tab(text: 'Balance auxiliaire'), Tab(text: 'Balance âgée'), Tab(text: 'Centralisateur')],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                child: _filters(context),
              ),
              Expanded(
                child: p == null
                    ? Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Align(alignment: Alignment.topLeft, child: AkBanner(kind: AkBannerKind.warning, child: const Text('Dates invalides (jj/mm/aaaa).'))))
                    : TabBarView(controller: _tabs, children: [
                        _LedgerTab(params: p),
                        _BalanceTab(params: p, previous: _compare ? _previousYear(p) : null),
                        _AuxiliaryTab(params: p),
                        _AgedTab(params: p, side: _side, onSide: (s) => setState(() => _side = s)),
                        _CentralizationTab(params: p),
                      ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Filtres de période, de comptes et de classe ; l'actualisation relit les champs.
  Widget _filters(BuildContext context) {
    final t = context.ak;
    final h = akControlHeight(context);
    Widget labelled(String label, Widget field) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AkText.label.copyWith(color: t.textMuted)),
          const SizedBox(width: 6),
          field,
        ]);
    Widget input(TextEditingController c, String semantic, double width, {bool mono = false}) => SizedBox(
          width: width,
          height: h,
          child: Semantics(
            label: semantic,
            child: TextField(
              controller: c,
              style: (mono ? AkText.code : AkText.table).copyWith(color: t.text),
              decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: (h - 18) / 2)),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        );
    return Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
      labelled('Du', input(_from, 'Date de début', 110)),
      labelled('Au', input(_to, 'Date de fin', 110)),
      labelled('Comptes', Row(mainAxisSize: MainAxisSize.min, children: [
        input(_accountFrom, 'Compte de', 96, mono: true),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('à', style: AkText.table.copyWith(color: t.textMuted))),
        input(_accountTo, 'Compte à', 96, mono: true),
      ])),
      Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
        decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderControl), borderRadius: AkRadius.mdAll),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _classNo,
            isDense: true,
            hint: Text('Toutes classes', style: AkText.table.copyWith(color: t.text)),
            style: AkText.table.copyWith(color: t.text),
            icon: Icon(Icons.expand_more, size: 18, color: t.textMuted),
            items: [const DropdownMenuItem(value: null, child: Text('Toutes classes')), for (var c = 1; c <= 8; c++) DropdownMenuItem(value: c, child: Text('Classe $c'))],
            onChanged: (v) => setState(() => _classNo = v),
          ),
        ),
      ),
      InkWell(
        borderRadius: AkRadius.mdAll,
        onTap: () => setState(() => _compare = !_compare),
        child: SizedBox(
          height: h,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(value: _compare, onChanged: (v) => setState(() => _compare = v ?? false)),
            Text('Comparer N-1', style: AkText.table.copyWith(color: t.text)),
            const SizedBox(width: AkSpace.s1),
          ]),
        ),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: Size(0, h)),
        onPressed: () => setState(() {}),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Actualiser'),
      ),
    ]);
  }

  /// Menu d'export (PDF ou Excel) placé dans l'en-tête de l'écran.
  Widget _exportMenu(BuildContext context) {
    final t = context.ak;
    final h = akControlHeight(context);
    return PopupMenuButton<String>(
      tooltip: 'Exporter',
      enabled: !_exporting,
      onSelected: _export,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'trial_balance:pdf', child: Text('Balance — PDF')),
        PopupMenuItem(value: 'trial_balance:xlsx', child: Text('Balance — Excel')),
        PopupMenuItem(value: 'general_ledger:pdf', child: Text('Grand livre — PDF')),
        PopupMenuItem(value: 'general_ledger:xlsx', child: Text('Grand livre — Excel')),
        PopupMenuItem(value: 'aged_balance:pdf', child: Text('Balance âgée — PDF')),
      ],
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
        decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderStrong), borderRadius: AkRadius.mdAll),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_exporting) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.download_outlined, size: 18, color: t.text),
          const SizedBox(width: 6),
          Text('Exporter', style: AkText.bodyStrong.copyWith(color: t.text)),
        ]),
      ),
    );
  }

  Future<void> _export(String choice) async {
    final p = _params();
    if (p == null) return;
    final parts = choice.split(':');
    setState(() => _exporting = true);
    try {
      final (name, bytes) = await ref.read(consultationRepositoryProvider).export(p: p, kind: parts[0], format: parts[1]);
      final uri = await FilePicker.saveFile(dialogTitle: 'Enregistrer l\'export', fileName: name, bytes: bytes);
      if (uri != null && uri.scheme == 'file') {
        final f = File(uri.toFilePath());
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
      }
      if (mounted && uri != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export enregistré : ${uri.scheme == 'file' ? uri.toFilePath() : uri}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: context.ak.danger));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Tableau commun : en-tête fixe, lignes de section, ligne de totaux en gras
// ---------------------------------------------------------------------------

/// Colonne du tableau ; `grow` absorbe la largeur disponible en plus de la largeur minimale.
class _Col {
  const _Col(this.label, this.width, {this.numeric = false, this.grow = false});

  final String label;
  final double width;
  final bool numeric;
  final bool grow;
}

enum _RowKind { normal, section, total }

class _GRow {
  const _GRow(this.cells, {this.kind = _RowKind.normal, this.onTap}) : sectionChild = null;

  /// Ligne de section pleine largeur (classe, compte, journal).
  const _GRow.section(Widget this.sectionChild) : cells = const [], kind = _RowKind.section, onTap = null;

  final List<Widget> cells;
  final _RowKind kind;
  final VoidCallback? onTap;
  final Widget? sectionChild;
}

Widget _txt(BuildContext context, String s, {bool bold = false, bool muted = false}) =>
    Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: muted ? context.ak.textMuted : context.ak.text, fontWeight: bold ? FontWeight.w600 : null));

Widget _codeTxt(BuildContext context, String s, {bool bold = false}) =>
    Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.code.copyWith(color: context.ak.text, fontWeight: bold ? FontWeight.w600 : null));

Widget _amt(String s, {bool bold = false}) => AkAmountText(s, bold: bold);

class _DataGrid extends StatelessWidget {
  const _DataGrid({required this.columns, required this.rows, this.groups});

  final List<_Col> columns;
  final List<_GRow> rows;

  /// Regroupements d'en-têtes (libellé, nombre de colonnes) ; libellé vide = pas de regroupement.
  final List<(String, int)>? groups;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final rowH = akIsCompact(context) ? AkSpace.rowTouch : AkSpace.rowCompact;
    return LayoutBuilder(builder: (context, c) {
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

      Widget headerCell(int j) => Container(
            width: widths[j],
            padding: EdgeInsets.symmetric(horizontal: j == 0 ? AkSpace.s4 : AkSpace.s3),
            alignment: columns[j].numeric ? Alignment.centerRight : Alignment.centerLeft,
            decoration: sep(j),
            child: Text(columns[j].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.label.copyWith(color: t.textMuted)),
          );
      final groupCells = <Widget>[];
      if (groups != null) {
        var i = 0;
        for (final g in groups!) {
          final start = i;
          i += g.$2;
          final w = widths.sublist(start, start + g.$2).fold<double>(0, (s, x) => s + x);
          groupCells.add(Container(
            width: w,
            alignment: Alignment.center,
            decoration: sep(start),
            child: Text(g.$1, style: AkText.label.copyWith(color: t.textMuted)),
          ));
        }
      }
      final header = Column(mainAxisSize: MainAxisSize.min, children: [
        if (groups != null)
          Container(
            height: rowH,
            color: t.surfaceSunken,
            child: Row(children: groupCells),
          ),
        Container(
          height: rowH,
          decoration: BoxDecoration(color: t.surfaceSunken, border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [for (var j = 0; j < columns.length; j++) headerCell(j)]),
        ),
      ]);

      Widget rowAt(int i) {
        final r = rows[i];
        if (r.kind == _RowKind.section) {
          return Container(
            width: total,
            height: rowH,
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: t.surfaceSunken, border: Border(bottom: BorderSide(color: t.border))),
            child: r.sectionChild,
          );
        }
        final isTotal = r.kind == _RowKind.total;
        Widget row = Container(
          height: rowH,
          decoration: BoxDecoration(
            color: isTotal ? t.surfaceSunken : null,
            border: Border(top: isTotal ? BorderSide(color: t.borderStrong) : BorderSide.none, bottom: BorderSide(color: t.border)),
          ),
          child: Row(children: [
            for (var j = 0; j < columns.length; j++)
              Container(
                width: widths[j],
                padding: EdgeInsets.symmetric(horizontal: j == 0 ? AkSpace.s4 : AkSpace.s3),
                alignment: columns[j].numeric ? Alignment.centerRight : Alignment.centerLeft,
                decoration: sep(j),
                child: j < r.cells.length ? r.cells[j] : null,
              ),
          ]),
        );
        if (r.onTap != null) row = InkWell(onTap: r.onTap, child: row);
        return row;
      }

      final content = Column(children: [header, Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => rowAt(i)))]);
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: total, child: content));
    });
  }
}

/// Libellé de classe SYSCOHADA pour les lignes de section de la balance.
String _classLabel(int c) => switch (c) {
      1 => 'Ressources durables',
      2 => 'Actif immobilisé',
      3 => 'Stocks',
      4 => 'Tiers',
      5 => 'Trésorerie',
      6 => 'Charges des activités ordinaires',
      7 => 'Produits des activités ordinaires',
      8 => 'Autres charges et produits',
      _ => '',
    };

Widget _sectionText(BuildContext context, String s) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.bodyStrong.copyWith(color: context.ak.text));

const _balanceGroups = <(String, int)>[('', 2), ('Ouverture', 2), ('Mouvements', 2), ('Clôture', 2)];

// ---------------------------------------------------------------------------
// Grand livre
// ---------------------------------------------------------------------------

sealed class _LItem {}

class _LHead extends _LItem {
  _LHead(this.code, this.label);
  final String code;
  final String label;
}

class _LLine extends _LItem {
  _LLine(this.line);
  final LedgerLine line;
}

class _LTotal extends _LItem {
  _LTotal(this.debit, this.credit);
  final int debit;
  final int credit;
}

class _LedgerTab extends ConsumerWidget {
  const _LedgerTab({required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(generalLedgerProvider(params));
    return AsyncView(
      value: lines,
      onRetry: () => ref.invalidate(generalLedgerProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucune écriture validée sur la période.');
        final items = <_LItem>[];
        String? current;
        var subD = 0, subC = 0;
        void flush() {
          if (current != null) items.add(_LTotal(subD, subC));
          subD = 0;
          subC = 0;
        }
        for (final l in list) {
          if (l.accountCode != current) {
            flush();
            current = l.accountCode;
            items.add(_LHead(l.accountCode, l.accountLabel));
          }
          subD += l.debit;
          subC += l.credit;
          items.add(_LLine(l));
        }
        flush();
        return akIsCompact(context) ? _LedgerList(items: items) : _LedgerGrid(items: items);
      },
    );
  }
}

class _LedgerGrid extends StatelessWidget {
  const _LedgerGrid({required this.items});

  final List<_LItem> items;

  @override
  Widget build(BuildContext context) {
    final rows = <_GRow>[
      for (final it in items)
        switch (it) {
          _LHead h => _GRow.section(Row(children: [_codeTxt(context, h.code, bold: true), const SizedBox(width: AkSpace.s2), Flexible(child: _sectionText(context, '— ${h.label}'))])),
          _LLine(:final line) => _GRow([
              _txt(context, Fmt.date(line.entryDate)),
              _codeTxt(context, '${line.journalCode}-${line.number}'),
              _codeTxt(context, line.reference ?? ''),
              _txt(context, line.label),
              _codeTxt(context, line.thirdPartyCode ?? ''),
              _amt(Fmt.fcfa(line.debit)),
              _amt(Fmt.fcfa(line.credit)),
              _amt(Fmt.fcfa(line.runningBalance, showZero: true)),
              _codeTxt(context, line.letterCode ?? ''),
            ], onTap: () => context.go('/saisie/${line.entryId}')),
          _LTotal tot => _GRow([
              const SizedBox.shrink(),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
              _txt(context, 'Total compte', bold: true),
              const SizedBox.shrink(),
              _amt(Fmt.fcfa(tot.debit, showZero: true), bold: true),
              _amt(Fmt.fcfa(tot.credit, showZero: true), bold: true),
              _amt(Fmt.fcfa(tot.debit - tot.credit, showZero: true), bold: true),
            ], kind: _RowKind.total),
        },
    ];
    return _DataGrid(
      columns: const [
        _Col('Date', 116),
        _Col('Pièce', 96),
        _Col('Référence', 110),
        _Col('Libellé', 240, grow: true),
        _Col('Tiers', 90),
        _Col('Débit', 120, numeric: true),
        _Col('Crédit', 120, numeric: true),
        _Col('Solde', 130, numeric: true),
        _Col('Lettre', 70),
      ],
      rows: rows,
    );
  }
}

/// Grand livre sur mobile : une ligne tactile par mouvement, lecture seule (maquette MobileCompte).
class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.items});

  final List<_LItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        switch (items[i]) {
          case _LHead h:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
              decoration: BoxDecoration(color: t.surfaceSunken, border: Border(bottom: BorderSide(color: t.border))),
              child: Row(children: [
                Text(h.code, style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600)),
                const SizedBox(width: AkSpace.s2),
                Expanded(child: Text(h.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.bodyStrong.copyWith(color: t.text))),
              ]),
            );
          case _LTotal tot:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
              decoration: BoxDecoration(color: t.surfaceSunken, border: Border(bottom: BorderSide(color: t.border))),
              child: Row(children: [
                Expanded(child: Text('Total compte', style: AkText.bodyStrong.copyWith(color: t.text))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  AkAmountText('D ${Fmt.fcfa(tot.debit, showZero: true)}', bold: true),
                  AkAmountText('C ${Fmt.fcfa(tot.credit, showZero: true)}', bold: true),
                  AkAmountText('Solde ${Fmt.fcfa(tot.debit - tot.credit, showZero: true)}', bold: true),
                ]),
              ]),
            );
          case _LLine(:final line):
            final debit = line.debit != 0;
            final meta = [
              '${line.journalCode}-${line.number}',
              if (line.reference != null && line.reference!.isNotEmpty) line.reference!,
              if (line.thirdPartyCode != null) line.thirdPartyCode!,
              if (line.letterCode != null) 'lettre ${line.letterCode}',
            ].join(' · ');
            return InkWell(
              onTap: () => context.go('/saisie/${line.entryId}'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                child: Row(children: [
                  SizedBox(width: 84, child: Text(Fmt.date(line.entryDate), style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(line.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AkText.body.copyWith(color: t.text)),
                      Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.code.copyWith(fontSize: 12, color: t.textMuted)),
                    ]),
                  ),
                  const SizedBox(width: AkSpace.s2),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    AkAmountText('${debit ? 'D' : 'C'} ${Fmt.fcfa(debit ? line.debit : line.credit)}', bold: true),
                    Text('Solde ${Fmt.fcfa(line.runningBalance, showZero: true)}', style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ]),
              ),
            );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Balance générale
// ---------------------------------------------------------------------------

class _BalanceTab extends ConsumerWidget {
  const _BalanceTab({required this.params, this.previous});

  final ConsultationParams params;
  final ConsultationParams? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(trialBalanceProvider(params));
    final prevRows = previous == null ? null : ref.watch(trialBalanceProvider(previous!)).value;
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(trialBalanceProvider(params)),
      builder: (list) {
        final prevByCode = {for (final r in prevRows ?? const <BalanceRow>[]) r.accountCode: r};
        int t(int Function(BalanceRow) f) => list.fold(0, (s, r) => s + f(r));
        final withPrev = previous != null;
        final grid = <_GRow>[];
        int? lastClass;
        for (final r in list) {
          final cls = r.accountCode.isEmpty ? null : int.tryParse(r.accountCode[0]);
          if (cls != null && cls != lastClass) {
            lastClass = cls;
            final label = _classLabel(cls);
            grid.add(_GRow.section(_sectionText(context, label.isEmpty ? 'Classe $cls' : 'Classe $cls · $label')));
          }
          final prev = prevByCode[r.accountCode];
          grid.add(_GRow([
            _codeTxt(context, r.accountCode),
            _txt(context, r.accountLabel),
            _amt(Fmt.fcfa(r.openingDebit)),
            _amt(Fmt.fcfa(r.openingCredit)),
            _amt(Fmt.fcfa(r.periodDebit)),
            _amt(Fmt.fcfa(r.periodCredit)),
            _amt(Fmt.fcfa(r.closingDebit)),
            _amt(Fmt.fcfa(r.closingCredit)),
            if (withPrev) _amt(Fmt.fcfa((prev?.closingDebit ?? 0) - (prev?.closingCredit ?? 0), showZero: true)),
          ]));
        }
        grid.add(_GRow([
          const SizedBox.shrink(),
          _txt(context, 'Totaux', bold: true),
          _amt(Fmt.fcfa(t((r) => r.openingDebit), showZero: true), bold: true),
          _amt(Fmt.fcfa(t((r) => r.openingCredit), showZero: true), bold: true),
          _amt(Fmt.fcfa(t((r) => r.periodDebit), showZero: true), bold: true),
          _amt(Fmt.fcfa(t((r) => r.periodCredit), showZero: true), bold: true),
          _amt(Fmt.fcfa(t((r) => r.closingDebit), showZero: true), bold: true),
          _amt(Fmt.fcfa(t((r) => r.closingCredit), showZero: true), bold: true),
          if (withPrev) const SizedBox.shrink(),
        ], kind: _RowKind.total));
        return _DataGrid(
          groups: [..._balanceGroups, if (withPrev) ('', 1)],
          columns: [
            const _Col('Compte', 110),
            const _Col('Intitulé', 260, grow: true),
            const _Col('Débit', 112, numeric: true),
            const _Col('Crédit', 112, numeric: true),
            const _Col('Débit', 112, numeric: true),
            const _Col('Crédit', 112, numeric: true),
            const _Col('Débit', 112, numeric: true),
            const _Col('Crédit', 112, numeric: true),
            if (withPrev) const _Col('Solde N-1', 120, numeric: true),
          ],
          rows: grid,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Balance auxiliaire
// ---------------------------------------------------------------------------

class _AuxiliaryTab extends ConsumerWidget {
  const _AuxiliaryTab({required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(auxiliaryBalanceProvider(params));
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(auxiliaryBalanceProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucun mouvement de tiers sur la période.');
        return _DataGrid(
          groups: const [('', 3), ('Ouverture', 2), ('Mouvements', 2), ('Clôture', 2)],
          columns: const [
            _Col('Collectif', 100),
            _Col('Tiers', 96),
            _Col('Nom', 240, grow: true),
            _Col('Débit', 112, numeric: true),
            _Col('Crédit', 112, numeric: true),
            _Col('Débit', 112, numeric: true),
            _Col('Crédit', 112, numeric: true),
            _Col('Débit', 112, numeric: true),
            _Col('Crédit', 112, numeric: true),
          ],
          rows: [
            for (final r in list)
              _GRow([
                _codeTxt(context, r.accountCode),
                _codeTxt(context, r.thirdPartyCode ?? ''),
                _txt(context, r.thirdPartyName ?? ''),
                _amt(Fmt.fcfa(r.openingDebit)),
                _amt(Fmt.fcfa(r.openingCredit)),
                _amt(Fmt.fcfa(r.periodDebit)),
                _amt(Fmt.fcfa(r.periodCredit)),
                _amt(Fmt.fcfa(r.closingDebit)),
                _amt(Fmt.fcfa(r.closingCredit)),
              ]),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Balance âgée
// ---------------------------------------------------------------------------

class _AgedTab extends ConsumerWidget {
  const _AgedTab({required this.params, required this.side, required this.onSide});

  final ConsultationParams params;
  final String side;
  final ValueChanged<String> onSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final rows = ref.watch(agedBalanceProvider(params));
    final h = akControlHeight(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s3),
        child: Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: Size(0, h),
              textStyle: AkText.table,
              foregroundColor: t.text,
              backgroundColor: t.surface,
              selectedForegroundColor: t.brandText,
              selectedBackgroundColor: t.brandTint,
              side: BorderSide(color: t.borderControl),
              shape: const RoundedRectangleBorder(borderRadius: AkRadius.mdAll),
            ),
            segments: const [ButtonSegment(value: 'debit', label: Text('Clients (débiteurs)')), ButtonSegment(value: 'credit', label: Text('Fournisseurs (créditeurs)'))],
            selected: {side},
            onSelectionChanged: (s) => onSide(s.first),
          ),
          Text('À la date du ${Fmt.date(params.to)} · lignes non lettrées', style: AkText.caption.copyWith(color: t.textMuted)),
        ]),
      ),
      Divider(height: 1, color: t.border),
      Expanded(
        child: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(agedBalanceProvider(params)),
          builder: (list) {
            if (list.isEmpty) return const AkEmptyState('Aucune ligne non lettrée à cette date.');
            return _DataGrid(
              columns: const [
                _Col('Compte', 100),
                _Col('Tiers', 96),
                _Col('Nom', 220, grow: true),
                _Col('0-30 j', 110, numeric: true),
                _Col('31-60 j', 110, numeric: true),
                _Col('61-90 j', 110, numeric: true),
                _Col('91-180 j', 110, numeric: true),
                _Col('> 180 j', 110, numeric: true),
                _Col('Total', 130, numeric: true),
              ],
              rows: [
                for (final r in list)
                  _GRow([
                    _codeTxt(context, r.accountCode),
                    _codeTxt(context, r.thirdPartyCode),
                    _txt(context, r.thirdPartyName),
                    _amt(Fmt.fcfa(r.d0_30)),
                    _amt(Fmt.fcfa(r.d31_60)),
                    _amt(Fmt.fcfa(r.d61_90)),
                    _amt(Fmt.fcfa(r.d91_180)),
                    _amt(Fmt.fcfa(r.over180)),
                    _amt(Fmt.fcfa(r.total, showZero: true), bold: true),
                  ]),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Centralisateur
// ---------------------------------------------------------------------------

class _CentralizationTab extends ConsumerWidget {
  const _CentralizationTab({required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (params.fiscalYearId == null) {
      return Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Align(alignment: Alignment.topLeft, child: AkBanner(kind: AkBannerKind.warning, child: const Text('Aucun exercice ne contient la date de début.'))));
    }
    final rows = ref.watch(centralizationProvider(params));
    final journals = ref.watch(journalsProvider(params.entityId)).value ?? const [];
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(centralizationProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucune écriture validée sur cet exercice.');
        final byJournal = <String, List<CentralizationRow>>{};
        for (final r in list) {
          byJournal.putIfAbsent(r.journalCode, () => []).add(r);
        }
        final grid = <_GRow>[];
        for (final e in byJournal.entries) {
          final label = journals.where((j) => j.code == e.key).firstOrNull?.label ?? e.value.first.journalLabel;
          grid.add(_GRow.section(Row(children: [_codeTxt(context, e.key, bold: true), const SizedBox(width: AkSpace.s2), Flexible(child: _sectionText(context, '— $label'))])));
          for (final r in e.value) {
            grid.add(_GRow([
              _txt(context, Fmt.month(r.monthStart)),
              _txt(context, '${r.entriesCount} écr.', muted: true),
              _amt(Fmt.fcfa(r.totalDebit, showZero: true)),
              _amt(Fmt.fcfa(r.totalCredit, showZero: true)),
            ]));
          }
          grid.add(_GRow([
            _txt(context, 'Total journal', bold: true),
            const SizedBox.shrink(),
            _amt(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalDebit), showZero: true), bold: true),
            _amt(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalCredit), showZero: true), bold: true),
          ], kind: _RowKind.total));
        }
        return _DataGrid(
          columns: const [
            _Col('Mois', 200, grow: true),
            _Col('Écritures', 100),
            _Col('Débit', 140, numeric: true),
            _Col('Crédit', 140, numeric: true),
          ],
          rows: grid,
        );
      },
    );
  }
}
