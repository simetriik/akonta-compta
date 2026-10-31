import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import 'statement_notes_section.dart';
import '../../application/providers/entities_providers.dart';
import '../../domain/closing_models.dart';
import '../../domain/consultation_models.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';
import '../widgets/save_export.dart';
import '../../application/providers/closing_providers.dart';

class StatementsStep extends ConsumerStatefulWidget {
  const StatementsStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<StatementsStep> createState() => _StatementsStepState();
}

class _StatementsStepState extends ConsumerState<StatementsStep> {
  /// États que l'on vient de générer ; à défaut, les derniers enregistrés pour l'exercice.
  FinancialStatements? _generated;
  bool _busy = false;

  Future<void> _export(BuildContext context, String kind, String format) async {
    setState(() => _busy = true);
    try {
      final p = ConsultationParams(entityId: widget.entity.id, from: widget.fy.startDate, to: widget.fy.endDate);
      final (name, bytes) = await ref.read(consultationServiceProvider).export(p: p, kind: kind, format: format);
      await saveExportedFile(dialogTitle: 'Enregistrer', fileName: name, bytes: bytes);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final saved = ref.watch(latestStatementsProvider(widget.fy.id));
    if (saved.hasError && _generated == null) return AkErrorMessage(errorText(saved.error!));
    if (saved.isLoading && _generated == null) return const AkLoading();
    final fs = _generated ?? saved.value;
    final nonProfit = ref.watch(entityProvider(widget.entity.id)).value?.accountingSystem == 'sycebnl';
    return ListView(
      padding: closingBodyPadding(context),
      children: [
        Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              nonProfit ? 'États financiers SYCEBNL (entités à but non lucratif)' : 'États financiers SYSCOHADA (système normal)',
              style: AkText.heading.copyWith(color: t.text),
            ),
            AkButton.primary(
              'Générer les états',
              icon: Icons.auto_awesome,
              loading: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                try {
                  final v = await ref.read(closingServiceProvider).generateStatements(widget.entity.id, widget.fy.id);
                  setState(() => _generated = v);
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, errorText(e));
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s3),
        if (fs == null) const AkBanner(kind: AkBannerKind.info, child: Text('Aucun état généré pour cet exercice.')),
        if (fs != null) ...[
          AkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Généré le ${Fmt.date(fs.generatedAt)}${fs.isFinal ? ' · arrêté' : ''}', style: AkText.bodyStrong.copyWith(color: t.text)),
                const SizedBox(height: AkSpace.s2),
                for (final c in fs.checks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                    child: Row(
                      children: [
                        Icon(
                          (c['passed'] as bool?) == true ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: (c['passed'] as bool?) == true ? t.success : t.danger,
                        ),
                        const SizedBox(width: AkSpace.s2),
                        Expanded(
                          child: Text('${c['label']}', style: AkText.table.copyWith(color: t.text)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AkSpace.s3),
                if (nonProfit) ...[
                  AkButton.secondary(
                    'États financiers SYCEBNL PDF',
                    key: const Key('export-sycebnl-pdf'),
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () => _export(context, 'financial_statements', 'pdf'),
                  ),
                  const SizedBox(height: AkSpace.s2),
                  Text(
                    'Un seul PDF : bilan, compte de résultat, tableau des flux de trésorerie et notes annexes calculables. Export Excel : à venir.',
                    key: const Key('sycebnl-statements-notice'),
                    style: AkText.caption.copyWith(color: t.textMuted),
                  ),
                ] else ...[
                  Wrap(
                    spacing: AkSpace.s2,
                    runSpacing: AkSpace.s2,
                    children: [
                      AkButton.secondary(
                        'États financiers PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: () => _export(context, 'financial_statements', 'pdf'),
                      ),
                      AkButton.secondary(
                        'Liasse DGI (Excel, macros conservées)',
                        icon: Icons.table_view_outlined,
                        onPressed: () => _export(context, 'dgi', 'xlsm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s2),
                  Text(
                    'La liasse DGI reprend fiche R1/R2, bilan et compte de résultat (N et N-1) ; TFT et notes se complètent dans le classeur.',
                    style: AkText.caption.copyWith(color: t.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          _PostsTable(title: 'Bilan — Actif', posts: fs.assets, previous: fs.previous?['assets']),
          const SizedBox(height: AkSpace.s3),
          _PostsTable(title: 'Bilan — Passif', posts: fs.liabilities, previous: fs.previous?['liabilities']),
          const SizedBox(height: AkSpace.s3),
          _PostsTable(title: 'Compte de résultat', posts: fs.income, previous: fs.previous?['income']),
          if (fs.cashFlow.isNotEmpty) ...[const SizedBox(height: AkSpace.s3), _CashFlowTable(posts: fs.cashFlow, previous: fs.previous?['cash_flow'])],
          if (fs.notes.isNotEmpty) ...[const SizedBox(height: AkSpace.s3), StatementNotesSection(notes: fs.notes)],
        ],
      ],
    );
  }
}

class _PostsTable extends StatelessWidget {
  const _PostsTable({required this.title, required this.posts, this.previous});

  final String title;
  final List<StatementPost> posts;
  final List<StatementPost>? previous;

  @override
  Widget build(BuildContext context) {
    final prev = {for (final p in previous ?? const <StatementPost>[]) '${p.code}/${p.columnRole}': p.amount};
    final byCode = <String, Map<String, dynamic>>{};
    for (final p in posts) {
      final e = byCode.putIfAbsent(p.code, () => {'label': p.label, 'gross': 0, 'dep': 0, 'amount': 0});
      if (p.columnRole == 'gross') {
        e['gross'] = p.amount;
      } else if (p.columnRole == 'depreciation') {
        e['dep'] = p.amount;
      } else {
        e['amount'] = p.amount;
      }
    }
    final hasGross = posts.any((p) => p.columnRole == 'gross');
    final hasPrevious = previous != null;
    final t = context.ak;
    int gross(Map<String, dynamic> e) => e['gross'] as int;
    int dep(Map<String, dynamic> e) => e['dep'] as int;
    int net(Map<String, dynamic> e) => hasGross ? gross(e) - dep(e) : e['amount'] as int;
    final netTotal = Fmt.fcfa(byCode.values.fold<int>(0, (s, e) => s + net(e)), showZero: true);
    AkColumn<MapEntry<String, Map<String, dynamic>>> amountColumn(
      String label,
      int Function(MapEntry<String, Map<String, dynamic>>) value, {
      bool bold = false,
      bool muted = false,
      bool showZero = false,
      String? footer,
    }) => AkColumn(
      label: label,
      width: 130,
      numeric: true,
      footer: footer,
      cell: (_, e) => AkAmountText(
        Fmt.fcfa(value(e), showZero: showZero),
        bold: bold,
        color: muted ? t.textMuted : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkSectionTitle(title),
        const SizedBox(height: AkSpace.s2),
        AkTable<MapEntry<String, Map<String, dynamic>>>(
          minWidth: 560,
          rows: byCode.entries.toList(),
          footerLabel: 'Total',
          columns: [
            AkColumn.text(label: 'Code', width: 56, text: (e) => e.key),
            AkColumn.text(label: 'Libellé', text: (e) => e.value['label'] as String),
            if (hasGross) ...[
              amountColumn('Brut', (e) => gross(e.value)),
              amountColumn('Amortissements', (e) => dep(e.value)),
              amountColumn('Net', (e) => net(e.value), bold: true, showZero: true, footer: netTotal),
            ] else
              amountColumn('Montant', (e) => net(e.value), bold: true, showZero: true, footer: netTotal),
            if (hasPrevious) amountColumn('Exercice précédent', (e) => prev['${e.key}/${hasGross ? 'gross' : 'amount'}'] ?? 0, muted: true),
          ],
        ),
      ],
    );
  }
}

/// Tableau des flux de trésorerie : montants signés (encaissement +, décaissement -), totaux en gras, sans total de pied.
class _CashFlowTable extends StatelessWidget {
  const _CashFlowTable({required this.posts, this.previous});

  final List<StatementPost> posts;
  final List<StatementPost>? previous;

  bool _isTotal(StatementPost p) => p.code.startsWith('Z');

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final prev = {for (final p in previous ?? const <StatementPost>[]) p.code: p.amount};
    return Column(
      key: const Key('cash-flow-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AkSectionTitle('Tableau des flux de trésorerie'),
        const SizedBox(height: AkSpace.s2),
        AkTable<StatementPost>(
          minWidth: 560,
          rows: posts,
          columns: [
            AkColumn.text(label: 'Code', width: 56, text: (p) => p.code),
            AkColumn(
              label: 'Libellé',
              cell: (_, p) => Text(p.label, style: (_isTotal(p) ? AkText.bodyStrong : AkText.table).copyWith(color: t.text)),
            ),
            AkColumn(
              label: 'Exercice',
              width: 130,
              numeric: true,
              cell: (_, p) => AkAmountText(Fmt.fcfa(p.amount, showZero: _isTotal(p)), bold: _isTotal(p)),
            ),
            if (previous != null)
              AkColumn(
                label: 'Exercice précédent',
                width: 130,
                numeric: true,
                cell: (_, p) => AkAmountText(Fmt.fcfa(prev[p.code] ?? 0, showZero: _isTotal(p)), color: t.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}
