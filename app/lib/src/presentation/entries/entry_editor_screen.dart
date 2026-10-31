import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../data/entries_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entry_models.dart';
import '../../domain/suggestion_models.dart';
import 'entry_suggestions_panel.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/require_entity.dart';

/// Saisie d'une écriture (grille au clavier) : journal, date, référence, libellé ; lignes compte / tiers / libellé / débit / crédit ;
/// autocomplétion, contrepartie automatique (Ctrl+B), modèles d'écritures, équilibre affiché, validation (§10.4).
class EntryEditorScreen extends StatelessWidget {
  const EntryEditorScreen({super.key, this.entryId});

  final String? entryId;

  @override
  Widget build(BuildContext context) => RequireEntity(
    builder: (entity) => _Editor(entity: entity, entryId: entryId),
  );
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
    final errors = validate
        ? _draft.validationErrors()
        : [
            if (_draft.journalId == null) 'Journal requis',
            if (_draft.label.trim().isEmpty) 'Libellé requis',
            if (_draft.nonEmptyLines.any((l) => l.accountId == null)) 'Chaque ligne saisie doit avoir un compte',
          ];
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
        if (mounted) showAkToast(context, 'Écriture validée : n° $n');
      } else if (mounted) {
        showAkToast(context, 'Brouillard enregistré.');
      }
      ref.invalidate(entriesListProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
      if (mounted) context.go('/saisie');
    } catch (e) {
      setState(() => _errors = [errorText(e)]);
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

  Future<void> _applyTemplate({String? preselectedId}) async {
    final templates = await ref.read(templatesProvider(widget.entity.id).future);
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    final rates = await ref.read(taxRatesProvider.future);
    if (!mounted) return;
    final result = await showDialog<(EntryTemplate, int)>(
      context: context,
      builder: (_) => _TemplatePicker(templates: templates, initial: templates.where((t) => t.id == preselectedId).firstOrNull),
    );
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

  /// Reprend les comptes, tiers et sens d'une écriture passée (sans montants), après confirmation si la grille est déjà remplie.
  Future<void> _useSuggestedEntry(EntrySuggestion s) async {
    if (!await _confirmReplaceLines()) return;
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    if (!mounted) return;
    setState(() {
      _draft.lines
        ..clear()
        ..addAll([
          for (final l in s.lines)
            DraftLine(
              accountId: l.accountId,
              accountCode: l.accountCode,
              accountLabel: l.accountLabel,
              isCollective: accounts.where((a) => a.id == l.accountId).firstOrNull?.isCollective ?? l.thirdPartyId != null,
              thirdPartyId: l.thirdPartyId,
              thirdPartyCode: l.thirdPartyCode ?? '',
              label: l.label ?? '',
            ),
        ])
        ..add(DraftLine());
    });
  }

  /// Ouvre le sélecteur de modèle avec le modèle proposé déjà choisi.
  Future<void> _useSuggestedTemplate(TemplateSuggestion s) => _applyTemplate(preselectedId: s.templateId);

  /// Place le compte habituel sur la première ligne sans compte (une ligne est ajoutée si besoin).
  Future<void> _useSuggestedAccount(AccountSuggestion s) async {
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    if (!mounted) return;
    final account = accounts.where((a) => a.id == s.accountId).firstOrNull;
    setState(() {
      var line = _draft.lines.where((l) => l.accountId == null).firstOrNull;
      if (line == null) {
        line = DraftLine();
        _draft.lines.add(line);
      }
      line
        ..accountId = s.accountId
        ..accountCode = s.accountCode
        ..accountLabel = s.accountLabel
        ..isCollective = account?.isCollective ?? false;
    });
  }

  bool get _hasContent => _draft.lines.any((l) => l.accountId != null || l.debit > 0 || l.credit > 0);

  Future<bool> _confirmReplaceLines() async {
    if (!_hasContent) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AkDialog(
        title: 'Remplacer les lignes ?',
        size: AkDialogSize.s,
        content: const Text('Les lignes déjà saisies seront remplacées par celles de l\'écriture proposée (sans montants).'),
        actions: [
          AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx, false)),
          AkButton.primary('Remplacer', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Nouvelle ligne en fin de grille ; si l'écriture est déséquilibrée, la contrepartie est déjà proposée.
  void _appendLine() {
    final line = DraftLine();
    final gap = _draft.balance;
    if (gap > 0) line.credit = gap;
    if (gap < 0) line.debit = -gap;
    setState(() => _draft.lines.add(line));
    // Le focus passe au compte de la nouvelle ligne une fois celle-ci construite.
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusManager.instance.primaryFocus?.nextFocus());
  }

  Future<void> _showShortcuts() => showDialog<void>(context: context, builder: (_) => const _ShortcutsDialog());

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AkLoading();
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const []).where((j) => j.isActive).toList();
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canValidate = perms.has('entries.validate', entityId: widget.entity.id);
    final t = context.ak;
    final mobile = akIsCompact(context);
    final gutter = akPageMargin(context);
    final title = _loaded == null ? 'Nouvelle écriture' : 'Écriture ${_loaded!.numberLabel}';
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => setState(_draft.autoBalance),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _readOnly ? null : _save(),
        const SingleActivator(LogicalKeyboardKey.f1): _showShortcuts,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, AkSpace.s4, gutter, AkSpace.s4),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AkSpace.pageMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AkIconButton(tooltip: 'Retour à la liste', icon: Icons.arrow_back, onPressed: () => context.go('/saisie')),
                              const SizedBox(width: AkSpace.s1),
                              Expanded(
                                child: AkPageHead(
                                  title: title,
                                  subtitle: _readOnly ? 'Écriture validée : lecture seule' : 'Grille au clavier',
                                  actions: [
                                    if (!_readOnly) ...[
                                      AkButton.secondary('Modèle', icon: Icons.auto_fix_high_outlined, onPressed: _applyTemplate),
                                      AkButton.secondary('Contrepartie (Ctrl+B)', icon: Icons.balance, onPressed: () => setState(_draft.autoBalance)),
                                      if (_draft.id != null) AkButton.dangerOutline('Supprimer', icon: Icons.delete_outline, onPressed: _busy ? null : _delete),
                                    ],
                                    AkButton.ghost('Raccourcis (F1)', icon: Icons.keyboard_outlined, onPressed: _showShortcuts),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AkSpace.s3),
                          AkCard(
                            child: Wrap(
                              spacing: AkSpace.s3,
                              runSpacing: AkSpace.s3,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                SizedBox(
                                  width: mobile ? double.infinity : 240,
                                  child: AkDropdown<String>(
                                    key: const Key('entry-journal'),
                                    label: 'Journal',
                                    value: _draft.journalId,
                                    items: [for (final j in journals) AkOption(j.id, '${j.code} · ${j.label}')],
                                    onChanged: _readOnly ? null : (v) => setState(() => _draft.journalId = v),
                                  ),
                                ),
                                SizedBox(
                                  width: mobile ? double.infinity : 160,
                                  child: AkDateField(key: const Key('entry-date'), controller: _date, label: 'Date', enabled: !_readOnly),
                                ),
                                SizedBox(
                                  width: mobile ? double.infinity : 180,
                                  child: AkTextField(controller: _reference, label: 'Référence pièce', enabled: !_readOnly, mono: true),
                                ),
                                SizedBox(
                                  width: mobile ? double.infinity : 420,
                                  child: AkTextField(key: const Key('entry-label'), controller: _label, label: 'Libellé', enabled: !_readOnly),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _loaded != null
                                      ? AkStatusBadge(AkStatusBadge.of(status: _loaded!.status, reviewStatus: _loaded!.reviewStatus))
                                      : const AkStatusBadge(AkEntryStatus.draft),
                                ),
                              ],
                            ),
                          ),
                          EntrySuggestionsPanel(
                            entityId: widget.entity.id,
                            labelController: _label,
                            referenceController: _reference,
                            currentDraft: () => _draft,
                            enabled: !_readOnly && !_loading,
                            onUseEntry: _useSuggestedEntry,
                            onUseTemplate: _useSuggestedTemplate,
                            onUseAccount: _useSuggestedAccount,
                          ),
                          const SizedBox(height: AkSpace.s3),
                          AkCard(
                            padding: EdgeInsets.zero,
                            clip: true,
                            // Sur petit écran la grille défile horizontalement plutôt que de se comprimer.
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final withThird = _draft.lines.any((l) => l.isCollective);
                                final grid = Column(
                                  children: [
                                    _GridHeader(withThirdParty: withThird),
                                    for (var i = 0; i < _draft.lines.length; i++)
                                      _LineRow(
                                        key: ValueKey(_draft.lines[i]),
                                        index: i,
                                        line: _draft.lines[i],
                                        entityId: widget.entity.id,
                                        readOnly: _readOnly,
                                        withThirdParty: withThird,
                                        onChanged: () => setState(() {}),
                                        onRemove: _readOnly || _draft.lines.length <= 2 ? null : () => setState(() => _draft.lines.removeAt(i)),
                                        onEnterOnLast: i == _draft.lines.length - 1 ? _appendLine : null,
                                      ),
                                    // Pied de totaux : filet fort, montants alignés sur les colonnes Débit / Crédit.
                                    Container(
                                      decoration: BoxDecoration(
                                        color: t.surfaceSunken,
                                        border: Border(top: BorderSide(color: t.borderControl, width: 2)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: AkSpace.s2),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: _kIndexW),
                                          Expanded(
                                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2), child: Text('Totaux', style: AkText.tableHead.copyWith(color: t.textStrong))),
                                          ),
                                          const SizedBox(width: AkSpace.s2),
                                          SizedBox(
                                            width: _kAmountW,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                                              child: AkAmountText(Fmt.fcfa(_draft.totalDebit, showZero: true), bold: true),
                                            ),
                                          ),
                                          const SizedBox(width: AkSpace.s2),
                                          SizedBox(
                                            width: _kAmountW + AkSpace.s2,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                                              child: AkAmountText(Fmt.fcfa(_draft.totalCredit, showZero: true), bold: true),
                                            ),
                                          ),
                                          const SizedBox(width: _kRemoveW),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                final minWidth = AkEntryGridCols.minWidth(withThirdParty: withThird);
                                if (c.maxWidth >= minWidth) return AkEntryGridTheme(child: grid);
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(width: minWidth, child: AkEntryGridTheme(child: grid)),
                                );
                              },
                            ),
                          ),
                          if (!_readOnly)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: AkSpace.s2),
                                child: AkButton.ghost('Ligne', icon: Icons.add, onPressed: _appendLine),
                              ),
                            ),
                          if (_errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AkSpace.s3),
                              child: AkBanner(
                                kind: AkBannerKind.danger,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final message in _errors) Text('• $message')]),
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
                              child: Wrap(
                                spacing: AkSpace.s4,
                                runSpacing: AkSpace.s1,
                                children: [
                                  for (final (k, d) in const [
                                    ('Tab', 'cellule suivante'),
                                    ('Entrée', 'champ suivant ; en fin de ligne : nouvelle ligne'),
                                    ('Ctrl B', 'contrepartie'),
                                    ('Ctrl S', 'enregistrer le brouillard'),
                                    ('F1', 'tous les raccourcis'),
                                  ])
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AkKbd(k),
                                        const SizedBox(width: 6),
                                        Text(d, style: AkText.caption.copyWith(color: t.textMuted)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _BalanceBar(
              debit: _draft.totalDebit,
              credit: _draft.totalCredit,
              balance: _draft.balance,
              readOnly: _readOnly,
              busy: _busy,
              canValidate: canValidate,
              onSave: () => _save(),
              onValidate: () => _save(validate: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre fixe en bas de l'écran : totaux, équilibre de l'écriture (toujours visible) et actions d'enregistrement.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.debit,
    required this.credit,
    required this.balance,
    required this.readOnly,
    required this.busy,
    required this.canValidate,
    required this.onSave,
    required this.onValidate,
  });

  final int debit;
  final int credit;
  final int balance;
  final bool readOnly;
  final bool busy;
  final bool canValidate;
  final VoidCallback onSave;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final balanced = balance == 0;
    final color = balanced ? t.success : t.danger;
    final mobile = akIsCompact(context);
    Widget total(String label, int v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AkText.caption.copyWith(color: t.textMuted)),
        Text(Fmt.fcfa(v, showZero: true), style: AkText.amountTotal.copyWith(color: t.textStrong)),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: akPageMargin(context), vertical: AkSpace.s3),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Wrap(
        spacing: AkSpace.s4,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
        children: [
          if (!mobile) ...[total('Débit', debit), total('Crédit', credit)],
          Container(
            key: const Key('balance-chip'),
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s1),
            decoration: BoxDecoration(color: balanced ? t.successTint : t.dangerTint, borderRadius: AkRadius.smAll),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(balanced ? Icons.check_circle_outline : Icons.error_outline, size: AkSpace.iconMd, color: color),
                const SizedBox(width: AkSpace.s2),
                Text(
                  balanced ? 'Équilibrée' : 'Écart ${Fmt.fcfa(balance.abs())} · ${balance > 0 ? 'débit' : 'crédit'} supérieur',
                  style: AkText.bodyStrong.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (!readOnly) ...[
            AkButton.secondary('Enregistrer le brouillard', key: const Key('save-draft'), onPressed: busy ? null : onSave),
            if (canValidate)
              AkButton.primary('Valider l\'écriture', key: const Key('validate-entry'), onPressed: busy || !balanced ? null : onValidate),
          ],
        ],
      ),
    );
  }
}

