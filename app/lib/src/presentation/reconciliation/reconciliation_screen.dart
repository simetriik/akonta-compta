import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/consultation_repository.dart';
import '../../data/import_repository.dart';
import '../../data/reconciliation_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/bank_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../inventory/inventory_screen.dart' show akPagePadding, showErrorSnack;
import '../widgets/require_entity.dart';

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
    final repo = ref.read(reconciliationRepositoryProvider);
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
      if (mounted) showErrorSnack(context, _french(e));
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
    final selectedLabel = _selBank.isEmpty && _selBook.isEmpty ? 'Pointer' : 'Pointer (${Fmt.fcfa(_selBankNet, showZero: true)} ↔ ${Fmt.fcfa(_selBookNet, showZero: true)})';
    final subtitle = _journal == null ? null : '${_journal!.treasuryAccountCode} ${_journal!.label} · ${Fmt.month(_until)}';
    return ListView(
      padding: akPagePadding(context),
      children: [
        AkPageHead(
          title: 'Rapprochement bancaire',
          subtitle: subtitle,
          actions: [
            if (can && _journal != null) OutlinedButton.icon(key: const Key('import-statement'), onPressed: _busy ? null : _importStatement, icon: const Icon(Icons.upload_file_outlined, size: 18), label: const Text('Importer un relevé')),
            if (_journal != null) OutlinedButton.icon(onPressed: _busy ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('État PDF')),
            if (can && _journal != null)
              FilledButton(
                key: const Key('finalize-recon'),
                onPressed: _busy || st == null || st.difference != 0 ? null : _finalize,
                child: const Text('Figer l\'état du mois'),
              ),
          ],
        ),
        const SizedBox(height: AkSpace.s4),
        Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              key: const Key('recon-journal'),
              isExpanded: true,
              initialValue: _journal?.id,
              decoration: const InputDecoration(labelText: 'Journal de trésorerie'),
              items: [for (final j in journals) DropdownMenuItem(value: j.id, child: Text('${j.code} · ${j.label} (${j.treasuryAccountCode})', overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                setState(() => _journal = journals.where((j) => j.id == v).firstOrNull);
                _load();
              },
            ),
          ),
          SizedBox(width: 130, child: TextField(controller: _asOf, decoration: const InputDecoration(labelText: 'État au'), onSubmitted: (_) => _load())),
          if (can && _journal != null)
            FilledButton.icon(
              key: const Key('match-selected'),
              onPressed: _busy || _selBank.isEmpty || _selBook.isEmpty || _selBankNet != _selBookNet ? null : _matchSelected,
              icon: const Icon(Icons.link, size: 18),
              label: Text(selectedLabel),
            ),
          if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        if (st != null) ...[
          const SizedBox(height: AkSpace.s4),
          _StateBar(state: st),
        ],
        if (_proposals.isNotEmpty && can) ...[
          const SizedBox(height: AkSpace.s4),
          AkBanner(
            kind: AkBannerKind.info,
            icon: Icons.auto_awesome,
            action: Wrap(spacing: AkSpace.s2, children: [
              TextButton(onPressed: _selectProposals, child: const Text('Sélectionner la première')),
              OutlinedButton.icon(onPressed: _busy ? null : _acceptAllProposals, icon: const Icon(Icons.done_all, size: 18), label: const Text('Tout accepter')),
            ]),
            child: Text.rich(TextSpan(children: [TextSpan(text: '${_proposals.length} proposition(s) de pointage', style: AkText.bodyStrong), const TextSpan(text: ' (montant identique, ± 5 jours)')])),
          ),
        ],
        const SizedBox(height: AkSpace.s4),
        if (_journal == null)
          AkBanner(kind: AkBannerKind.info, child: const Text('Choisissez un journal de banque ou de caisse.'))
        else
          LayoutBuilder(builder: (context, c) {
            final bankPane = _pane('Relevé bancaire non pointé (${_bank.length})', [
              for (final l in _bank)
                _row(
                  selected: _selBank.contains(l.id),
                  onChanged: !can ? null : (v) => setState(() => v == true ? _selBank.add(l.id) : _selBank.remove(l.id)),
                  cells: [
                    SizedBox(width: 84, child: Text(Fmt.date(l.date), style: AkText.table.copyWith(color: t.text))),
                    Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
                    if (_proposals.any((p) => p.statementLineId == l.id)) ...[
                      AkBadge(label: 'Proposée', color: t.info, tint: t.infoTint, icon: Icons.auto_awesome),
                      const SizedBox(width: AkSpace.s2),
                    ],
                    SizedBox(width: 110, child: AkAmountText(l.debit > 0 ? '-${Fmt.fcfa(l.debit)}' : '+${Fmt.fcfa(l.credit)}', color: l.debit > 0 ? t.danger : t.success)),
                    if (can) IconButton(tooltip: 'Créer l\'écriture', visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _createEntry(l)),
                  ],
                ),
            ]);
            final bookPane = _pane('Comptabilité non pointée (${_book.length})', [
              for (final l in _book)
                _row(
                  selected: _selBook.contains(l.id),
                  onChanged: !can ? null : (v) => setState(() => v == true ? _selBook.add(l.id) : _selBook.remove(l.id)),
                  cells: [
                    SizedBox(width: 84, child: Text(Fmt.date(l.date), style: AkText.table.copyWith(color: t.text))),
                    SizedBox(width: 60, child: Text('${l.number}', style: AkText.code.copyWith(color: t.text))),
                    Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
                    SizedBox(width: 110, child: AkAmountText(l.debit > 0 ? '+${Fmt.fcfa(l.debit)}' : '-${Fmt.fcfa(l.credit)}', color: l.debit > 0 ? t.success : t.danger)),
                  ],
                ),
            ]);
            if (c.maxWidth >= 900) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: bankPane), const SizedBox(width: AkSpace.s4), Expanded(child: bookPane)]);
            }
            return Column(children: [bankPane, const SizedBox(height: AkSpace.s3), bookPane]);
          }),
        if (_journal != null) ...[
          const SizedBox(height: AkSpace.s3),
          Text('Pointage 1-1 ou plusieurs-à-plusieurs : sélectionnez des lignes des deux côtés puis « Pointer ». Les montants sont vus côté banque à gauche, côté entreprise à droite.', style: AkText.caption.copyWith(color: t.textMuted)),
        ],
      ],
    );
  }

  /// Ligne pointable : case à cocher puis cellules ; fond teinté quand sélectionnée.
  Widget _row({required bool selected, required ValueChanged<bool?>? onChanged, required List<Widget> cells}) {
    final t = context.ak;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!selected),
      child: Container(
        color: selected ? t.brandTint : null,
        constraints: const BoxConstraints(minHeight: AkSpace.rowCompact),
        padding: const EdgeInsets.fromLTRB(AkSpace.s2, 2, AkSpace.s3, 2),
        child: Row(children: [SizedBox(width: 36, child: Checkbox(value: selected, onChanged: onChanged)), ...cells]),
      ),
    );
  }

  Widget _pane(String title, List<Widget> rows) {
    final t = context.ak;
    return AkCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3), child: Text(title, style: AkText.heading.copyWith(color: t.text))),
        for (final r in rows) ...[Divider(height: 1, color: t.border), r],
        if (rows.isEmpty) ...[Divider(height: 1, color: t.border), Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Text('Rien à pointer.', style: AkText.body.copyWith(color: t.textMuted)))],
      ]),
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
    final repo = ref.read(reconciliationRepositoryProvider);
    var n = 0;
    for (final p in _proposals) {
      try {
        await repo.match(_journal!.id, [p.statementLineId], [p.entryLineId], note: 'proposition');
        n++;
      } catch (_) {}
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n pointage(s) effectué(s).')));
    await _load();
  }

  Future<void> _matchSelected() async {
    try {
      await ref.read(reconciliationRepositoryProvider).match(_journal!.id, _selBank.toList(), _selBook.toList());
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _createEntry(StatementLine l) async {
    // Listes attendues (et non lues en cache) : l'écran peut être ouvert sans passage préalable par un module qui les charge.
    final accounts = (await ref.read(accountsProvider(widget.entity.id).future)).where((a) => a.allowPosting && a.isActive && a.classNo != 5).toList();
    final thirdParties = await ref.read(thirdPartiesProvider(widget.entity.id).future);
    if (!mounted) return;
    final result = await showDialog<(Account, ThirdParty?, String, DateTime)>(context: context, builder: (_) => _EntryFromLineDialog(line: l, accounts: accounts, thirdParties: thirdParties));
    if (result == null) return;
    try {
      await ref.read(reconciliationRepositoryProvider).entryFromLine(l.id, accountId: result.$1.id, thirdPartyId: result.$2?.id, label: result.$3, entryDate: result.$4, validate: true);
      ref.invalidate(entityDashboardProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _importStatement() async {
    final templates = await ref.read(statementTemplatesProvider.future);
    if (!mounted) return;
    final template = await showDialog<StatementTemplate>(context: context, builder: (_) => _TemplateDialog(templates: templates, bankName: _journal!.label));
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
    final params = await showDialog<(DateTime, DateTime, int?, int?)>(context: context, builder: (_) => _StatementParamsDialog(from: dates.first, to: dates.last, count: parsed.lines.length, errors: parsed.errors));
    if (params == null) return;
    try {
      String? templateId = template.id;
      if (templateId == null) {
        final cabinet = await ref.read(currentCabinetProvider.future);
        templateId = (await ref.read(reconciliationRepositoryProvider).saveTemplate(cabinet!.id, template)).id;
        ref.invalidate(statementTemplatesProvider);
      }
      await ref.read(reconciliationRepositoryProvider).importStatement(journalId: _journal!.id, from: params.$1, to: params.$2, lines: parsed.lines, opening: params.$3, closing: params.$4, templateId: templateId, fileName: file.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${parsed.lines.length} lignes de relevé importées.')));
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _finalize() async {
    try {
      await ref.read(reconciliationRepositoryProvider).finalize(_journal!.id, _until);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('État de rapprochement figé. Exportez le PDF pour l\'archiver.')));
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final p = ConsultationParams(entityId: widget.entity.id, from: DateTime(_until.year, _until.month, 1), to: _until, journalId: _journal!.id);
      final (name, bytes) = await ref.read(consultationRepositoryProvider).export(p: p, kind: 'reconciliation', format: 'pdf');
      final uri = await FilePicker.saveFile(dialogTitle: 'Enregistrer l\'état de rapprochement', fileName: name, bytes: bytes);
      if (uri != null && uri.scheme == 'file') {
        final f = File(uri.toFilePath());
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _french(Object e) => RegExp(r'message: ([^,}]+)').firstMatch(e.toString())?.group(1) ?? e.toString();
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: AkText.caption.copyWith(color: t.textMuted)),
              Text(Fmt.fcfa(v, showZero: true), style: AkText.amount.copyWith(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: t.text)),
            ]),
          ),
        );
    return Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s3, children: [
      cell('Solde comptable', state.bookBalance),
      cell('Solde banque', state.bankBalance),
      cell('+ Encaissements non crédités', state.depositsInTransit),
      cell('- Décaissements non débités', state.outstandingPayments),
      cell('+ Débits banque non comptabilisés', state.unmatchedBankDebits),
      cell('- Crédits banque non comptabilisés', state.unmatchedBankCredits),
      AkCard(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Écart après rapprochement', style: AkText.caption.copyWith(color: t.textMuted)),
          const SizedBox(height: 2),
          AkBadge(
            key: const Key('recon-diff'),
            label: ok ? 'Écart 0 : rapproché' : 'Écart ${Fmt.fcfa(state.difference, showZero: true)}',
            color: ok ? t.success : t.danger,
            tint: ok ? t.successTint : t.dangerTint,
            icon: ok ? Icons.check_circle_outline : Icons.error_outline,
          ),
        ]),
      ),
    ]);
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
  Widget build(BuildContext context) {
    final l = widget.line;
    return AlertDialog(
      title: const Text('Créer l\'écriture depuis le relevé'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${Fmt.date(l.date)} · ${l.label} · ${l.debit > 0 ? 'sortie' : 'entrée'} de ${Fmt.fcfa(l.debit > 0 ? l.debit : l.credit)} FCFA'),
          const SizedBox(height: 12),
          Autocomplete<Account>(
            displayStringForOption: (a) => '${a.code} ${a.label}',
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<Account>.empty();
              return widget.accounts.where((a) => a.code.startsWith(q) || a.label.toLowerCase().contains(q)).take(12);
            },
            onSelected: (a) => setState(() => _account = a),
            fieldViewBuilder: (context, c, f, _) => TextField(
              controller: c,
              focusNode: f,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Compte de contrepartie (ex. 6318)'),
              onChanged: (v) {
                final typed = matchAccountCode(widget.accounts, v);
                if (typed != _account) setState(() => _account = typed);
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('entry-from-line-date'),
            controller: _date,
            decoration: const InputDecoration(labelText: 'Date de l\'écriture', helperText: 'Date d\'opération par défaut ; à reporter si sa période est verrouillée.'),
            onChanged: (_) => setState(() {}),
          ),
          if (_account?.isCollective ?? false) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tiers'),
              items: [for (final t in widget.thirdParties) DropdownMenuItem(value: t.id, child: Text('${t.code} · ${t.name}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _tp = widget.thirdParties.where((t) => t.id == v).firstOrNull),
            ),
          ],
          const SizedBox(height: 8),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé')),
          const SizedBox(height: 8),
          Text('L\'écriture est validée dans le journal de banque et pointée avec la ligne du relevé.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _account == null || ((_account!.isCollective) && _tp == null) || Fmt.parseDate(_date.text) == null
              ? null
              : () => Navigator.pop(context, (_account!, _tp, _label.text.trim(), Fmt.parseDate(_date.text)!)),
          child: const Text('Créer et pointer'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gabarit du relevé'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.templates.isNotEmpty && !_create)
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gabarit mémorisé'),
                items: [for (final t in widget.templates) DropdownMenuItem(value: t.id, child: Text('${t.bankName} · ${t.label}'))],
                onChanged: (v) => setState(() => _existing = widget.templates.where((t) => t.id == v).firstOrNull),
              ),
            TextButton(onPressed: () => setState(() => _create = !_create), child: Text(_create ? 'Utiliser un gabarit mémorisé' : 'Nouveau gabarit')),
            if (_create || widget.templates.isEmpty) ...[
              Row(children: [
                Expanded(child: TextField(controller: _bank, decoration: const InputDecoration(labelText: 'Banque'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _label, decoration: const InputDecoration(labelText: 'Nom du gabarit'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 90, child: TextField(controller: _delimiter, decoration: const InputDecoration(labelText: 'Séparateur'))),
                const SizedBox(width: 8),
                Expanded(child: CheckboxListTile(value: _header, onChanged: (v) => setState(() => _header = v ?? true), title: const Text('Ligne d\'en-tête'), contentPadding: EdgeInsets.zero)),
              ]),
              Text('Numéros de colonnes (1 = première)', style: AkText.caption.copyWith(color: context.ak.textMuted)),
              Row(children: [
                Expanded(child: TextField(controller: _date, decoration: const InputDecoration(labelText: 'Date'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _lib, decoration: const InputDecoration(labelText: 'Libellé'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _debit, decoration: const InputDecoration(labelText: 'Débit'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _credit, decoration: const InputDecoration(labelText: 'Crédit'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Montant signé'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Référence'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(initialValue: _dateFormat, decoration: const InputDecoration(labelText: 'Format de date'), items: const [DropdownMenuItem(value: 'DD/MM/YYYY', child: Text('jj/mm/aaaa')), DropdownMenuItem(value: 'YYYY-MM-DD', child: Text('aaaa-mm-jj')), DropdownMenuItem(value: 'MM/DD/YYYY', child: Text('mm/jj/aaaa'))], onChanged: (v) => setState(() => _dateFormat = v ?? 'DD/MM/YYYY'))),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(initialValue: _decimal, decoration: const InputDecoration(labelText: 'Décimale'), items: const [DropdownMenuItem(value: ',', child: Text('virgule')), DropdownMenuItem(value: '.', child: Text('point'))], onChanged: (v) => setState(() => _decimal = v ?? ','))),
              ]),
              CheckboxListTile(value: _inverted, onChanged: (v) => setState(() => _inverted = v ?? false), title: const Text('Montant signé : positif = sortie'), contentPadding: EdgeInsets.zero),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!_create && widget.templates.isNotEmpty) {
              if (_existing != null) Navigator.pop(context, _existing);
              return;
            }
            int? n(TextEditingController c) => int.tryParse(c.text.trim());
            final amount = n(_amount);
            if (n(_date) == null || n(_lib) == null || (amount == null && (n(_debit) == null || n(_credit) == null))) return;
            Navigator.pop(context, StatementTemplate(bankName: _bank.text.trim(), label: _label.text.trim(), delimiter: _delimiter.text.isEmpty ? ';' : _delimiter.text, hasHeader: _header, dateColumn: n(_date)!, labelColumn: n(_lib)!,
                debitColumn: amount == null ? n(_debit) : null, creditColumn: amount == null ? n(_credit) : null, amountColumn: amount, referenceColumn: n(_ref), dateFormat: _dateFormat, decimalSeparator: _decimal, amountSignInverted: _inverted));
          },
          child: const Text('Continuer'),
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
    return AlertDialog(
      title: Text('Relevé : ${widget.count} lignes lues'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'Du'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _to, decoration: const InputDecoration(labelText: 'Au'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _opening, decoration: const InputDecoration(labelText: 'Solde début (facultatif)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _closing, decoration: const InputDecoration(labelText: 'Solde fin (facultatif)'))),
          ]),
          if (widget.errors.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${widget.errors.length} ligne(s) ignorée(s) : ${widget.errors.take(3).join(' · ')}', style: AkText.caption.copyWith(color: context.ak.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final f = Fmt.parseDate(_from.text), t = Fmt.parseDate(_to.text);
            if (f == null || t == null) return;
            Navigator.pop(context, (f, t, Fmt.parseAmount(_opening.text), Fmt.parseAmount(_closing.text)));
          },
          child: const Text('Importer'),
        ),
      ],
    );
  }
}
