
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/bank_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/reconciliation_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../core/text_decoding.dart';
import '../../domain/consultation_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'entry_from_line_dialog.dart';
import 'reconciliation_state_bar.dart';
import 'reconciliation_template_dialog.dart';
import 'statement_params_dialog.dart';
import '../../application/providers/reconciliation_controller.dart';
import '../../application/rules/account_selection.dart';
import '../widgets/save_export.dart';

/// Rapprochement bancaire (§10.7) : import du relevé selon un gabarit mémorisé, deux volets relevé / comptabilité,
/// propositions, pointage 1-1 ou n-n, état mensuel, écriture depuis une ligne, état figé et archivé en PDF.
class ReconciliationScreen extends StatelessWidget {
  const ReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _ReconciliationBody(entity: entity));
}

class _ReconciliationBody extends ConsumerStatefulWidget {
  const _ReconciliationBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_ReconciliationBody> createState() => _ReconciliationBodyState();
}

class _ReconciliationBodyState extends ConsumerState<_ReconciliationBody> {
  late final _asOf = TextEditingController(text: Fmt.date(ref.read(reconciliationControllerProvider).until));

  bool _exporting = false;

  ReconciliationController get _c => ref.read(reconciliationControllerProvider.notifier);

  /// Exécute une action du contrôleur et affiche l'erreur éventuelle.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(reconciliationControllerProvider);
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const <Journal>[]).where((j) => j.isTreasury && j.isActive).toList();
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final can = perms.has('reconciliation.manage', entityId: widget.entity.id);
    final st = v.state;
    final t = context.ak;
    final selectedLabel = v.selBank.isEmpty && v.selBook.isEmpty
        ? 'Pointer'
        : 'Pointer (${Fmt.fcfa(v.selBankNet, showZero: true)} ↔ ${Fmt.fcfa(v.selBookNet, showZero: true)})';
    final subtitle = v.journal == null ? null : '${v.journal!.treasuryAccountCode} ${v.journal!.label} · ${Fmt.month(v.until)}';
    return AkPage(
      children: [
        AkPageHead(
          title: 'Rapprochement bancaire',
          subtitle: subtitle,
          actions: [
            if (can && v.journal != null)
              AkButton.secondary(
                'Importer un relevé',
                key: const Key('import-statement'),
                icon: Icons.upload_file_outlined,
                onPressed: v.busy ? null : _importStatement,
              ),
            if (v.journal != null) AkButton.secondary('État PDF', icon: Icons.picture_as_pdf_outlined, onPressed: v.busy || _exporting ? null : _exportPdf),
            if (can && v.journal != null)
              AkButton.primary(
                'Figer l\'état du mois',
                key: const Key('finalize-recon'),
                onPressed: v.busy || st == null || st.difference != 0 ? null : _finalize,
              ),
          ],
        ),
        const SizedBox(height: AkSpace.s4),
        Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 260,
              child: AkDropdown<String>(
                key: const Key('recon-journal'),
                label: 'Journal de trésorerie',
                value: v.journal?.id,
                items: [for (final j in journals) AkOption(j.id, '${j.code} · ${j.label} (${j.treasuryAccountCode})')],
                onChanged: (id) => _guard(() => _c.setJournal(journals.where((j) => j.id == id).firstOrNull)),
              ),
            ),
            SizedBox(
              width: 160,
              child: AkDateField(
                controller: _asOf,
                label: 'État au',
                onChanged: (d) {
                  if (d != null) _guard(() => _c.setUntil(d));
                },
              ),
            ),
            if (can && v.journal != null)
              AkButton.primary(
                selectedLabel,
                key: const Key('match-selected'),
                icon: Icons.link,
                onPressed: v.busy || !v.canMatch ? null : () => _guard(_c.matchSelected),
              ),
            if (v.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: AkSpace.s2),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        if (st != null) ...[const SizedBox(height: AkSpace.s4), ReconciliationStateBar(state: st)],
        if (v.proposals.isNotEmpty && can) ...[
          const SizedBox(height: AkSpace.s4),
          AkBanner(
            kind: AkBannerKind.info,
            icon: Icons.auto_awesome,
            action: Wrap(
              spacing: AkSpace.s2,
              children: [
                AkButton.ghost('Sélectionner la première', dense: true, onPressed: _c.selectFirstProposal),
                AkButton.secondary('Tout accepter', dense: true, icon: Icons.done_all, onPressed: v.busy ? null : _acceptAllProposals),
              ],
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${v.proposals.length} proposition(s) de pointage', style: AkText.bodyStrong),
                  const TextSpan(text: ' (montant identique, ± 5 jours)'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AkSpace.s4),
        if (v.journal == null)
          const AkBanner(kind: AkBannerKind.info, child: Text('Choisissez un journal de banque ou de caisse.'))
        else
          LayoutBuilder(
            builder: (context, c) {
              final bankPane = _pane<StatementLine>(
                'Relevé bancaire non pointé (${v.bank.length})',
                v.bank,
                selected: (l) => v.selBank.contains(l.id),
                toggle: !can ? null : (l) => _c.toggleBank(l.id),
                columns: [
                  AkColumn<StatementLine>.text(label: 'Date', width: 84, text: (l) => Fmt.date(l.date)),
                  AkColumn<StatementLine>.text(label: 'Libellé', text: (l) => l.label),
                  AkColumn<StatementLine>(
                    label: '',
                    width: 110,
                    cell: (context, l) => v.proposals.any((p) => p.statementLineId == l.id)
                        ? AkBadge(label: 'Proposée', color: t.info, tint: t.infoTint, icon: Icons.auto_awesome)
                        : const SizedBox.shrink(),
                  ),
                  AkColumn<StatementLine>(
                    label: 'Montant',
                    width: 110,
                    numeric: true,
                    cell: (context, l) =>
                        AkAmountText(l.debit > 0 ? '-${Fmt.fcfa(l.debit)}' : '+${Fmt.fcfa(l.credit)}', color: l.debit > 0 ? t.danger : t.success),
                  ),
                  if (can)
                    AkColumn<StatementLine>(
                      label: '',
                      width: 40,
                      cell: (context, l) =>
                          AkIconButton(icon: Icons.add_circle_outline, tooltip: 'Créer l\'écriture', dense: true, onPressed: () => _createEntry(l)),
                    ),
                ],
              );
              final bookPane = _pane<BookLine>(
                'Comptabilité non pointée (${v.book.length})',
                v.book,
                selected: (l) => v.selBook.contains(l.id),
                toggle: !can ? null : (l) => _c.toggleBook(l.id),
                columns: [
                  AkColumn<BookLine>.text(label: 'Date', width: 84, text: (l) => Fmt.date(l.date)),
                  AkColumn<BookLine>(
                    label: 'N°',
                    width: 60,
                    cell: (context, l) => Text('${l.number}', style: AkText.code.copyWith(color: t.text)),
                  ),
                  AkColumn<BookLine>.text(label: 'Libellé', text: (l) => l.label),
                  AkColumn<BookLine>(
                    label: 'Montant',
                    width: 110,
                    numeric: true,
                    cell: (context, l) =>
                        AkAmountText(l.debit > 0 ? '+${Fmt.fcfa(l.debit)}' : '-${Fmt.fcfa(l.credit)}', color: l.debit > 0 ? t.success : t.danger),
                  ),
                ],
              );
              if (c.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: bankPane),
                    const SizedBox(width: AkSpace.s4),
                    Expanded(child: bookPane),
                  ],
                );
              }
              return Column(
                children: [
                  bankPane,
                  const SizedBox(height: AkSpace.s3),
                  bookPane,
                ],
              );
            },
          ),
        if (v.journal != null) ...[
          const SizedBox(height: AkSpace.s3),
          Text(
            'Pointage 1-1 ou plusieurs-à-plusieurs : sélectionnez des lignes des deux côtés puis « Pointer ». Les montants sont vus côté banque à gauche, côté entreprise à droite.',
            style: AkText.caption.copyWith(color: t.textMuted),
          ),
        ],
      ],
    );
  }

  /// Volet pointable : titre puis tableau avec case à cocher en première colonne ; fond teinté quand la ligne est sélectionnée.
  Widget _pane<R>(String title, List<R> rows, {required bool Function(R) selected, required void Function(R)? toggle, required List<AkColumn<R>> columns}) {
    final t = context.ak;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s2),
          child: AkSectionTitle(title),
        ),
        AkTable<R>(
          rows: rows,
          minWidth: 480,
          emptyMessage: 'Rien à pointer.',
          onRowTap: toggle,
          rowColor: (r) => selected(r) ? t.rowSelected : null,
          columns: [
            AkColumn<R>(
              label: '',
              width: 40,
              cell: (context, r) => AkCheckbox(dense: true, value: selected(r), onChanged: toggle == null ? null : (_) => toggle(r)),
            ),
            ...columns,
          ],
        ),
      ],
    );
  }

  Future<void> _acceptAllProposals() => _guard(() async {
    final n = await _c.acceptAllProposals();
    if (mounted) showAkToast(context, '$n pointage(s) effectué(s).');
  });

  Future<void> _createEntry(StatementLine l) async {
    // Listes attendues (et non lues en cache) : l'écran peut être ouvert sans passage préalable par un module qui les charge.
    final accounts = AccountSelection.statementCounterparts(await ref.read(accountsProvider(widget.entity.id).future));
    final thirdParties = await ref.read(thirdPartiesProvider(widget.entity.id).future);
    if (!mounted) return;
    final result = await showDialog<(Account, ThirdParty?, String, DateTime)>(
      context: context,
      builder: (_) => EntryFromLineDialog(line: l, accounts: accounts, thirdParties: thirdParties),
    );
    if (result == null) return;
    await _guard(() async {
      await _c.createEntryFromLine(l.id, accountId: result.$1.id, thirdPartyId: result.$2?.id, label: result.$3, entryDate: result.$4);
      ref.invalidate(entityDashboardProvider);
    });
  }

  Future<void> _importStatement() async {
    final journal = ref.read(reconciliationControllerProvider).journal!;
    final templates = await ref.read(statementTemplatesProvider.future);
    if (!mounted) return;
    final template = await showDialog<StatementTemplate>(
      context: context,
      builder: (_) => ReconciliationTemplateDialog(templates: templates, bankName: journal.label),
    );
    if (template == null) return;
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt', 'tsv']);
    if (picked.isEmpty) return;
    final file = picked.first;
    final text = decodePerfectoText(await file.readAsBytes());
    final parsed = parseStatementCsv(text, template);
    if (!mounted) return;
    if (parsed.lines.isEmpty) {
      showErrorSnack(context, 'Aucune ligne lue. ${parsed.errors.take(3).join(' · ')}');
      return;
    }
    final dates = parsed.lines.map((l) => l.date).toList()..sort();
    final params = await showDialog<(DateTime, DateTime, int?, int?)>(
      context: context,
      builder: (_) => StatementParamsDialog(from: dates.first, to: dates.last, count: parsed.lines.length, errors: parsed.errors),
    );
    if (params == null) return;
    await _guard(() async {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await _c.importStatement(
        cabinetId: cabinet!.id,
        template: template,
        lines: parsed.lines,
        from: params.$1,
        to: params.$2,
        opening: params.$3,
        closing: params.$4,
        fileName: file.name,
      );
      if (mounted) showAkToast(context, '${parsed.lines.length} lignes de relevé importées.');
    });
  }

  Future<void> _finalize() => _guard(() async {
    await _c.finalizeMonth();
    if (mounted) showAkToast(context, 'État de rapprochement figé. Exportez le PDF pour l\'archiver.');
  });

  Future<void> _exportPdf() async {
    final v = ref.read(reconciliationControllerProvider);
    setState(() => _exporting = true);
    try {
      final p = ConsultationParams(entityId: widget.entity.id, from: DateTime(v.until.year, v.until.month, 1), to: v.until, journalId: v.journal!.id);
      final (name, bytes) = await ref.read(consultationServiceProvider).export(p: p, kind: 'reconciliation', format: 'pdf');
      await saveExportedFile(dialogTitle: 'Enregistrer l\'état de rapprochement', fileName: name, bytes: bytes);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
