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
import '../widgets/ak_widgets.dart';
import '../widgets/require_entity.dart';
import '../widgets/status_chip.dart';
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
    final t = context.ak;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final gutter = mobile ? AkSpace.s4 : AkSpace.s6;
    final control = mobile ? AkSpace.controlTouch : AkSpace.controlCompact;
    final balanced = _draft.balance == 0;
    final balanceColor = balanced ? t.success : t.danger;
    final title = _loaded == null ? 'Nouvelle écriture' : 'Écriture ${_loaded!.numberLabel}';
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => setState(_draft.autoBalance),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _readOnly ? null : _save(),
      },
      child: Focus(
        autofocus: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AkSpace.s4, gutter, AkSpace.s6),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              IconButton(tooltip: 'Retour à la liste', icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/saisie')),
              const SizedBox(width: AkSpace.s1),
              Expanded(
                child: AkPageHead(
                  title: title,
                  subtitle: _readOnly ? 'Écriture validée : lecture seule' : 'Grille au clavier',
                  actions: [
                    if (!_readOnly) ...[
                      OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size(0, control)), onPressed: _applyTemplate, icon: const Icon(Icons.auto_fix_high_outlined, size: 18), label: const Text('Modèle')),
                      OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size(0, control)), onPressed: () => setState(_draft.autoBalance), icon: const Icon(Icons.balance, size: 18), label: const Text('Contrepartie (Ctrl+B)')),
                      if (_draft.id != null) OutlinedButton.icon(style: akDangerOutlinedStyle(context).merge(OutlinedButton.styleFrom(minimumSize: Size(0, control))), onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Supprimer')),
                    ],
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AkSpace.s3),
            AkCard(
              child: Wrap(
                spacing: AkSpace.s3,
                runSpacing: AkSpace.s3,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
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
                  SizedBox(width: 130, child: TextField(controller: _date, key: const Key('entry-date'), enabled: !_readOnly, decoration: const InputDecoration(labelText: 'Date'))),
                  SizedBox(width: 160, child: TextField(controller: _reference, enabled: !_readOnly, style: AkText.code, decoration: const InputDecoration(labelText: 'Référence pièce'))),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 720),
                    child: SizedBox(
                      width: mobile ? double.infinity : 420,
                      child: TextField(controller: _label, key: const Key('entry-label'), enabled: !_readOnly, decoration: const InputDecoration(labelText: 'Libellé')),
                    ),
                  ),
                  if (_loaded != null) StatusChip(StatusChip.of(status: _loaded!.status, reviewStatus: _loaded!.reviewStatus)) else const StatusChip(EntryStatusKind.draft),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s3),
            AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Sur petit écran la grille défile horizontalement plutôt que de se comprimer.
                LayoutBuilder(builder: (context, c) {
                  final grid = Column(children: [
                    const _GridHeader(),
                    for (var i = 0; i < _draft.lines.length; i++)
                      _LineRow(
                        key: ValueKey(_draft.lines[i]),
                        index: i,
                        line: _draft.lines[i],
                        entityId: widget.entity.id,
                        readOnly: _readOnly,
                        touch: mobile,
                        onChanged: () => setState(() {}),
                        onRemove: _readOnly || _draft.lines.length <= 2 ? null : () => setState(() => _draft.lines.removeAt(i)),
                        onEnterOnLast: i == _draft.lines.length - 1 ? () => setState(() => _draft.lines.add(DraftLine())) : null,
                      ),
                    // Pied de totaux : filet fort, montants alignés sur les colonnes Débit / Crédit.
                    Container(
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderStrong, width: 2))),
                      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: AkSpace.s2),
                      child: Row(children: [
                        const SizedBox(width: _kIndexW),
                        Expanded(child: Text('Totaux', style: AkText.bodyStrong.copyWith(color: t.text))),
                        const SizedBox(width: AkSpace.s2),
                        SizedBox(width: _kAmountW, child: AkAmountText(Fmt.fcfa(_draft.totalDebit, showZero: true), bold: true)),
                        const SizedBox(width: AkSpace.s2),
                        SizedBox(width: _kAmountW, child: AkAmountText(Fmt.fcfa(_draft.totalCredit, showZero: true), bold: true)),
                        const SizedBox(width: _kRemoveW),
                      ]),
                    ),
                  ]);
                  if (c.maxWidth >= _kGridMinWidth) return grid;
                  return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: _kGridMinWidth, child: grid));
                }),
                Divider(height: 1, color: t.border),
                Padding(
                  padding: const EdgeInsets.all(AkSpace.s3),
                  child: Wrap(
                    spacing: AkSpace.s3,
                    runSpacing: AkSpace.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!_readOnly) TextButton.icon(onPressed: () => setState(() => _draft.lines.add(DraftLine())), icon: const Icon(Icons.add, size: 18), label: const Text('Ligne')),
                      Row(key: const Key('balance-chip'), mainAxisSize: MainAxisSize.min, children: [
                        Icon(balanced ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: balanceColor),
                        const SizedBox(width: 6),
                        Text(balanced ? 'Équilibrée' : 'Écart ${Fmt.fcfa(_draft.balance, showZero: true)}', style: AkText.bodyStrong.copyWith(color: balanceColor)),
                      ]),
                      if (!_readOnly) ...[
                        OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: Size(0, control)), key: const Key('save-draft'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer (Ctrl+S)')),
                        if (canValidate) FilledButton(style: FilledButton.styleFrom(minimumSize: Size(0, control)), key: const Key('validate-entry'), onPressed: _busy ? null : () => _save(validate: true), child: const Text('Valider')),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: AkBanner(
                  kind: AkBannerKind.danger,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final e in _errors) Text('• $e')]),
                ),
              ),
            if (_loaded?.reviewComment != null)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: AkBanner(kind: AkBannerKind.warning, child: Text('Revue : ${_loaded!.reviewComment}')),
              ),
            if (!_readOnly && !mobile)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: Wrap(spacing: AkSpace.s4, runSpacing: AkSpace.s1, children: [
                  for (final (k, d) in const [('Tab', 'cellule suivante'), ('Entrée', 'en fin de ligne : nouvelle ligne'), ('Ctrl B', 'contrepartie'), ('Ctrl S', 'enregistrer le brouillard')])
                    Row(mainAxisSize: MainAxisSize.min, children: [AkKbd(k), const SizedBox(width: 6), Text(d, style: AkText.caption.copyWith(color: t.textMuted))]),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// Largeurs des colonnes de la grille, partagées par l'en-tête, les lignes et le pied de totaux.
const double _kIndexW = 24;
const double _kAmountW = 130;
const double _kRemoveW = 40;
const double _kGridMinWidth = 820;

class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final style = AkText.label.copyWith(color: t.textMuted, letterSpacing: 0);
    return Container(
      height: AkSpace.rowCompact,
      color: t.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
      child: Row(children: [
        const SizedBox(width: _kIndexW),
        SizedBox(width: 220, child: Text('Compte', style: style)),
        const SizedBox(width: AkSpace.s2),
        SizedBox(width: 120, child: Text('Tiers', style: style)),
        const SizedBox(width: AkSpace.s2),
        Expanded(child: Text('Libellé', style: style)),
        const SizedBox(width: AkSpace.s2),
        SizedBox(width: _kAmountW, child: Text('Débit (FCFA)', style: style, textAlign: TextAlign.right)),
        const SizedBox(width: AkSpace.s2),
        SizedBox(width: _kAmountW, child: Text('Crédit (FCFA)', style: style, textAlign: TextAlign.right)),
        const SizedBox(width: _kRemoveW),
      ]),
    );
  }
}