/// Aide : raccourcis clavier de la grille de saisie (F1).
class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  static const _rows = [
    ('Tab / Maj+Tab', 'Cellule suivante / précédente'),
    ('Entrée', 'Passe au champ suivant ; dans une liste de comptes, choisit la proposition surlignée'),
    ('Entrée (dernier montant)', 'Nouvelle ligne, avec la contrepartie déjà proposée si l\'écriture est déséquilibrée'),
    ('↑ ↓', 'Parcourir les propositions de compte ou de tiers'),
    ('Ctrl B', 'Contrepartie automatique sur la première ligne vide'),
    ('Ctrl S', 'Enregistrer le brouillard'),
    ('F1', 'Afficher cette aide'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkDialog(
      title: 'Raccourcis clavier',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, d) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 190,
                    child: Align(alignment: Alignment.centerLeft, child: AkKbd(k)),
                  ),
                  Expanded(
                    child: Text(d, style: AkText.body.copyWith(color: t.text)),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [AkButton.primary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}

// Largeurs des colonnes de la grille, partagées par l'en-tête, les lignes et le pied de totaux.
const double _kIndexW = AkEntryGridCols.index;
const double _kAmountW = AkEntryGridCols.amount;
const double _kRemoveW = AkEntryGridCols.remove;

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.withThirdParty});

  final bool withThirdParty;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final style = AkText.tableHead.copyWith(color: t.textMuted);
    // Même marge interne que les cellules de saisie, pour aligner texte d'en-tête et contenu.
    const cellPad = EdgeInsets.symmetric(horizontal: AkSpace.s2);
    return Container(
      constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact),
      color: t.tableHead,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
      child: Row(
        children: [
          const SizedBox(width: _kIndexW),
          SizedBox(width: AkEntryGridCols.account, child: Padding(padding: cellPad, child: Text('Compte', style: style))),
          const SizedBox(width: AkSpace.s2),
          SizedBox(width: withThirdParty ? AkEntryGridCols.thirdParty : AkEntryGridCols.thirdPartyEmpty, child: Padding(padding: cellPad, child: Text('Tiers', style: style, overflow: TextOverflow.ellipsis))),
          const SizedBox(width: AkSpace.s2),
          Expanded(child: Padding(padding: cellPad, child: Text('Libellé', style: style))),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: _kAmountW,
            child: Padding(padding: cellPad, child: Text('D · Débit (FCFA)', style: style, textAlign: TextAlign.right)),
          ),
          const SizedBox(width: AkSpace.s2),
          Container(
            width: _kAmountW + AkSpace.s2,
            padding: const EdgeInsets.only(left: AkSpace.s2),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: t.border))),
            child: Padding(padding: cellPad, child: Text('C · Crédit (FCFA)', style: style, textAlign: TextAlign.right)),
          ),
          const SizedBox(width: _kRemoveW),
        ],
      ),
    );
  }
}

