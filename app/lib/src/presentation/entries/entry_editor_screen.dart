import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/entries_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entry_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/require_entity.dart';
import 'entries_screen.dart';

/// Saisie d'une écriture (grille au clavier) : journal, date, référence, libellé ; lignes compte / tiers / libellé / débit / crédit ;
/// autocomplétion, contrepartie automatique (Ctrl+B), modèles d'écritures, équilibre affiché, validation (§10.4).
class EntryEditorScreen extends StatelessWidget {
  const EntryEditorScreen({super.key, this.entryId});

  final String? entryId;

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _Editor(entity: entity, entryId: entryId));
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.entity, this.entryId});

  final EntitySummary entity;
  final String? entryId;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  EntryDraft _draft = EntryDraft();
  EntryModel? _loaded;
  bool _loading = true;
  bool _busy = false;
  List<String> _errors = const [];
  late final _date = TextEditingController(text: Fmt.date(_draft.entryDate));
  late final _reference = TextEditingController();
  late final _label = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.entryId != null) {
      final e = await ref.read(entriesRepositoryProvider).get(widget.entryId!);
      _loaded = e;
      _draft = EntryDraft.fromEntry(e);
      _date.text = Fmt.date(_draft.entryDate);
      _reference.text = _draft.reference;
      _label.text = _draft.label;
      if (_draft.lines.length < 2) _draft.lines.add(DraftLine());
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _readOnly => _loaded != null && !_loaded!.isDraft;

  Future<void> _save({bool validate = false}) async {
    _draft.reference = _reference.text;
    _draft.label = _label.text;
    final d = Fmt.parseDate(_date.text);
    if (d == null) {
      setState(() => _errors = ['Date invalide (jj/mm/aaaa)']);
      return;
    }
    _draft.entryDate = d;
    final errors = validate ? _draft.validationErrors() : [if (_draft.journalId == null) 'Journal requis', if (_draft.label.trim().isEmpty) 'Libellé requis', if (_draft.nonEmptyLines.any((l) => l.accountId == null)) 'Chaque ligne saisie doit avoir un compte'];
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      final repo = ref.read(entriesRepositoryProvider);
      final id = await repo.saveDraft(cabinet!.id, widget.entity.id, _draft);
      _draft.id = id;
      if (validate) {
        final n = await repo.validate(id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Écriture validée : n° $n')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brouillard enregistré.')));
      }
      ref.invalidate(entriesListProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
      if (mounted) context.go('/saisie');
    } catch (e) {
      setState(() => _errors = [frenchEntryError(e)]);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_draft.id == null) return;
    await ref.read(entriesRepositoryProvider).deleteDraft(_draft.id!);
    ref.invalidate(entriesListProvider(widget.entity.id));
    if (mounted) context.go('/saisie');
  }

  Future<void> _applyTemplate() async {
    final templates = await ref.read(templatesProvider(widget.entity.id).future);
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    final rates = await ref.read(taxRatesProvider.future);
    if (!mounted) return;
    final result = await showDialog<(EntryTemplate, int)>(context: context, builder: (_) => _TemplatePicker(templates: templates));
    if (result == null) return;
    final (template, amount) = result;
    final today = DateTime.now();
    double? rateOf(String code) {
      final r = rates.where((r) => r.code == code && !r.validFrom.isAfter(today) && (r.validTo == null || !r.validTo!.isBefore(today))).firstOrNull;
      return r?.rate;
    }
    Account? resolve(String code) => accounts.where((a) => a.code == padAccountCode(code, accounts.first.code.length)).firstOrNull;
    setState(() {
      _draft.lines
        ..clear()
        ..addAll(applyTemplate(template, baseAmount: amount, rateOf: rateOf, resolveAccount: resolve))
        ..add(DraftLine());
      if (_label.text.isEmpty) _label.text = template.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const []).where((j) => j.isActive).toList();
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canValidate = perms.has('entries.validate', entityId: widget.entity.id);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => setState(_draft.autoBalance),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _readOnly ? null : _save(),
      },
      child: Focus(
        autofocus: true,
        child: Column(children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/saisie')),
                Text(_loaded == null ? 'Nouvelle écriture' : 'Écriture ${_loaded!.numberLabel}', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (!_readOnly) ...[
                  TextButton.icon(onPressed: _applyTemplate, icon: const Icon(Icons.auto_fix_high_outlined), label: const Text('Modèle')),
                  TextButton.icon(onPressed: () => setState(_draft.autoBalance), icon: const Icon(Icons.balance), label: const Text('Contrepartie (Ctrl+B)')),
                  if (_draft.id != null) TextButton.icon(onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline), label: const Text('Supprimer')),
                  OutlinedButton(key: const Key('save-draft'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer (Ctrl+S)')),
                  const SizedBox(width: 8),
                  if (canValidate) FilledButton(key: const Key('validate-entry'), onPressed: _busy ? null : () => _save(validate: true), child: const Text('Valider')),
                ],
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          key: const Key('entry-journal'),
                          isExpanded: true,
                          initialValue: _draft.journalId,
                          decoration: const InputDecoration(labelText: 'Journal'),
                          items: [for (final j in journals) DropdownMenuItem(value: j.id, child: Text('${j.code} · ${j.label}', overflow: TextOverflow.ellipsis))],
                          onChanged: _readOnly ? null : (v) => setState(() => _draft.journalId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 130, child: TextField(controller: _date, key: const Key('entry-date'), enabled: !_readOnly, decoration: const InputDecoration(labelText: 'Date'))),
                      const SizedBox(width: 8),
                      SizedBox(width: 160, child: TextField(controller: _reference, enabled: !_readOnly, decoration: const InputDecoration(labelText: 'Référence pièce'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _label, key: const Key('entry-label'), enabled: !_readOnly, decoration: const InputDecoration(labelText: 'Libellé'))),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      const _GridHeader(),
                      for (var i = 0; i < _draft.lines.length; i++)
                        _LineRow(
                          key: ValueKey(_draft.lines[i]),
                          index: i,
                          line: _draft.lines[i],
                          entityId: widget.entity.id,
                          readOnly: _readOnly,
                          onChanged: () => setState(() {}),
                          onRemove: _readOnly || _draft.lines.length <= 2 ? null : () => setState(() => _draft.lines.removeAt(i)),
                          onEnterOnLast: i == _draft.lines.length - 1 ? () => setState(() => _draft.lines.add(DraftLine())) : null,
                        ),
                      const Divider(),
                      Row(children: [
                        if (!_readOnly) TextButton.icon(onPressed: () => setState(() => _draft.lines.add(DraftLine())), icon: const Icon(Icons.add), label: const Text('Ligne')),
                        const Spacer(),
                        Text('Débit ${Fmt.fcfa(_draft.totalDebit, showZero: true)}   Crédit ${Fmt.fcfa(_draft.totalCredit, showZero: true)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 16),
                        Chip(
                          key: const Key('balance-chip'),
                          label: Text(_draft.balance == 0 ? 'Équilibrée' : 'Écart ${Fmt.fcfa(_draft.balance, showZero: true)}'),
                          backgroundColor: (_draft.balance == 0 ? AkColors.validated : AkColors.toCorrect).withValues(alpha: 0.12),
                          side: BorderSide(color: _draft.balance == 0 ? AkColors.validated : AkColors.toCorrect),
                        ),
                      ]),
                    ]),
                  ),
                ),
                if (_errors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      color: AkColors.toCorrect.withValues(alpha: 0.08),
                      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final e in _errors) Text('• $e', style: const TextStyle(color: AkColors.toCorrect))])),
                    ),
                  ),
                if (_loaded?.reviewComment != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Revue : ${_loaded!.reviewComment}', style: const TextStyle(color: AkColors.toCorrect))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w600, fontSize: 12);
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 24),
        SizedBox(width: 220, child: Text('Compte', style: style)),
        SizedBox(width: 8),
        SizedBox(width: 120, child: Text('Tiers', style: style)),
        SizedBox(width: 8),
        Expanded(child: Text('Libellé', style: style)),
        SizedBox(width: 8),
        SizedBox(width: 130, child: Text('Débit', style: style, textAlign: TextAlign.right)),
        SizedBox(width: 8),
        SizedBox(width: 130, child: Text('Crédit', style: style, textAlign: TextAlign.right)),
        SizedBox(width: 40),
      ]),
    );
  }
}

