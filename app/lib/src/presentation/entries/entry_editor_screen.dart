import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entry_models.dart';
import '../../domain/suggestion_models.dart';
import 'entry_suggestions_panel.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entries_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../../application/offline/outbox_codec.dart';
import '../../application/providers/documents_providers.dart';
import '../../domain/documents_models.dart';
import '../documents/document_preview.dart';
import '../documents/documents_screen.dart' show DocumentViewer;
import 'entry_balance_bar.dart';
import 'entry_documents_panel.dart';
import 'entry_grid.dart';
import 'entry_header_fields.dart';
import 'entry_shortcuts_dialog.dart';
import 'entry_template_picker.dart';
import 'return_draft_dialog.dart';
import '../../application/entries/entry_editor_logic.dart';

/// Saisie d'une écriture (grille au clavier) : journal, date, référence, libellé ; lignes compte / tiers / libellé / débit / crédit ;
/// autocomplétion, contrepartie automatique (Ctrl+B), modèles d'écritures, équilibre affiché, validation (§10.4).
class EntryEditorScreen extends StatelessWidget {
  const EntryEditorScreen({super.key, this.entryId, this.documentId});

  final String? entryId;

  /// Pièce de départ (« Créer l'écriture depuis cette pièce ») : elle s'affiche à côté de la grille et se rattache à l'enregistrement.
  final String? documentId;

