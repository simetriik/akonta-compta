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
    return Column(children: [
      Material(
        color: Colors.white,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 120, child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'Du'), onSubmitted: (_) => setState(() {}))),
              SizedBox(width: 120, child: TextField(controller: _to, decoration: const InputDecoration(labelText: 'Au'), onSubmitted: (_) => setState(() {}))),
              SizedBox(width: 120, child: TextField(controller: _accountFrom, decoration: const InputDecoration(labelText: 'Compte de'), onSubmitted: (_) => setState(() {}))),
              SizedBox(width: 120, child: TextField(controller: _accountTo, decoration: const InputDecoration(labelText: 'à'), onSubmitted: (_) => setState(() {}))),
              DropdownButton<int?>(value: _classNo, hint: const Text('Classe'), items: [const DropdownMenuItem(value: null, child: Text('Toutes classes')), for (var c = 1; c <= 8; c++) DropdownMenuItem(value: c, child: Text('Classe $c'))], onChanged: (v) => setState(() => _classNo = v)),
              FilterChip(label: const Text('Comparer N-1'), selected: _compare, onSelected: (v) => setState(() => _compare = v)),
              FilledButton.tonal(onPressed: () => setState(() {}), child: const Text('Actualiser')),
              const SizedBox(width: 8),
              if (_exporting) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              if (!_exporting) PopupMenuButton<String>(
                tooltip: 'Exporter',
                icon: const Icon(Icons.download_outlined),
                onSelected: (v) => _export(v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'trial_balance:pdf', child: Text('Balance — PDF')),
                  PopupMenuItem(value: 'trial_balance:xlsx', child: Text('Balance — Excel')),
                  PopupMenuItem(value: 'general_ledger:pdf', child: Text('Grand livre — PDF')),
                  PopupMenuItem(value: 'general_ledger:xlsx', child: Text('Grand livre — Excel')),
                  PopupMenuItem(value: 'aged_balance:pdf', child: Text('Balance âgée — PDF')),
                ],
              ),
            ]),
          ),
          TabBar(controller: _tabs, isScrollable: true, tabs: const [Tab(text: 'Grand livre'), Tab(text: 'Balance générale'), Tab(text: 'Balance auxiliaire'), Tab(text: 'Balance âgée'), Tab(text: 'Centralisateur')]),
        ]),
      ),
      Expanded(
        child: p == null
            ? const Center(child: Text('Dates invalides (jj/mm/aaaa).'))
            : TabBarView(controller: _tabs, children: [
                _LedgerTab(params: p),
                _BalanceTab(params: p, previous: _compare ? _previousYear(p) : null),
                _AuxiliaryTab(params: p),
                _AgedTab(params: p, side: _side, onSide: (s) => setState(() => _side = s)),
                _CentralizationTab(params: p),
              ]),
      ),
    ]);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AkColors.toCorrect));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