/// Une ligne de la grille : compte avec autocomplétion (numéro ou intitulé), tiers si collectif, libellé, débit, crédit.
class _LineRow extends ConsumerStatefulWidget {
  const _LineRow({super.key, required this.index, required this.line, required this.entityId, required this.readOnly, required this.onChanged, this.onRemove, this.onEnterOnLast});

  final int index;
  final DraftLine line;
  final String entityId;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onEnterOnLast;

  @override
  ConsumerState<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends ConsumerState<_LineRow> {
  late final _label = TextEditingController(text: widget.line.label);
  late final _debit = TextEditingController(text: Fmt.fcfa(widget.line.debit));
  late final _credit = TextEditingController(text: Fmt.fcfa(widget.line.credit));

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entityId)).value ?? const <Account>[]).where((a) => a.isActive && a.allowPosting).toList();
    final thirdParties = (ref.watch(thirdPartiesProvider(widget.entityId)).value ?? const <ThirdParty>[]).where((t) => t.isActive).toList();
    final l = widget.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 24, child: Text('${widget.index + 1}', style: const TextStyle(fontSize: 12))),
        SizedBox(
          width: 220,
          child: Autocomplete<Account>(
            key: Key('line-account-${widget.index}'),
            initialValue: TextEditingValue(text: l.accountCode.isEmpty ? '' : '${l.accountCode} ${l.accountLabel}'),
            displayStringForOption: (a) => '${a.code} ${a.label}',
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<Account>.empty();
              return accounts.where((a) => a.code.startsWith(q) || a.label.toLowerCase().contains(q)).take(12);
            },
            onSelected: (a) {
              l.accountId = a.id;
              l.accountCode = a.code;
              l.accountLabel = a.label;
              l.isCollective = a.isCollective;
              if (!a.isCollective) {
                l.thirdPartyId = null;
                l.thirdPartyCode = '';
              }
              widget.onChanged();
            },
            fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
              controller: controller,
              focusNode: focus,
              enabled: !widget.readOnly,
              decoration: InputDecoration(isDense: true, hintText: 'Numéro ou intitulé', errorText: controller.text.isNotEmpty && l.accountId == null ? 'Choisir dans la liste' : null),
              onChanged: (v) {
                if (v.isEmpty) {
                  l.accountId = null;
                  l.accountCode = '';
                  widget.onChanged();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: l.isCollective
              ? Autocomplete<ThirdParty>(
                  initialValue: TextEditingValue(text: l.thirdPartyCode),
                  displayStringForOption: (t) => t.code,
                  optionsBuilder: (v) {
                    final q = v.text.trim().toUpperCase();
                    return thirdParties.where((t) => q.isEmpty || t.code.contains(q) || t.name.toUpperCase().contains(q)).take(12);
                  },
                  onSelected: (t) {
                    l.thirdPartyId = t.id;
                    l.thirdPartyCode = t.code;
                    widget.onChanged();
                  },
                  fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(controller: controller, focusNode: focus, enabled: !widget.readOnly, decoration: const InputDecoration(isDense: true, hintText: 'Code tiers')),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _label, enabled: !widget.readOnly, decoration: const InputDecoration(isDense: true), onChanged: (v) => l.label = v)),
        const SizedBox(width: 8),
        SizedBox(width: 130, child: _amountField(_debit, (v) => l.debit = v, () => l.credit = 0, _credit)),
        const SizedBox(width: 8),
        SizedBox(width: 130, child: _amountField(_credit, (v) => l.credit = v, () => l.debit = 0, _debit, last: true)),
        SizedBox(width: 40, child: widget.onRemove == null ? null : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onRemove)),
      ]),
    );
  }

  Widget _amountField(TextEditingController c, void Function(int) set, VoidCallback clearOther, TextEditingController other, {bool last = false}) {
    return TextField(
      controller: c,
      enabled: !widget.readOnly,
      textAlign: TextAlign.right,
      decoration: const InputDecoration(isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final n = Fmt.parseAmount(v) ?? 0;
        set(n);
        if (n > 0) {
          clearOther();
          other.clear();
        }
        widget.onChanged();
      },
      onSubmitted: (_) => last ? widget.onEnterOnLast?.call() : null,
    );
  }
}

class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker({required this.templates});

  final List<EntryTemplate> templates;

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  EntryTemplate? _template;
  final _amount = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final amount = Fmt.parseAmount(_amount.text);
    return AlertDialog(
      title: const Text('Appliquer un modèle'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<EntryTemplate>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Modèle'),
            items: [for (final t in widget.templates) DropdownMenuItem(value: t, child: Text('${t.code} — ${t.label}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _template = v),
          ),
          const SizedBox(height: 8),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Montant de base (FCFA)'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _template == null || amount == null || amount <= 0 ? null : () => Navigator.pop(context, (_template!, amount)), child: const Text('Appliquer')),
      ],
    );
  }
}