/// Une ligne de la grille : compte avec autocomplétion (numéro ou intitulé), tiers si collectif, libellé, débit, crédit.
class _LineRow extends ConsumerStatefulWidget {
  const _LineRow({
    super.key,
    required this.index,
    required this.line,
    required this.entityId,
    required this.readOnly,
    required this.withThirdParty,
    required this.onChanged,
    this.onRemove,
    this.onEnterOnLast,
  });

  final int index;
  final DraftLine line;
  final String entityId;
  final bool readOnly;
  final bool withThirdParty;
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
  bool _active = false;

  @override
  void dispose() {
    _label.dispose();
    _debit.dispose();
    _credit.dispose();
    super.dispose();
  }

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

  void _next() => FocusScope.of(context).nextFocus();

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entityId)).value ?? const <Account>[]).where((a) => a.isActive && a.allowPosting).toList();
    final thirdParties = (ref.watch(thirdPartiesProvider(widget.entityId)).value ?? const <ThirdParty>[]).where((t) => t.isActive).toList();
    final l = widget.line;
    final t = context.ak;
    final mobile = akIsTouch(context);
    // Ligne active : la ligne qui contient le focus prend `rowActive` ; la cellule active montre l'anneau de focus.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) => setState(() => _active = has),
      child: Container(
      constraints: BoxConstraints(minHeight: mobile ? AkSpace.rowTouch : AkSpace.controlDense + AkSpace.s1),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
      decoration: BoxDecoration(
        color: _active ? t.rowActive : null,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kIndexW,
            child: Text('${widget.index + 1}', style: AkText.caption.copyWith(color: t.textMuted)),
          ),
          SizedBox(
            width: AkEntryGridCols.account,
            child: AkAccountField(
              key: Key('line-account-${widget.index}'),
              accounts: accounts,
              dense: !mobile,
              enabled: !widget.readOnly,
              selected: l.accountCode.isEmpty
                  ? null
                  : Account(
                      id: l.accountId ?? '',
                      code: l.accountCode,
                      label: l.accountLabel,
                      classNo: 0,
                      normalSide: 'debit',
                      isCollective: l.isCollective,
                      isLetterable: false,
                      allowPosting: true,
                      isActive: true,
                    ),
              resolved: l.accountId != null,
              onSelected: (a) => _selectAccount(l, a),
              onCleared: () {
                if (l.accountId != null) {
                  l.accountId = null;
                  l.accountCode = '';
                  widget.onChanged();
                }
              },
              onSubmittedPick: _next,
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: widget.withThirdParty ? AkEntryGridCols.thirdParty : AkEntryGridCols.thirdPartyEmpty,
            child: l.isCollective
                ? AkThirdPartyField(
                    thirdParties: thirdParties,
                    dense: !mobile,
                    enabled: !widget.readOnly,
                    initialCode: l.thirdPartyCode,
                    resolved: l.thirdPartyId != null,
                    onSelected: (t) {
                      l.thirdPartyId = t.id;
                      l.thirdPartyCode = t.code;
                      widget.onChanged();
                    },
                    onSubmittedPick: _next,
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: AkSpace.s2),
                    child: Text('—', style: AkText.table.copyWith(color: t.borderControl)),
                  ),
          ),
          const SizedBox(width: AkSpace.s2),
          Expanded(
            child: AkTextField(
              controller: _label,
              dense: !mobile,
              enabled: !widget.readOnly,
              textInputAction: TextInputAction.next,
              onChanged: (v) => l.label = v,
              onSubmitted: (_) => _next(),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(width: _kAmountW, child: _amountField(_debit, (v) => l.debit = v, () => l.credit = 0, _credit)),
          const SizedBox(width: AkSpace.s2),
          const SizedBox(width: AkSpace.s2),
          Container(
            width: _kAmountW + AkSpace.s2,
            padding: const EdgeInsets.only(left: AkSpace.s2),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: t.border))),
            child: _amountField(_credit, (v) => l.credit = v, () => l.debit = 0, _debit, last: true),
          ),
          SizedBox(
            width: _kRemoveW,
            // Hors du parcours au clavier : Tab va de ligne en ligne sans s'arrêter sur la suppression.
            child: widget.onRemove == null
                ? null
                : ExcludeFocus(
                    child: AkIconButton(tooltip: 'Supprimer la ligne', icon: Icons.close, size: AkSpace.iconMd, dense: true, onPressed: widget.onRemove),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, void Function(int) set, VoidCallback clearOther, TextEditingController other, {bool last = false}) {
    return AkAmountField(
      controller: c,
      enabled: !widget.readOnly,
      dense: !akIsTouch(context),
      textInputAction: TextInputAction.next,
      onChanged: (n) {
        set(n);
        if (n > 0) {
          clearOther();
          other.clear();
        }
        widget.onChanged();
      },
      onSubmitted: (_) => last && widget.onEnterOnLast != null ? widget.onEnterOnLast!() : _next(),
    );
  }
}

class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker({required this.templates, this.initial});

  final List<EntryTemplate> templates;
  final EntryTemplate? initial;

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  late EntryTemplate? _template = widget.initial;
  final _amount = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final amount = Fmt.parseAmount(_amount.text);
    return AkDialog(
      title: 'Appliquer un modèle',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AkDropdown<EntryTemplate>(
            label: 'Modèle',
            value: _template,
            items: [for (final t in widget.templates) AkOption(t, '${t.code} — ${t.label}')],
            onChanged: (v) => setState(() => _template = v),
          ),
          const SizedBox(height: AkSpace.s3),
          AkAmountField(controller: _amount, label: 'Montant de base', onChanged: (_) => setState(() {})),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Appliquer',
          onPressed: _template == null || amount == null || amount <= 0 ? null : () => Navigator.pop(context, (_template!, amount)),
        ),
      ],
    );
  }
}