/// Une ligne de la grille : compte avec autocomplétion (numéro ou intitulé), tiers si collectif, libellé, débit, crédit.
class _LineRow extends ConsumerStatefulWidget {
  const _LineRow({super.key, required this.index, required this.line, required this.entityId, required this.readOnly, this.touch = false, required this.onChanged, this.onRemove, this.onEnterOnLast});

  final int index;
  final DraftLine line;
  final String entityId;
  final bool readOnly;

  /// Cellules de 44 px sur mobile.
  final bool touch;
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

  /// Applique le compte choisi (liste ou code tapé) à la ligne.
  void _selectAccount(DraftLine l, Account a) {
    l.accountId = a.id;
    l.accountCode = a.code;
    l.accountLabel = a.label;
    l.isCollective = a.isCollective;
    if (!a.isCollective) {
      l.thirdPartyId = null;
      l.thirdPartyCode = '';
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entityId)).value ?? const <Account>[]).where((a) => a.isActive && a.allowPosting).toList();
    final thirdParties = (ref.watch(thirdPartiesProvider(widget.entityId)).value ?? const <ThirdParty>[]).where((t) => t.isActive).toList();
    final l = widget.line;
    final t = context.ak;
    return Container(
      constraints: BoxConstraints(minHeight: widget.touch ? AkSpace.rowTouch : AkSpace.rowCompact),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: 2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(children: [
        SizedBox(width: _kIndexW, child: Text('${widget.index + 1}', style: AkText.caption.copyWith(color: t.textMuted))),
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
            onSelected: (a) => _selectAccount(l, a),
            fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
              controller: controller,
              focusNode: focus,
              enabled: !widget.readOnly,
              style: AkText.code,
              decoration: InputDecoration(isDense: true, hintText: 'Numéro ou intitulé', errorText: controller.text.isNotEmpty && l.accountId == null ? 'Choisir dans la liste' : null),
              onChanged: (v) {
                final typed = matchAccountCode(accounts, v);
                if (typed != null) {
                  _selectAccount(l, typed);
                } else if (l.accountId != null) {
                  l.accountId = null;
                  l.accountCode = '';
                  widget.onChanged();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: AkSpace.s2),
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
        const SizedBox(width: AkSpace.s2),
        Expanded(child: TextField(controller: _label, enabled: !widget.readOnly, decoration: const InputDecoration(isDense: true), onChanged: (v) => l.label = v)),
        const SizedBox(width: AkSpace.s2),
        SizedBox(width: _kAmountW, child: _amountField(_debit, (v) => l.debit = v, () => l.credit = 0, _credit)),
        const SizedBox(width: AkSpace.s2),
        SizedBox(width: _kAmountW, child: _amountField(_credit, (v) => l.credit = v, () => l.debit = 0, _debit, last: true)),
        SizedBox(width: _kRemoveW, child: widget.onRemove == null ? null : IconButton(tooltip: 'Supprimer la ligne', icon: const Icon(Icons.close, size: 16), onPressed: widget.onRemove)),
      ]),
    );
  }

  Widget _amountField(TextEditingController c, void Function(int) set, VoidCallback clearOther, TextEditingController other, {bool last = false}) {
    return TextField(
      controller: c,
      enabled: !widget.readOnly,
      textAlign: TextAlign.right,
      style: AkText.amount,
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
