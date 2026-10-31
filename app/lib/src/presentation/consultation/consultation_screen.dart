
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../widgets/error_display.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/consultation_providers.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../domain/consultation_models.dart';
import '../../application/providers/services.dart';
import '../widgets/save_export.dart';

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
      return ConsultationParams(
        entityId: p.entityId,
        from: DateTime(p.from.year - 1, p.from.month, p.from.day),
        to: DateTime(p.to.year - 1, p.to.month, p.to.day),
        accountFrom: p.accountFrom,
        accountTo: p.accountTo,
        classNo: p.classNo,
        side: p.side,
      );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AkPageHead(title: 'Consultation', subtitle: widget.entity.dossierLabel, actions: [_exportMenu(context)]),
          const SizedBox(height: AkSpace.s3),
          Expanded(
            child: AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                    tabs: const [
                      Tab(text: 'Grand livre'),
                      Tab(text: 'Balance générale'),
                      Tab(text: 'Balance auxiliaire'),
                      Tab(text: 'Balance âgée'),
                      Tab(text: 'Centralisateur'),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.border)),
                    ),
                    child: _filters(context),
                  ),
                  Expanded(
                    child: p == null
                        ? Padding(
                            padding: const EdgeInsets.all(AkSpace.s4),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: AkBanner(kind: AkBannerKind.warning, child: const Text('Dates invalides (jj/mm/aaaa).')),
                            ),
                          )
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _LedgerTab(params: p),
                              _BalanceTab(params: p, previous: _compare ? _previousYear(p) : null),
                              _AuxiliaryTab(params: p),
                              _AgedTab(params: p, side: _side, onSide: (s) => setState(() => _side = s)),
                              _CentralizationTab(params: p),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtres de période, de comptes et de classe ; l'actualisation relit les champs.
  Widget _filters(BuildContext context) {
    Widget sized(double width, Widget child) => SizedBox(width: width, child: child);
    return Wrap(
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        sized(176, AkDateField(controller: _from, label: 'Du', onSubmitted: (_) => setState(() {}))),
        sized(176, AkDateField(controller: _to, label: 'Au', onSubmitted: (_) => setState(() {}))),
        sized(136, AkTextField(controller: _accountFrom, label: 'Compte de', mono: true, onSubmitted: (_) => setState(() {}))),
        sized(136, AkTextField(controller: _accountTo, label: 'Compte à', mono: true, onSubmitted: (_) => setState(() {}))),
        sized(
          176,
          AkDropdown<int?>(
            label: 'Classe',
            value: _classNo,
            items: [const AkOption<int?>(null, 'Toutes classes'), for (var c = 1; c <= 8; c++) AkOption<int?>(c, 'Classe $c')],
            onChanged: (v) => setState(() => _classNo = v),
          ),
        ),
        SizedBox(
          height: akControlHeight(context),
          child: AkCheckbox(value: _compare, label: 'Comparer N-1', onChanged: (v) => setState(() => _compare = v)),
        ),
        AkButton.secondary('Actualiser', icon: Icons.refresh, onPressed: () => setState(() {})),
      ],
    );
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
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderControl),
          borderRadius: AkRadius.mdAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_exporting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.download_outlined, size: 18, color: t.text),
            const SizedBox(width: 6),
            Text('Exporter', style: AkText.bodyStrong.copyWith(color: t.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String choice) async {
    final p = _params();
    if (p == null) return;
    final parts = choice.split(':');
    setState(() => _exporting = true);
    try {
      final (name, bytes) = await ref.read(consultationServiceProvider).export(p: p, kind: parts[0], format: parts[1]);
      final uri = await saveExportedFile(dialogTitle: 'Enregistrer l\'export', fileName: name, bytes: bytes);
      if (mounted && uri != null) {
        showAkToast(context, 'Export enregistré : ${uri.scheme == 'file' ? uri.toFilePath() : uri}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Cellules de tableau communes (le tableau lui-même est AkGrid)
// ---------------------------------------------------------------------------

Widget _txt(BuildContext context, String s, {bool bold = false, bool muted = false}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.table.copyWith(color: muted ? context.ak.textMuted : context.ak.text, fontWeight: bold ? FontWeight.w600 : null),
);

Widget _codeTxt(BuildContext context, String s, {bool bold = false}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.code.copyWith(color: context.ak.text, fontWeight: bold ? FontWeight.w600 : null),
);

Widget _amt(String s, {bool bold = false}) => AkAmountText(s, bold: bold);

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

Widget _sectionText(BuildContext context, String s) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.bodyStrong.copyWith(color: context.ak.text),
);

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
    final rows = <AkGridRow>[
      for (final it in items)
        switch (it) {
          _LHead h => AkGridRow.section(
            Row(
              children: [
                _codeTxt(context, h.code, bold: true),
                const SizedBox(width: AkSpace.s2),
                Flexible(child: _sectionText(context, '— ${h.label}')),
              ],
            ),
          ),
          _LLine(:final line) => AkGridRow([
            _txt(context, Fmt.date(line.entryDate)),
            _codeTxt(context, '${line.journalCode}-${line.number}'),
            _codeTxt(context, line.reference ?? ''),
            _txt(context, line.label),
            _codeTxt(context, line.thirdPartyCode ?? ''),
            _amt(Fmt.fcfa(line.debit)),
            _amt(Fmt.fcfa(line.credit)),
            _amt(Fmt.balance(line.runningBalance)),
            _codeTxt(context, line.letterCode ?? ''),
          ], onTap: () => context.go('/saisie/${line.entryId}')),
          _LTotal tot => AkGridRow([
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _txt(context, 'Total compte', bold: true),
            const SizedBox.shrink(),
            _amt(Fmt.fcfa(tot.debit, showZero: true), bold: true),
            _amt(Fmt.fcfa(tot.credit, showZero: true), bold: true),
            _amt(Fmt.balance(tot.debit - tot.credit), bold: true),
          ], kind: AkGridRowKind.total),
        },
    ];
    return AkGrid(
      columns: const [
        AkGridColumn('Date', 116),
        AkGridColumn('Pièce', 124),
        AkGridColumn('Référence', 110),
        AkGridColumn('Libellé', 240, grow: true),
        AkGridColumn('Tiers', 90),
        AkGridColumn('Débit', 120, numeric: true),
        AkGridColumn('Crédit', 120, numeric: true),
        AkGridColumn('Solde', 130, numeric: true),
        AkGridColumn('Lettre', 70),
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
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Text(
                    h.code,
                    style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: AkSpace.s2),
                  Expanded(
                    child: Text(
                      h.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AkText.bodyStrong.copyWith(color: t.text),
                    ),
                  ),
                ],
              ),
            );
          case _LTotal tot:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Total compte', style: AkText.bodyStrong.copyWith(color: t.text)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AkAmountText('D ${Fmt.fcfa(tot.debit, showZero: true)}', bold: true),
                      AkAmountText('C ${Fmt.fcfa(tot.credit, showZero: true)}', bold: true),
                      AkAmountText('Solde ${Fmt.balance(tot.debit - tot.credit)}', bold: true),
                    ],
                  ),
                ],
              ),
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
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        Fmt.date(line.entryDate),
                        style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.body.copyWith(color: t.text),
                          ),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.code.copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AkSpace.s2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AkAmountText('${debit ? 'D' : 'C'} ${Fmt.fcfa(debit ? line.debit : line.credit)}', bold: true),
                        Text(
                          'Solde ${Fmt.balance(line.runningBalance)}',
                          style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  ],
                ),
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
        final grid = <AkGridRow>[];
        int? lastClass;
        for (final r in list) {
          final cls = r.accountCode.isEmpty ? null : int.tryParse(r.accountCode[0]);
          if (cls != null && cls != lastClass) {
            lastClass = cls;
            final label = _classLabel(cls);
            grid.add(AkGridRow.section(_sectionText(context, label.isEmpty ? 'Classe $cls' : 'Classe $cls · $label')));
          }
          final prev = prevByCode[r.accountCode];
          grid.add(
            AkGridRow([
              _codeTxt(context, r.accountCode),
              _txt(context, r.accountLabel),
              _amt(Fmt.fcfa(r.openingDebit)),
              _amt(Fmt.fcfa(r.openingCredit)),
              _amt(Fmt.fcfa(r.periodDebit)),
              _amt(Fmt.fcfa(r.periodCredit)),
              _amt(Fmt.fcfa(r.closingDebit)),
              _amt(Fmt.fcfa(r.closingCredit)),
              if (withPrev) _amt(Fmt.balance((prev?.closingDebit ?? 0) - (prev?.closingCredit ?? 0))),
            ]),
          );
        }
        grid.add(
          AkGridRow([
            const SizedBox.shrink(),
            _txt(context, 'Totaux', bold: true),
            _amt(Fmt.fcfa(t((r) => r.openingDebit), showZero: true), bold: true),
            _amt(Fmt.fcfa(t((r) => r.openingCredit), showZero: true), bold: true),
            _amt(Fmt.fcfa(t((r) => r.periodDebit), showZero: true), bold: true),
            _amt(Fmt.fcfa(t((r) => r.periodCredit), showZero: true), bold: true),
            _amt(Fmt.fcfa(t((r) => r.closingDebit), showZero: true), bold: true),
            _amt(Fmt.fcfa(t((r) => r.closingCredit), showZero: true), bold: true),
            if (withPrev) const SizedBox.shrink(),
          ], kind: AkGridRowKind.total),
        );
        return AkGrid(
          groups: [..._balanceGroups, if (withPrev) ('', 1)],
          columns: [
            const AkGridColumn('Compte', 110),
            const AkGridColumn('Intitulé', 260, grow: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            if (withPrev) const AkGridColumn('Solde N-1', 120, numeric: true),
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
        AkColumn<BalanceRow> code(String label, String Function(BalanceRow) f, double w) => AkColumn(label: label, width: w, cell: (c, r) => _codeTxt(c, f(r)));
        AkColumn<BalanceRow> amount(String label, int Function(BalanceRow) f) =>
            AkColumn(label: label, width: 112, numeric: true, cell: (c, r) => _amt(Fmt.fcfa(f(r))));
        return SingleChildScrollView(
          child: AkTable<BalanceRow>(
            bare: true,
            minWidth: 1100,
            rows: list,
            columns: [
              code('Collectif', (r) => r.accountCode, 100),
              code('Tiers', (r) => r.thirdPartyCode ?? '', 96),
              AkColumn(label: 'Nom', flex: 1, cell: (c, r) => _txt(c, r.thirdPartyName ?? '')),
              amount('Ouverture débit', (r) => r.openingDebit),
              amount('Ouverture crédit', (r) => r.openingCredit),
              amount('Mouvements débit', (r) => r.periodDebit),
              amount('Mouvements crédit', (r) => r.periodCredit),
              amount('Clôture débit', (r) => r.closingDebit),
              amount('Clôture crédit', (r) => r.closingCredit),
            ],
          ),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s3),
          child: Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AkSegmented<String>(
                options: const [AkOption('debit', 'Clients (débiteurs)'), AkOption('credit', 'Fournisseurs (créditeurs)')],
                selected: side,
                onChanged: onSide,
              ),
              Text('À la date du ${Fmt.date(params.to)} · lignes non lettrées', style: AkText.caption.copyWith(color: t.textMuted)),
            ],
          ),
        ),
        Divider(height: 1, color: t.border),
        Expanded(
          child: AsyncView(
            value: rows,
            onRetry: () => ref.invalidate(agedBalanceProvider(params)),
            builder: (list) {
              if (list.isEmpty) return const AkEmptyState('Aucune ligne non lettrée à cette date.');
              AkColumn<AgedRow> amount(String label, int Function(AgedRow) f, {double w = 110, bool bold = false}) => AkColumn(
                label: label,
                width: w,
                numeric: true,
                cell: (c, r) => _amt(Fmt.fcfa(f(r), showZero: bold), bold: bold),
              );
              return SingleChildScrollView(
                child: AkTable<AgedRow>(
                  bare: true,
                  minWidth: 960,
                  rows: list,
                  columns: [
                    AkColumn(label: 'Compte', width: 100, cell: (c, r) => _codeTxt(c, r.accountCode)),
                    AkColumn(label: 'Tiers', width: 96, cell: (c, r) => _codeTxt(c, r.thirdPartyCode)),
                    AkColumn(label: 'Nom', flex: 1, cell: (c, r) => _txt(c, r.thirdPartyName)),
                    amount('0-30 j', (r) => r.d0_30),
                    amount('31-60 j', (r) => r.d31_60),
                    amount('61-90 j', (r) => r.d61_90),
                    amount('91-180 j', (r) => r.d91_180),
                    amount('> 180 j', (r) => r.over180),
                    amount('Total', (r) => r.total, w: 130, bold: true),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
      return Padding(
        padding: const EdgeInsets.all(AkSpace.s4),
        child: Align(
          alignment: Alignment.topLeft,
          child: AkBanner(kind: AkBannerKind.warning, child: const Text('Aucun exercice ne contient la date de début.')),
        ),
      );
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
        final grid = <AkGridRow>[];
        for (final e in byJournal.entries) {
          final label = journals.where((j) => j.code == e.key).firstOrNull?.label ?? e.value.first.journalLabel;
          grid.add(
            AkGridRow.section(
              Row(
                children: [
                  _codeTxt(context, e.key, bold: true),
                  const SizedBox(width: AkSpace.s2),
                  Flexible(child: _sectionText(context, '— $label')),
                ],
              ),
            ),
          );
          for (final r in e.value) {
            grid.add(
              AkGridRow([
                _txt(context, Fmt.month(r.monthStart)),
                _txt(context, '${r.entriesCount} écr.', muted: true),
                _amt(Fmt.fcfa(r.totalDebit, showZero: true)),
                _amt(Fmt.fcfa(r.totalCredit, showZero: true)),
              ]),
            );
          }
          grid.add(
            AkGridRow([
              _txt(context, 'Total journal', bold: true),
              const SizedBox.shrink(),
              _amt(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalDebit), showZero: true), bold: true),
              _amt(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalCredit), showZero: true), bold: true),
            ], kind: AkGridRowKind.total),
          );
        }
        return AkGrid(
          columns: const [AkGridColumn('Mois', 200, grow: true), AkGridColumn('Écritures', 100), AkGridColumn('Débit', 140, numeric: true), AkGridColumn('Crédit', 140, numeric: true)],
          rows: grid,
        );
      },
    );
  }
}