TextStyle get _mono => const TextStyle(fontFamily: 'monospace', fontSize: 12);

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
        if (list.isEmpty) return const Center(child: Text('Aucune écriture validée sur la période.'));
        final widgets = <Widget>[];
        String? current;
        var subD = 0, subC = 0;
        void flush() {
          if (current != null) {
            widgets.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [const Spacer(), Text('Total compte : D ${Fmt.fcfa(subD, showZero: true)} · C ${Fmt.fcfa(subC, showZero: true)} · solde ${Fmt.fcfa(subD - subC, showZero: true)}', style: const TextStyle(fontWeight: FontWeight.w600))])));
          }
          subD = 0;
          subC = 0;
        }
        for (final l in list) {
          if (l.accountCode != current) {
            flush();
            current = l.accountCode;
            widgets.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text('${l.accountCode} — ${l.accountLabel}', style: const TextStyle(fontWeight: FontWeight.bold))));
          }
          subD += l.debit;
          subC += l.credit;
          widgets.add(InkWell(
            onTap: () => context.go('/saisie/${l.entryId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 90, child: Text(Fmt.date(l.entryDate), style: _mono)),
                SizedBox(width: 80, child: Text('${l.journalCode}-${l.number}', style: _mono)),
                SizedBox(width: 90, child: Text(l.reference ?? '', style: _mono, overflow: TextOverflow.ellipsis)),
                Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 70, child: Text(l.thirdPartyCode ?? '', style: _mono)),
                SizedBox(width: 110, child: Text(Fmt.fcfa(l.debit), textAlign: TextAlign.right, style: _mono)),
                SizedBox(width: 110, child: Text(Fmt.fcfa(l.credit), textAlign: TextAlign.right, style: _mono)),
                SizedBox(width: 120, child: Text(Fmt.fcfa(l.runningBalance, showZero: true), textAlign: TextAlign.right, style: _mono)),
                SizedBox(width: 30, child: Text(l.letterCode ?? '', style: _mono)),
              ]),
            ),
          ));
        }
        flush();
        return ListView(padding: const EdgeInsets.all(16), children: widgets);
      },
    );
  }
}

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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AkColors.sand),
              columnSpacing: 16,
              columns: [
                const DataColumn(label: Text('Compte')),
                const DataColumn(label: Text('Intitulé')),
                const DataColumn(label: Text('Ouverture D'), numeric: true),
                const DataColumn(label: Text('Ouverture C'), numeric: true),
                const DataColumn(label: Text('Mouvements D'), numeric: true),
                const DataColumn(label: Text('Mouvements C'), numeric: true),
                const DataColumn(label: Text('Solde D'), numeric: true),
                const DataColumn(label: Text('Solde C'), numeric: true),
                if (previous != null) const DataColumn(label: Text('Solde N-1'), numeric: true),
              ],
              rows: [
                for (final r in list)
                  DataRow(cells: [
                    DataCell(Text(r.accountCode, style: _mono)),
                    DataCell(SizedBox(width: 260, child: Text(r.accountLabel, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(Fmt.fcfa(r.openingDebit), style: _mono)),
                    DataCell(Text(Fmt.fcfa(r.openingCredit), style: _mono)),
                    DataCell(Text(Fmt.fcfa(r.periodDebit), style: _mono)),
                    DataCell(Text(Fmt.fcfa(r.periodCredit), style: _mono)),
                    DataCell(Text(Fmt.fcfa(r.closingDebit), style: _mono)),
                    DataCell(Text(Fmt.fcfa(r.closingCredit), style: _mono)),
                    if (previous != null) DataCell(Text(Fmt.fcfa((prevByCode[r.accountCode]?.closingDebit ?? 0) - (prevByCode[r.accountCode]?.closingCredit ?? 0), showZero: true), style: _mono)),
                  ]),
                DataRow(color: WidgetStateProperty.all(AkColors.sand), cells: [
                  const DataCell(Text('')),
                  const DataCell(Text('Totaux', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(Fmt.fcfa(t((r) => r.openingDebit), showZero: true), style: _mono)),
                  DataCell(Text(Fmt.fcfa(t((r) => r.openingCredit), showZero: true), style: _mono)),
                  DataCell(Text(Fmt.fcfa(t((r) => r.periodDebit), showZero: true), style: _mono)),
                  DataCell(Text(Fmt.fcfa(t((r) => r.periodCredit), showZero: true), style: _mono)),
                  DataCell(Text(Fmt.fcfa(t((r) => r.closingDebit), showZero: true), style: _mono)),
                  DataCell(Text(Fmt.fcfa(t((r) => r.closingCredit), showZero: true), style: _mono)),
                  if (previous != null) const DataCell(Text('')),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuxiliaryTab extends ConsumerWidget {
  const _AuxiliaryTab({required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(auxiliaryBalanceProvider(params));
    return AsyncView(
      value: rows,
      builder: (list) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AkColors.sand),
            columnSpacing: 16,
            columns: const [DataColumn(label: Text('Collectif')), DataColumn(label: Text('Tiers')), DataColumn(label: Text('Nom')), DataColumn(label: Text('Ouverture D'), numeric: true), DataColumn(label: Text('Ouverture C'), numeric: true), DataColumn(label: Text('Mouvements D'), numeric: true), DataColumn(label: Text('Mouvements C'), numeric: true), DataColumn(label: Text('Solde D'), numeric: true), DataColumn(label: Text('Solde C'), numeric: true)],
            rows: [
              for (final r in list)
                DataRow(cells: [
                  DataCell(Text(r.accountCode, style: _mono)),
                  DataCell(Text(r.thirdPartyCode ?? '', style: _mono)),
                  DataCell(SizedBox(width: 220, child: Text(r.thirdPartyName ?? '', overflow: TextOverflow.ellipsis))),
                  DataCell(Text(Fmt.fcfa(r.openingDebit), style: _mono)),
                  DataCell(Text(Fmt.fcfa(r.openingCredit), style: _mono)),
                  DataCell(Text(Fmt.fcfa(r.periodDebit), style: _mono)),
                  DataCell(Text(Fmt.fcfa(r.periodCredit), style: _mono)),
                  DataCell(Text(Fmt.fcfa(r.closingDebit), style: _mono)),
                  DataCell(Text(Fmt.fcfa(r.closingCredit), style: _mono)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgedTab extends ConsumerWidget {
  const _AgedTab({required this.params, required this.side, required this.onSide});

  final ConsultationParams params;
  final String side;
  final ValueChanged<String> onSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(agedBalanceProvider(params));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'debit', label: Text('Clients (débiteurs)')), ButtonSegment(value: 'credit', label: Text('Fournisseurs (créditeurs)'))], selected: {side}, onSelectionChanged: (s) => onSide(s.first)),
          const SizedBox(width: 12),
          Text('À la date du ${Fmt.date(params.to)} · lignes non lettrées'),
        ]),
      ),
      Expanded(
        child: AsyncView(
          value: rows,
          builder: (list) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AkColors.sand),
                columnSpacing: 16,
                columns: const [DataColumn(label: Text('Compte')), DataColumn(label: Text('Tiers')), DataColumn(label: Text('Nom')), DataColumn(label: Text('0-30 j'), numeric: true), DataColumn(label: Text('31-60 j'), numeric: true), DataColumn(label: Text('61-90 j'), numeric: true), DataColumn(label: Text('91-180 j'), numeric: true), DataColumn(label: Text('> 180 j'), numeric: true), DataColumn(label: Text('Total'), numeric: true)],
                rows: [
                  for (final r in list)
                    DataRow(cells: [
                      DataCell(Text(r.accountCode, style: _mono)),
                      DataCell(Text(r.thirdPartyCode, style: _mono)),
                      DataCell(SizedBox(width: 200, child: Text(r.thirdPartyName, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(Fmt.fcfa(r.d0_30), style: _mono)),
                      DataCell(Text(Fmt.fcfa(r.d31_60), style: _mono)),
                      DataCell(Text(Fmt.fcfa(r.d61_90), style: _mono)),
                      DataCell(Text(Fmt.fcfa(r.d91_180), style: _mono)),
                      DataCell(Text(Fmt.fcfa(r.over180), style: _mono)),
                      DataCell(Text(Fmt.fcfa(r.total, showZero: true), style: _mono.copyWith(fontWeight: FontWeight.bold))),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _CentralizationTab extends ConsumerWidget {
  const _CentralizationTab({required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (params.fiscalYearId == null) return const Center(child: Text('Aucun exercice ne contient la date de début.'));
    final rows = ref.watch(centralizationProvider(params));
    final journals = ref.watch(journalsProvider(params.entityId)).value ?? const [];
    return AsyncView(
      value: rows,
      builder: (list) {
        final byJournal = <String, List<CentralizationRow>>{};
        for (final r in list) {
          byJournal.putIfAbsent(r.journalCode, () => []).add(r);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in byJournal.entries)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.key} — ${journals.where((j) => j.code == e.key).firstOrNull?.label ?? e.value.first.journalLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    for (final r in e.value)
                      Row(children: [
                        SizedBox(width: 160, child: Text(Fmt.month(r.monthStart))),
                        SizedBox(width: 90, child: Text('${r.entriesCount} écr.')),
                        SizedBox(width: 130, child: Text(Fmt.fcfa(r.totalDebit, showZero: true), textAlign: TextAlign.right, style: _mono)),
                        SizedBox(width: 130, child: Text(Fmt.fcfa(r.totalCredit, showZero: true), textAlign: TextAlign.right, style: _mono)),
                      ]),
                    const Divider(),
                    Row(children: [
                      const SizedBox(width: 160, child: Text('Total journal', style: TextStyle(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 90),
                      SizedBox(width: 130, child: Text(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalDebit), showZero: true), textAlign: TextAlign.right, style: _mono)),
                      SizedBox(width: 130, child: Text(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalCredit), showZero: true), textAlign: TextAlign.right, style: _mono)),
                    ]),
                  ]),
                ),
              ),
            if (list.isEmpty) const Text('Aucune écriture validée sur cet exercice.'),
          ],
        );
      },
    );
  }
}