  @override
  Widget build(BuildContext context) => RequireEntity(
    builder: (entity) => _Editor(entity: entity, entryId: entryId, documentId: documentId),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.entity, this.entryId, this.documentId});

  final EntitySummary entity;
  final String? entryId;
  final String? documentId;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  EntryDraft _draft = EntryDraft();
  EntryModel? _loaded;
  bool _loading = true;
  bool _busy = false;
  bool _piecesOpen = false; // mobile : le bloc des pièces est replié pour laisser la place à la grille
  List<String> _errors = const [];
  String? _loadError;
  List<DocumentModel> _pending = const []; // pièces choisies pour une écriture pas encore enregistrée
  DocumentModel? _viewed; // pièce affichée à côté de la grille
  late final _date = TextEditingController(text: Fmt.date(_draft.entryDate));
  late final _reference = TextEditingController();
  late final _label = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.entryId != null) {
        final e = await ref.read(entriesServiceProvider).get(widget.entryId!);
        _loaded = e;
        _draft = EntryDraft.fromEntry(e);
        _date.text = Fmt.date(_draft.entryDate);
        _reference.text = _draft.reference;
        _label.text = _draft.label;
        if (_draft.lines.length < 2) _draft.lines.add(DraftLine());
      } else if (widget.documentId != null) {
        // Écriture créée depuis une pièce : on l'affiche et on la rattachera à l'enregistrement.
        final docs = await ref.read(documentsServiceProvider).list(widget.entity.id);
        final doc = docs.where((d) => d.id == widget.documentId).firstOrNull;
        if (doc != null) {
          _pending = [doc];
          _viewed = doc;
        }
      }
      _loadError = null;
    } catch (e) {
      _loadError = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Relance le chargement après un échec.
  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  /// Exécute une action asynchrone de l'éditeur et annonce l'erreur au lieu de la laisser remonter.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showAkToast(context, errorText(e), kind: AkToastKind.danger);
    }
  }

  bool get _readOnly => _loaded != null && !_loaded!.isDraft;

  Widget _withViewer(Widget? pane, Widget main) => pane == null
      ? main
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            const SizedBox(width: AkSpace.s4),
            SizedBox(width: 440, child: pane),
          ],
        );

  Future<void> _save({bool validate = false}) async {
    _draft.reference = _reference.text;
    _draft.label = _label.text;
    final d = Fmt.parseDate(_date.text);
    if (d == null) {
      setState(() => _errors = ['Date invalide (jj/mm/aaaa)']);
      return;
    }
    _draft.entryDate = d;
    final errors = EntryEditorLogic.errors(_draft, validate: validate);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    if (validate && !await _confirmWithoutDocument()) return;
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      final repo = ref.read(entriesServiceProvider);
      final id = await repo.saveDraft(cabinet!.id, widget.entity.id, _draft);
      _draft.id = id;
      await _attachPending(id);
      if (validate) {
        final n = await repo.validate(id);
        if (mounted) showAkToast(context, 'Écriture validée : n° $n');
      } else if (mounted) {
        showAkToast(
          context,
          isLocalDraftId(id) ? 'Hors connexion : brouillard conservé sur cet appareil, il sera envoyé à la reconnexion.' : 'Brouillard enregistré.',
          kind: isLocalDraftId(id) ? AkToastKind.info : AkToastKind.success,
        );
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

  /// Écriture sur le serveur : pièces à rattacher d'office (aucune pièce en attente pour un brouillon enregistré hors connexion).
  Future<void> _attachPending(String id) async {
    if (_pending.isEmpty || isLocalDraftId(id)) return;
    final failed = <String>[];
    for (final d in _pending) {
      try {
        await ref.read(documentsServiceProvider).attach(id, d.id);
      } catch (e) {
        failed.add('${d.fileName} : ${errorText(e)}');
      }
    }
    _pending = const [];
    ref.invalidate(documentsProvider(widget.entity.id));
    if (failed.isNotEmpty && mounted) showAkToast(context, 'Pièce non rattachée :\n${failed.join('\n')}', kind: AkToastKind.warning);
  }

  /// Avertissement non bloquant à la validation sans pièce justificative (réglable par cabinet, D-040).
  Future<bool> _confirmWithoutDocument() async {
    final cabinet = await ref.read(currentCabinetProvider.future);
    if (cabinet == null || !cabinet.warnMissingDocument) return true;
    var count = _pending.length;
    final id = _draft.id ?? widget.entryId;
    if (id != null && !isLocalDraftId(id)) {
      try {
        count += (await ref.read(documentsServiceProvider).forEntry(id)).length;
      } catch (_) {
        return true; // hors connexion ou lecture impossible : on ne bloque pas la validation
      }
    }
    if (count > 0 || !mounted) return true;
    return showAkConfirm(
      context,
      title: 'Aucune pièce jointe',
      message: 'Cette écriture n\'a pas de pièce justificative (facture, reçu, relevé). La valider quand même ? Une écriture validée ne se modifie plus.',
      confirmLabel: 'Valider quand même',
    );
  }

  /// Affiche la pièce à côté de la grille sur grand écran, dans une fenêtre sinon.
  void _view(DocumentModel d) {
    if (MediaQuery.sizeOf(context).width >= _viewerBreakpoint) {
      setState(() => _viewed = d);
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => DocumentViewer(document: d),
      );
    }
  }

  static const _viewerBreakpoint = 1180.0;

  Widget _viewerPane(BuildContext context, DocumentModel d) {
    final t = context.ak;
    return AkCard(
      key: const Key('document-pane'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AkText.bodyStrong.copyWith(color: t.text),
                ),
              ),
              AkIconButton(
                key: const Key('document-pane-close'),
                icon: Icons.close,
                tooltip: 'Fermer l\'aperçu',
                dense: true,
                onPressed: () => setState(() => _viewed = null),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          DocumentPreview(document: d, height: 560),
        ],
      ),
    );
  }

  Future<void> _returnToClient() async {
    if (await showReturnDraftDialog(context, ref, _loaded!.id) && mounted) context.go('/saisie');
  }

  Future<void> _delete() async {
    if (_draft.id == null) return;
    await ref.read(entriesServiceProvider).deleteDraft(_draft.id!);
    ref.invalidate(entriesListProvider(widget.entity.id));
    if (mounted) context.go('/saisie');
  }

  Future<void> _applyTemplate({String? preselectedId}) => _guard(() => _applyTemplateNow(preselectedId));

  Future<void> _applyTemplateNow(String? preselectedId) async {
    final templates = await ref.read(templatesProvider(widget.entity.id).future);
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    final rates = await ref.read(taxRatesProvider.future);
    if (!mounted) return;
    final result = await showDialog<(EntryTemplate, int)>(
      context: context,
      builder: (_) => EntryTemplatePicker(templates: templates, initial: templates.where((t) => t.id == preselectedId).firstOrNull),
    );
    if (result == null) return;
    final (template, amount) = result;
    setState(() {
      EntryEditorLogic.applyTemplateTo(_draft, template, baseAmount: amount, accounts: accounts, rates: rates, today: DateTime.now());
      if (_label.text.isEmpty) _label.text = template.label;
    });
  }

  /// Reprend les comptes, tiers et sens d'une écriture passée (sans montants), après confirmation si la grille est déjà remplie.
  Future<void> _useSuggestedEntry(EntrySuggestion s) => _guard(() => _useSuggestedEntryNow(s));

  Future<void> _useSuggestedEntryNow(EntrySuggestion s) async {
    if (!await _confirmReplaceLines()) return;
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    if (!mounted) return;
    setState(() => EntryEditorLogic.useSuggestedEntry(_draft, s, accounts));
  }

  /// Ouvre le sélecteur de modèle avec le modèle proposé déjà choisi.
  Future<void> _useSuggestedTemplate(TemplateSuggestion s) => _applyTemplate(preselectedId: s.templateId);

  /// Place le compte habituel sur la première ligne sans compte (une ligne est ajoutée si besoin).
  Future<void> _useSuggestedAccount(AccountSuggestion s) => _guard(() => _useSuggestedAccountNow(s));

  Future<void> _useSuggestedAccountNow(AccountSuggestion s) async {
    final accounts = await ref.read(accountsProvider(widget.entity.id).future);
    if (!mounted) return;
    setState(() => EntryEditorLogic.useSuggestedAccount(_draft, s, accounts));
  }

  Future<bool> _confirmReplaceLines() async {
    if (!EntryEditorLogic.hasContent(_draft)) return true;
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
    setState(() => EntryEditorLogic.appendLine(_draft));
    // Le focus passe au compte de la nouvelle ligne une fois celle-ci construite.
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusManager.instance.primaryFocus?.nextFocus());
  }

  /// Identifiant de l'écriture si elle existe déjà côté serveur (pas un brouillon local en attente d'envoi).
  String? get _savedEntryId {
    final id = _draft.id ?? widget.entryId;
    return id != null && !isLocalDraftId(id) ? id : null;
  }

  /// Nombre de pièces jointes, affiché sur la ligne repliable du mobile.
  int get _documentCount {
    final id = _savedEntryId;
    return id == null ? _pending.length : (ref.watch(entryDocumentsProvider(id)).value?.length ?? 0);
  }

  Future<void> _showShortcuts() => showDialog<void>(context: context, builder: (_) => const EntryShortcutsDialog());

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AkLoading();
    if (_loadError != null) return AkErrorMessage(_loadError!, onRetry: _retryLoad);
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const []).where((j) => j.isActive).toList();
    // Nouvelle écriture : journal d'opérations diverses (à défaut, le premier) proposé d'office.
    if (_loaded == null && _draft.journalId == null && journals.isNotEmpty) {
      _draft.journalId = journals.firstWhere((j) => j.code == 'OD', orElse: () => journals.first).id;
    }
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canValidate = perms.has('entries.validate', entityId: widget.entity.id);
    final mobile = akIsCompact(context);
    final gutter = akPageMargin(context);
    final title = _loaded == null ? 'Nouvelle écriture' : 'Écriture ${_loaded!.numberLabel}';
    final showViewer = _viewed != null && MediaQuery.sizeOf(context).width >= _viewerBreakpoint;
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
                      constraints: BoxConstraints(maxWidth: AkSpace.pageMaxWidth + (showViewer ? 460 : 0)),
                      child: _withViewer(
                        showViewer ? _viewerPane(context, _viewed!) : null,
                        Column(
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
                                    subtitle: _readOnly ? 'Écriture validée : lecture seule' : (mobile ? null : 'Grille au clavier'),
                                    actions: mobile
                                        ? const []
                                        : [
                                            if (!_readOnly) ...[
                                              AkButton.secondary('Modèle', icon: Icons.auto_fix_high_outlined, onPressed: _applyTemplate),
                                              AkButton.secondary('Contrepartie (Ctrl+B)', icon: Icons.balance, onPressed: () => setState(_draft.autoBalance)),
                                              if (_draft.id != null)
                                                AkButton.dangerOutline('Supprimer', icon: Icons.delete_outline, onPressed: _busy ? null : _delete),
                                            ],
                                            AkButton.ghost('Raccourcis (F1)', icon: Icons.keyboard_outlined, onPressed: _showShortcuts),
                                          ],
                                  ),
                                ),
                              ],
                            ),
                            if (mobile && !_readOnly)
                              EntryMobileActions(
                                onTemplate: _applyTemplate,
                                onBalance: () => setState(_draft.autoBalance),
                                onDelete: _draft.id != null && !_busy ? _delete : null,
                                canDelete: _draft.id != null,
                              ),
                            const SizedBox(height: AkSpace.s3),
                            AkCard(
                              child: mobile
                                  ? EntryMobileHeaderFields(
                                      journals: journals,
                                      journalId: _draft.journalId,
                                      onJournal: (v) => setState(() => _draft.journalId = v),
                                      date: _date,
                                      reference: _reference,
                                      label: _label,
                                      readOnly: _readOnly,
                                      status: _loaded != null
                                          ? AkStatusBadge.of(status: _loaded!.status, reviewStatus: _loaded!.reviewStatus)
                                          : AkEntryStatus.draft,
                                    )
                                  : Wrap(
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
                            if (mobile) EntryDocumentsToggle(count: _documentCount, open: _piecesOpen, onTap: () => setState(() => _piecesOpen = !_piecesOpen)),
                            if (!mobile || _piecesOpen)
                              EntryDocumentsPanel(
                                entityId: widget.entity.id,
                                entryId: _savedEntryId,
                                pending: _pending,
                                onPendingChanged: (list) => setState(() => _pending = list),
                                onView: _view,
                                viewedId: _viewed?.id,
                                canAttach: perms.has('documents.attach', entityId: widget.entity.id),
                                canDetach: !_readOnly,
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
                                      EntryGridHeader(withThirdParty: withThird),
                                      for (var i = 0; i < _draft.lines.length; i++)
                                        EntryLineRow(
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
                                      EntryGridTotals(debit: _draft.totalDebit, credit: _draft.totalCredit),
                                    ],
                                  );
                                  final minWidth = AkEntryGridCols.minWidth(withThirdParty: withThird);
                                  if (c.maxWidth >= minWidth) return AkEntryGridTheme(child: grid);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const EntryScrollHint(),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: minWidth,
                                          child: AkEntryGridTheme(child: grid),
                                        ),
                                      ),
                                    ],
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
                            DraftReturnArea(
                              entry: _loaded,
                              canReturn: canValidate && widget.entity.clientAccess != 'disabled' && _loaded?.createdBy != ref.watch(currentUserIdProvider),
                              onReturn: _returnToClient,
                            ),
                            if (!_readOnly && !mobile) const EntryShortcutHints(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            EntryBalanceBar(
              debit: _draft.totalDebit,
              credit: _draft.totalCredit,
              balance: _draft.balance,
              readOnly: _readOnly,
              busy: _busy,
              canValidate: canValidate,
              incomplete: _draft.hasLineWithoutAccount,
              onSave: () => _save(),
              onValidate: () => _save(validate: true),
            ),
          ],
        ),
      ),
    );
  }
}
