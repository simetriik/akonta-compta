import 'dart:io';

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
  Journal? _journal;
  late final _asOf = TextEditingController(text: Fmt.date(DateTime(DateTime.now().year, DateTime.now().month + 1, 0)));
  List<StatementLine> _bank = const [];
  List<BookLine> _book = const [];
  List<ReconciliationProposalModel> _proposals = const [];
  ReconciliationStateModel? _state;
  final Set<int> _selBank = {};
  final Set<String> _selBook = {};
  bool _busy = false;

  DateTime get _until => Fmt.parseDate(_asOf.text) ?? DateTime.now();

  Future<void> _load() async {
    final j = _journal;
    if (j == null) return;
    setState(() => _busy = true);
    final repo = ref.read(reconciliationServiceProvider);
    try {
      final bank = await repo.unmatchedStatementLines(j.id, until: _until);
      final book = await repo.unmatchedBookLines(j.id, until: _until);
      final proposals = await repo.proposals(j.id, until: _until);
      final state = await repo.state(j.id, _until);
      if (!mounted) return;
      setState(() {
        _bank = bank;
        _book = book;
        _proposals = proposals;
        _state = state;
        _selBank.clear();
        _selBook.clear();
      });
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _selBankNet => _bank.where((l) => _selBank.contains(l.id)).fold(0, (s, l) => s + l.net);
  int get _selBookNet => _book.where((l) => _selBook.contains(l.id)).fold(0, (s, l) => s + l.net);

  @override
  Widget build(BuildContext context) {
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const <Journal>[]).where((j) => j.isTreasury && j.isActive).toList();
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final can = perms.has('reconciliation.manage', entityId: widget.entity.id);
    final st = _state;
    final t = context.ak;
    final selectedLabel = _selBank.isEmpty && _selBook.isEmpty
        ? 'Pointer'
        : 'Pointer (${Fmt.fcfa(_selBankNet, showZero: true)} ↔ ${Fmt.fcfa(_selBookNet, showZero: true)})';
    final subtitle = _journal == null ? null : '${_journal!.treasuryAccountCode} ${_journal!.label} · ${Fmt.month(_until)}';
    return AkPage(
      children: [
        AkPageHead(
          title: 'Rapprochement bancaire',
          subtitle: subtitle,
          actions: [
            if (can && _journal != null)
              AkButton.secondary(
                'Importer un relevé',
                key: const Key('import-statement'),
                icon: Icons.upload_file_outlined,
                onPressed: _busy ? null : _importStatement,
              ),
            if (_journal != null) AkButton.secondary('État PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _busy ? null : _exportPdf),
            if (can && _journal != null)
              AkButton.primary(
                'Figer l\'état du mois',
                key: const Key('finalize-recon'),
                onPressed: _busy || st == null || st.difference != 0 ? null : _finalize,
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
                value: _journal?.id,
                items: [for (final j in journals) AkOption(j.id, '${j.code} · ${j.label} (${j.treasuryAccountCode})')],
                onChanged: (v) {
                  setState(() => _journal = journals.where((j) => j.id == v).firstOrNull);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: AkDateField(
                controller: _asOf,
                label: 'État au',
                onChanged: (d) {
                  if (d != null) _load();
                },
              ),
            ),
            if (can && _journal != null)
              AkButton.primary(
                selectedLabel,
                key: const Key('match-selected'),
                icon: Icons.link,
                onPressed: _busy || _selBank.isEmpty || _selBook.isEmpty || _selBankNet != _selBookNet ? null : _matchSelected,
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: AkSpace.s2),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        if (st != null) ...[const SizedBox(height: AkSpace.s4), ReconciliationStateBar(state: st)],
        if (_proposals.isNotEmpty && can) ...[
          const SizedBox(height: AkSpace.s4),
          AkBanner(
            kind: AkBannerKind.info,
            icon: Icons.auto_awesome,
            action: Wrap(
              spacing: AkSpace.s2,
              children: [
                AkButton.ghost('Sélectionner la première', dense: true, onPressed: _selectProposals),
                AkButton.secondary('Tout accepter', dense: true, icon: Icons.done_all, onPressed: _busy ? null : _acceptAllProposals),
              ],
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${_proposals.length} proposition(s) de pointage', style: AkText.bodyStrong),
                  const TextSpan(text: ' (montant identique, ± 5 jours)'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AkSpace.s4),
        if (_journal == null)
          const AkBanner(kind: AkBannerKind.info, child: Text('Choisissez un journal de banque ou de caisse.'))
        else
          LayoutBuilder(
            builder: (context, c) {
              final bankPane = _pane<StatementLine>(
                'Relevé bancaire non pointé (${_bank.length})',
                _bank,
                selected: (l) => _selBank.contains(l.id),
                toggle: !can ? null : (l) => setState(() => _selBank.contains(l.id) ? _selBank.remove(l.id) : _selBank.add(l.id)),
                columns: [
                  AkColumn<StatementLine>.text(label: 'Date', width: 84, text: (l) => Fmt.date(l.date)),
                  AkColumn<StatementLine>.text(label: 'Libellé', text: (l) => l.label),
                  AkColumn<StatementLine>(
                    label: '',
                    width: 110,
                    cell: (context, l) => _proposals.any((p) => p.statementLineId == l.id)
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
                'Comptabilité non pointée (${_book.length})',
                _book,
                selected: (l) => _selBook.contains(l.id),
                toggle: !can ? null : (l) => setState(() => _selBook.contains(l.id) ? _selBook.remove(l.id) : _selBook.add(l.id)),
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
        if (_journal != null) ...[
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

  void _selectProposals() {
    final p = _proposals.first;
    setState(() {
      _selBank
        ..clear()
        ..add(p.statementLineId);
      _selBook
        ..clear()
        ..add(p.entryLineId);
    });
  }

  Future<void> _acceptAllProposals() async {
    final repo = ref.read(reconciliationServiceProvider);
    var n = 0;
    for (final p in _proposals) {
      try {
        await repo.match(_journal!.id, [p.statementLineId], [p.entryLineId], note: 'proposition');
        n++;
      } catch (_) {}
    }
    if (mounted) showAkToast(context, '$n pointage(s) effectué(s).');
    await _load();
  }

  Future<void> _matchSelected() async {
    try {
      await ref.read(reconciliationServiceProvider).match(_journal!.id, _selBank.toList(), _selBook.toList());
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    }
    await _load();
  }

  Future<void> _createEntry(StatementLine l) async {
    // Listes attendues (et non lues en cache) : l'écran peut être ouvert sans passage préalable par un module qui les charge.
    final accounts = (await ref.read(accountsProvider(widget.entity.id).future)).where((a) => a.allowPosting && a.isActive && a.classNo != 5).toList();
    final thirdParties = await ref.read(thirdPartiesProvider(widget.entity.id).future);
    if (!mounted) return;
    final result = await showDialog<(Account, ThirdParty?, String, DateTime)>(
      context: context,
      builder: (_) => EntryFromLineDialog(line: l, accounts: accounts, thirdParties: thirdParties),
    );
    if (result == null) return;
    try {
      await ref
          .read(reconciliationServiceProvider)
          .entryFromLine(l.id, accountId: result.$1.id, thirdPartyId: result.$2?.id, label: result.$3, entryDate: result.$4, validate: true);
      ref.invalidate(entityDashboardProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    }
    await _load();
  }

  Future<void> _importStatement() async {
    final templates = await ref.read(statementTemplatesProvider.future);
    if (!mounted) return;
    final template = await showDialog<StatementTemplate>(
      context: context,
      builder: (_) => ReconciliationTemplateDialog(templates: templates, bankName: _journal!.label),
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
    try {
      String? templateId = template.id;
      if (templateId == null) {
        final cabinet = await ref.read(currentCabinetProvider.future);
        templateId = (await ref.read(reconciliationServiceProvider).saveTemplate(cabinet!.id, template)).id;
        ref.invalidate(statementTemplatesProvider);
      }
      await ref
          .read(reconciliationServiceProvider)
          .importStatement(
            journalId: _journal!.id,
            from: params.$1,
            to: params.$2,
            lines: parsed.lines,
            opening: params.$3,
            closing: params.$4,
            templateId: templateId,
            fileName: file.name,
          );
      if (mounted) showAkToast(context, '${parsed.lines.length} lignes de relevé importées.');
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    }
    await _load();
  }

  Future<void> _finalize() async {
    try {
      await ref.read(reconciliationServiceProvider).finalize(_journal!.id, _until);
      if (mounted) showAkToast(context, 'État de rapprochement figé. Exportez le PDF pour l\'archiver.');
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    }
    await _load();
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final p = ConsultationParams(entityId: widget.entity.id, from: DateTime(_until.year, _until.month, 1), to: _until, journalId: _journal!.id);
      final (name, bytes) = await ref.read(consultationServiceProvider).export(p: p, kind: 'reconciliation', format: 'pdf');
      final uri = await FilePicker.saveFile(dialogTitle: 'Enregistrer l\'état de rapprochement', fileName: name, bytes: bytes);
      if (uri != null && uri.scheme == 'file') {
        final f = File(uri.toFilePath());
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
