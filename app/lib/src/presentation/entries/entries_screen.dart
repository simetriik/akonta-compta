import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entry_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entries_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

/// Liste des écritures du dossier courant : filtres journal / mois / statut, recherche, validation par lot,
/// file « à revoir » pour le chef de mission, contre-passation (§10.4).
class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _EntriesBody(entity: entity));
}

class _EntriesBody extends ConsumerStatefulWidget {
  const _EntriesBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_EntriesBody> createState() => _EntriesBodyState();
}

class _EntriesBodyState extends ConsumerState<_EntriesBody> {
  final Set<String> _selected = {};
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(entryFilterProvider);
    final entries = ref.watch(entriesListProvider(widget.entity.id));
    final journals = ref.watch(journalsProvider(widget.entity.id)).value ?? const [];
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canValidate = perms.has('entries.validate', entityId: widget.entity.id);
    final canReview = perms.has('entries.review', entityId: widget.entity.id);
    final canReverse = perms.has('entries.reverse', entityId: widget.entity.id);
    final month = filter.month ?? DateTime(DateTime.now().year, DateTime.now().month, 1);

    final t = context.ak;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final gutter = akPageMargin(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AkSpace.s4, gutter, AkSpace.s3),
            child: AkPageHead(
              title: 'Saisie',
              subtitle: 'Écritures du dossier courant',
              actions: [AkButton.primary('Nouvelle écriture', key: const Key('new-entry'), icon: Icons.add, onPressed: () => context.go('/saisie/nouvelle'))],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AkSpace.s4),
              child: AkCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _filters(context, filter, journals, month),
                    Divider(height: 1, color: t.border),
                    Expanded(
                      child: AsyncView(
                        value: entries,
                        onRetry: () => ref.invalidate(entriesListProvider(widget.entity.id)),
                        builder: (list) => list.isEmpty
                            ? const AkEmptyState('Aucune écriture pour ces critères.')
                            : _list(context, list, canValidate: canValidate, canReview: canReview, canReverse: canReverse, mobile: mobile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barre de filtres : journal, mois, statut, recherche.
  Widget _filters(BuildContext context, EntryFilter filter, List<Journal> journals, DateTime month) {
    final notifier = ref.read(entryFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(AkSpace.s3),
      child: Wrap(
        spacing: AkSpace.s3,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: AkDropdown<String?>(
              value: filter.journalId,
              hint: 'Tous les journaux',
              items: [const AkOption<String?>(null, 'Tous les journaux'), for (final j in journals) AkOption<String?>(j.id, '${j.code} · ${j.label}')],
              onChanged: (v) => notifier.set(v == null ? filter.copyWith(clearJournal: true) : filter.copyWith(journalId: v)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AkIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mois précédent',
                onPressed: () => notifier.set(filter.copyWith(month: DateTime(month.year, month.month - 1, 1))),
              ),
              Text(Fmt.month(month), style: AkText.bodyStrong.copyWith(color: context.ak.text)),
              AkIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mois suivant',
                onPressed: () => notifier.set(filter.copyWith(month: DateTime(month.year, month.month + 1, 1))),
              ),
              AkButton.ghost('Tout l\'exercice', onPressed: () => notifier.set(filter.copyWith(clearMonth: true))),
            ],
          ),
          AkSegmented<String>(
            options: const [AkOption('all', 'Toutes'), AkOption('draft', 'Brouillards'), AkOption('validated', 'Validées'), AkOption('review', 'À revoir')],
            selected: filter.toReviewOnly ? 'review' : (filter.status ?? 'all'),
            onChanged: (v) => notifier.set(
              EntryFilter(
                journalId: filter.journalId,
                month: filter.month,
                search: filter.search,
                status: v == 'all' || v == 'review' ? null : v,
                toReviewOnly: v == 'review',
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: AkTextField(
              controller: _search,
              hint: 'Montant, libellé, compte, tiers, n°',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffix: AkIconButton(
                icon: Icons.clear,
                tooltip: 'Effacer',
                size: 18,
                onPressed: () {
                  _search.clear();
                  notifier.set(filter.copyWith(search: ''));
                },
              ),
              onSubmitted: (v) => notifier.set(filter.copyWith(search: v)),
            ),
          ),
        ],
      ),
    );
  }

  /// Tableau des écritures, en-tête de colonnes, lignes de 32 px et barre de lot en pied.
  Widget _list(
    BuildContext context,
    List<EntryModel> list, {
    required bool canValidate,
    required bool canReview,
    required bool canReverse,
    required bool mobile,
  }) {
    final t = context.ak;
    final selectable = canValidate ? list.where((e) => e.isDraft).toList() : <EntryModel>[];
    final allSelected = selectable.isNotEmpty && selectable.every((e) => _selected.contains(e.id));
    final selectedTotal = list.where((e) => _selected.contains(e.id)).fold<int>(0, (sum, e) => sum + e.totalDebit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mobile)
          Container(
            height: AkSpace.rowCompact,
            color: t.surfaceSunken,
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
            child: DefaultTextStyle(
              style: AkText.label.copyWith(color: t.textMuted, letterSpacing: 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: selectable.isEmpty
                        ? null
                        : AkCheckbox(
                            dense: true,
                            value: allSelected,
                            onChanged: (_) => setState(() => allSelected ? _selected.clear() : _selected.addAll(selectable.map((e) => e.id))),
                          ),
                  ),
                  const SizedBox(width: 90, child: Text('Date')),
                  const SizedBox(width: 120, child: Text('N°')),
                  const Expanded(child: Text('Libellé')),
                  const SizedBox(width: 130, child: Text('Montant (FCFA)', textAlign: TextAlign.right)),
                  const SizedBox(width: AkSpace.s3),
                  const SizedBox(width: 110, child: Text('Statut')),
                  const SizedBox(width: 96),
                ],
              ),
            ),
          ),
        if (!mobile) Divider(height: 1, color: t.border),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: t.border),
            itemBuilder: (_, i) => _EntryTile(
              entry: list[i],
              selected: _selected.contains(list[i].id),
              mobile: mobile,
              onSelect: list[i].isDraft && canValidate ? (v) => setState(() => v ? _selected.add(list[i].id) : _selected.remove(list[i].id)) : null,
              onOpen: () => context.go('/saisie/${list[i].id}'),
              onReview: canReview && !list[i].isDraft ? () => _review(context, list[i]) : null,
              onReverse: canReverse && !list[i].isDraft && list[i].reversedBy == null ? () => _reverse(context, list[i]) : null,
            ),
          ),
        ),
        Divider(height: 1, color: t.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s2),
          child: Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_selected.isNotEmpty && canValidate) ...[
                Text('${_selected.length} brouillard(s) sélectionné(s)', style: AkText.bodyStrong.copyWith(color: t.text)),
                Text('Total ${Fmt.fcfa(selectedTotal, showZero: true)} FCFA', style: AkText.table.copyWith(color: t.textMuted)),
                AkButton.primary(
                  'Valider ${_selected.length} brouillard(s)',
                  key: const Key('validate-selected'),
                  icon: Icons.check,
                  onPressed: () => _validateSelected(context),
                ),
              ],
              Icon(Icons.auto_awesome, size: 14, color: t.textMuted),
              Text('Générée', style: AkText.caption.copyWith(color: t.textMuted)),
              Icon(Icons.undo, size: 14, color: t.textMuted),
              Text('Contre-passée', style: AkText.caption.copyWith(color: t.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _validateSelected(BuildContext context) async {
    try {
      await ref.read(entriesServiceProvider).validateMany(_selected.toList());
      if (context.mounted) showAkToast(context, '${_selected.length} écriture(s) validée(s).');
      setState(_selected.clear);
    } catch (e) {
      if (context.mounted) showAkToast(context, errorText(e), kind: AkToastKind.danger);
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
    ref.invalidate(entityDashboardProvider);
  }

  Future<void> _review(BuildContext context, EntryModel e) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => ReviewDialog(entry: e),
    );
    if (result == null) return;
    try {
      await ref.read(entriesServiceProvider).review(e.id, status: result.$1, comment: result.$2);
    } catch (err) {
      if (context.mounted) showAkToast(context, errorText(err), kind: AkToastKind.danger);
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
    ref.invalidate(entityDashboardProvider);
  }

  Future<void> _reverse(BuildContext context, EntryModel e) async {
    final result = await showDialog<(String, DateTime)>(
      context: context,
      builder: (_) => ReversalDialog(entry: e),
    );
    if (result == null) return;
    try {
      await ref.read(entriesServiceProvider).reverse(e.id, reason: result.$1, date: result.$2);
      if (context.mounted) showAkToast(context, 'Écriture contre-passée (écriture inverse validée).');
    } catch (err) {
      if (context.mounted) showAkToast(context, errorText(err), kind: AkToastKind.danger);
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.selected, required this.mobile, this.onSelect, required this.onOpen, this.onReview, this.onReverse});

  final EntryModel entry;
  final bool selected;
  final bool mobile;
  final ValueChanged<bool>? onSelect;
  final VoidCallback onOpen;
  final VoidCallback? onReview;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final status = AkStatusBadge(AkStatusBadge.of(status: entry.status, reviewStatus: entry.reviewStatus));
    final flags = [
      if (entry.isGenerated)
        Tooltip(
          message: 'Écriture générée',
          child: Icon(Icons.auto_awesome, size: 16, color: t.textMuted),
        ),
      if (entry.reversedBy != null)
        Tooltip(
          message: 'Contre-passée',
          child: Icon(Icons.undo, size: 16, color: t.textMuted),
        ),
    ];
    final menu = (onReview == null && onReverse == null)
        ? null
        : PopupMenuButton<String>(
            tooltip: 'Actions sur l\'écriture',
            iconSize: 18,
            onSelected: (v) => v == 'review' ? onReview?.call() : onReverse?.call(),
            itemBuilder: (_) => [
              if (onReview != null) const PopupMenuItem(value: 'review', child: Text('Revue…')),
              if (onReverse != null) const PopupMenuItem(value: 'reverse', child: Text('Contre-passer…')),
            ],
          );
    final comment = entry.reviewComment != null
        ? Padding(
            padding: const EdgeInsets.only(bottom: AkSpace.s2),
            child: Text('Revue : ${entry.reviewComment}', style: AkText.caption.copyWith(color: t.danger)),
          )
        : null;
    final check = onSelect == null ? const SizedBox(width: 40) : AkCheckbox(dense: true, value: selected, onChanged: onSelect);

    final Widget body;
    if (mobile) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AkSpace.rowTouch),
        child: Row(
          children: [
            check,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(Fmt.date(entry.entryDate), style: AkText.table.copyWith(color: t.textMuted)),
                        const SizedBox(width: AkSpace.s2),
                        Text(entry.numberLabel, style: AkText.code.copyWith(color: t.text)),
                        const Spacer(),
                        AkAmountText(Fmt.fcfa(entry.totalDebit, showZero: true)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.label,
                      style: AkText.table.copyWith(color: t.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AkSpace.s1),
                    Row(
                      children: [
                        status,
                        const SizedBox(width: AkSpace.s2),
                        ...flags,
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ?menu,
          ],
        ),
      );
    } else {
      body = SizedBox(
        height: AkSpace.rowCompact,
        child: Row(
          children: [
            check,
            SizedBox(
              width: 90,
              child: Text(Fmt.date(entry.entryDate), style: AkText.table.copyWith(color: t.text)),
            ),
            SizedBox(
              width: 120,
              child: Text(entry.numberLabel, style: AkText.code.copyWith(color: t.text)),
            ),
            Expanded(
              child: Text(
                entry.label,
                style: AkText.table.copyWith(color: t.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 130, child: AkAmountText(Fmt.fcfa(entry.totalDebit, showZero: true))),
            const SizedBox(width: AkSpace.s3),
            SizedBox(
              width: 110,
              child: Align(alignment: Alignment.centerLeft, child: status),
            ),
            SizedBox(
              width: 56,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: flags),
            ),
          ],
        ),
      );
    }
    return Material(
      color: selected ? t.rowSelected : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.only(left: AkSpace.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mobile)
                body
              else
                Row(
                  children: [
                    Expanded(child: body),
                    SizedBox(width: 40, child: menu),
                  ],
                ),
              ?(!mobile && comment != null ? Padding(padding: const EdgeInsets.only(left: 40), child: comment) : (mobile ? comment : null)),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key, required this.entry});

  final EntryModel entry;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  String _status = 'reviewed';
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Revue de ${widget.entry.numberLabel}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AkRadioGroup<String>(
            value: _status,
            onChanged: (v) => setState(() => _status = v),
            options: const [
              AkOption('reviewed', 'Revue, conforme'),
              AkOption('to_correct', 'À corriger (commentaire obligatoire)'),
              AkOption('not_reviewed', 'Remettre en « non revue »'),
            ],
          ),
          AkTextField(
            controller: _comment,
            key: const Key('review-comment'),
            label: 'Commentaire',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ), // active « Enregistrer » dès qu'un commentaire est saisi
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: _status == 'to_correct' && _comment.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_status, _comment.text.trim().isEmpty ? null : _comment.text.trim())),
        ),
      ],
    );
  }
}

class ReversalDialog extends StatefulWidget {
  const ReversalDialog({super.key, required this.entry});

  final EntryModel entry;

  @override
  State<ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<ReversalDialog> {
  final _reason = TextEditingController();
  final _date = TextEditingController(text: Fmt.date(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final date = Fmt.parseDate(_date.text);
    return AkDialog(
      title: 'Contre-passer ${widget.entry.numberLabel}',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AkBanner(kind: AkBannerKind.info, child: Text('Une écriture inverse, liée à l\'originale, est créée et validée dans une période ouverte.')),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _reason, key: const Key('reversal-reason'), label: 'Motif (obligatoire)', onChanged: (_) => setState(() {}), autofocus: true),
          const SizedBox(height: AkSpace.s3),
          AkDateField(controller: _date, label: 'Date (jj/mm/aaaa)', onChanged: (_) => setState(() {})),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Contre-passer',
          onPressed: _reason.text.trim().isEmpty || date == null ? null : () => Navigator.pop(context, (_reason.text.trim(), date)),
        ),
      ],
    );
  }
}
