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
import '../inventory/inventory_screen.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/reconciliation_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../core/text_decoding.dart';
import '../../domain/consultation_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

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
        if (st != null) ...[const SizedBox(height: AkSpace.s4), _StateBar(state: st)],
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
      builder: (_) => _EntryFromLineDialog(line: l, accounts: accounts, thirdParties: thirdParties),
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
      builder: (_) => _TemplateDialog(templates: templates, bankName: _journal!.label),
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
      builder: (_) => _StatementParamsDialog(from: dates.first, to: dates.last, count: parsed.lines.length, errors: parsed.errors),
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

class _StateBar extends StatelessWidget {
  const _StateBar({required this.state});

  final ReconciliationStateModel state;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final ok = state.difference == 0;
    Widget cell(String label, int v) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
      child: AkCard(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AkText.caption.copyWith(color: t.textMuted)),
            Text(
              Fmt.fcfa(v, showZero: true),
              style: AkText.heading.copyWith(fontFamily: AkFonts.mono, fontFeatures: const [FontFeature.tabularFigures()], color: t.text),
            ),
          ],
        ),
      ),
    );
    return Wrap(
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s3,
      children: [
        cell('Solde comptable', state.bookBalance),
        cell('Solde banque', state.bankBalance),
        cell('+ Encaissements non crédités', state.depositsInTransit),
        cell('- Décaissements non débités', state.outstandingPayments),
        cell('+ Débits banque non comptabilisés', state.unmatchedBankDebits),
        cell('- Crédits banque non comptabilisés', state.unmatchedBankCredits),
        AkCard(
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Écart après rapprochement', style: AkText.caption.copyWith(color: t.textMuted)),
              const SizedBox(height: AkSpace.s1),
              AkBadge(
                key: const Key('recon-diff'),
                label: ok ? 'Écart 0 : rapproché' : 'Écart ${Fmt.fcfa(state.difference, showZero: true)}',
                color: ok ? t.success : t.danger,
                tint: ok ? t.successTint : t.dangerTint,
                icon: ok ? Icons.check_circle_outline : Icons.error_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryFromLineDialog extends StatefulWidget {
  const _EntryFromLineDialog({required this.line, required this.accounts, required this.thirdParties});

  final StatementLine line;
  final List<Account> accounts;
  final List<ThirdParty> thirdParties;

  @override
  State<_EntryFromLineDialog> createState() => _EntryFromLineDialogState();
}

class _EntryFromLineDialogState extends State<_EntryFromLineDialog> {
  Account? _account;
  ThirdParty? _tp;
  late final _label = TextEditingController(text: widget.line.label);
  late final _date = TextEditingController(text: Fmt.date(widget.line.date));

  @override
  void dispose() {
    _label.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return AkDialog(
      title: 'Créer l\'écriture depuis le relevé',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${Fmt.date(l.date)} · ${l.label} · ${l.debit > 0 ? 'sortie' : 'entrée'} de ${Fmt.fcfa(l.debit > 0 ? l.debit : l.credit)} FCFA'),
          const SizedBox(height: AkSpace.s3),
          AkAccountField(
            label: 'Compte de contrepartie (ex. 6318)',
            accounts: widget.accounts,
            selected: _account,
            onSelected: (a) => setState(() => _account = a),
            onCleared: () {
              if (_account != null) setState(() => _account = null);
            },
          ),
          const SizedBox(height: AkSpace.s2),
          AkDateField(
            key: const Key('entry-from-line-date'),
            controller: _date,
            label: 'Date de l\'écriture',
            helper: 'Date d\'opération par défaut ; à reporter si sa période est verrouillée.',
            onChanged: (_) => setState(() {}),
          ),
          if (_account?.isCollective ?? false) ...[
            const SizedBox(height: AkSpace.s2),
            AkThirdPartyField(label: 'Tiers', thirdParties: widget.thirdParties, onSelected: (t) => setState(() => _tp = t)),
          ],
          const SizedBox(height: AkSpace.s2),
          AkTextField(controller: _label, label: 'Libellé'),
          const SizedBox(height: AkSpace.s2),
          Text(
            'L\'écriture est validée dans le journal de banque et pointée avec la ligne du relevé.',
            style: AkText.caption.copyWith(color: context.ak.textMuted),
          ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Créer et pointer',
          onPressed: _account == null || ((_account!.isCollective) && _tp == null) || Fmt.parseDate(_date.text) == null
              ? null
              : () => Navigator.pop(context, (_account!, _tp, _label.text.trim(), Fmt.parseDate(_date.text)!)),
        ),
      ],
    );
  }
}

/// Choix ou création d'un gabarit de colonnes (mémorisé par banque).
class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.templates, required this.bankName});

  final List<StatementTemplate> templates;
  final String bankName;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  StatementTemplate? _existing;
  bool _create = false;
  late final _bank = TextEditingController(text: widget.bankName);
  final _label = TextEditingController(text: 'Export CSV');
  final _delimiter = TextEditingController(text: ';');
  final _date = TextEditingController(text: '1');
  final _lib = TextEditingController(text: '2');
  final _debit = TextEditingController(text: '3');
  final _credit = TextEditingController(text: '4');
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  bool _header = true;
  String _dateFormat = 'DD/MM/YYYY';
  String _decimal = ',';
  bool _inverted = false;

  Widget _col(String label, TextEditingController c) => SizedBox(
    width: 140,
    child: AkTextField(controller: c, label: label, keyboardType: TextInputType.number),
  );

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Gabarit du relevé',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.templates.isNotEmpty && !_create)
            AkDropdown<String?>(
              label: 'Gabarit mémorisé',
              value: _existing?.id,
              items: [for (final t in widget.templates) AkOption<String?>(t.id, '${t.bankName} · ${t.label}')],
              onChanged: (v) => setState(() => _existing = widget.templates.where((t) => t.id == v).firstOrNull),
            ),
          AkButton.ghost(_create ? 'Utiliser un gabarit mémorisé' : 'Nouveau gabarit', onPressed: () => setState(() => _create = !_create)),
          if (_create || widget.templates.isEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkTextField(controller: _bank, label: 'Banque'),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _label, label: 'Nom du gabarit'),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  child: AkTextField(controller: _delimiter, label: 'Séparateur'),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkCheckbox(value: _header, onChanged: (v) => setState(() => _header = v), label: 'Ligne d\'en-tête'),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Text('Numéros de colonnes (1 = première)', style: AkText.caption.copyWith(color: context.ak.textMuted)),
            const SizedBox(height: AkSpace.s1),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                _col('Date', _date),
                _col('Libellé', _lib),
                _col('Débit', _debit),
                _col('Crédit', _credit),
                _col('Montant signé', _amount),
                _col('Référence', _ref),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkDropdown<String>(
                    label: 'Format de date',
                    value: _dateFormat,
                    items: const [AkOption('DD/MM/YYYY', 'jj/mm/aaaa'), AkOption('YYYY-MM-DD', 'aaaa-mm-jj'), AkOption('MM/DD/YYYY', 'mm/jj/aaaa')],
                    onChanged: (v) => setState(() => _dateFormat = v ?? 'DD/MM/YYYY'),
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkDropdown<String>(
                    label: 'Décimale',
                    value: _decimal,
                    items: const [AkOption(',', 'virgule'), AkOption('.', 'point')],
                    onChanged: (v) => setState(() => _decimal = v ?? ','),
                  ),
                ),
              ],
            ),
            AkCheckbox(value: _inverted, onChanged: (v) => setState(() => _inverted = v), label: 'Montant signé : positif = sortie'),
          ],
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Continuer',
          onPressed: () {
            if (!_create && widget.templates.isNotEmpty) {
              if (_existing != null) Navigator.pop(context, _existing);
              return;
            }
            int? n(TextEditingController c) => int.tryParse(c.text.trim());
            final amount = n(_amount);
            if (n(_date) == null || n(_lib) == null || (amount == null && (n(_debit) == null || n(_credit) == null))) return;
            Navigator.pop(
              context,
              StatementTemplate(
                bankName: _bank.text.trim(),
                label: _label.text.trim(),
                delimiter: _delimiter.text.isEmpty ? ';' : _delimiter.text,
                hasHeader: _header,
                dateColumn: n(_date)!,
                labelColumn: n(_lib)!,
                debitColumn: amount == null ? n(_debit) : null,
                creditColumn: amount == null ? n(_credit) : null,
                amountColumn: amount,
                referenceColumn: n(_ref),
                dateFormat: _dateFormat,
                decimalSeparator: _decimal,
                amountSignInverted: _inverted,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatementParamsDialog extends StatefulWidget {
  const _StatementParamsDialog({required this.from, required this.to, required this.count, required this.errors});

  final DateTime from;
  final DateTime to;
  final int count;
  final List<String> errors;

  @override
  State<_StatementParamsDialog> createState() => _StatementParamsDialogState();
}

class _StatementParamsDialogState extends State<_StatementParamsDialog> {
  late final _from = TextEditingController(text: Fmt.date(widget.from));
  late final _to = TextEditingController(text: Fmt.date(widget.to));
  final _opening = TextEditingController();
  final _closing = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Relevé : ${widget.count} lignes lues',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkDateField(controller: _from, label: 'Du'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _to, label: 'Au'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _opening, label: 'Solde début (facultatif)'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkAmountField(controller: _closing, label: 'Solde fin (facultatif)'),
              ),
            ],
          ),
          if (widget.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: Text(
                '${widget.errors.length} ligne(s) ignorée(s) : ${widget.errors.take(3).join(' · ')}',
                style: AkText.caption.copyWith(color: context.ak.danger),
              ),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Importer',
          onPressed: () {
            final f = Fmt.parseDate(_from.text), t = Fmt.parseDate(_to.text);
            if (f == null || t == null) return;
            Navigator.pop(context, (f, t, Fmt.parseAmount(_opening.text), Fmt.parseAmount(_closing.text)));
          },
        ),
      ],
    );
  }
}
