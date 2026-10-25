import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/entries_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entry_models.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../widgets/status_chip.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-entry'),
        onPressed: () => context.go('/saisie/nouvelle'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle écriture'),
      ),
      body: Column(children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  value: filter.journalId,
                  hint: const Text('Tous les journaux'),
                  items: [const DropdownMenuItem(value: null, child: Text('Tous les journaux')), for (final j in journals) DropdownMenuItem(value: j.id, child: Text('${j.code} · ${j.label}'))],
                  onChanged: (v) => ref.read(entryFilterProvider.notifier).set(v == null ? filter.copyWith(clearJournal: true) : filter.copyWith(journalId: v)),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(entryFilterProvider.notifier).set(filter.copyWith(month: DateTime(month.year, month.month - 1, 1)))),
                  Text(Fmt.month(month), style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => ref.read(entryFilterProvider.notifier).set(filter.copyWith(month: DateTime(month.year, month.month + 1, 1)))),
                  TextButton(onPressed: () => ref.read(entryFilterProvider.notifier).set(filter.copyWith(clearMonth: true)), child: const Text('Tout l\'exercice')),
                ]),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'all', label: Text('Toutes')), ButtonSegment(value: 'draft', label: Text('Brouillards')), ButtonSegment(value: 'validated', label: Text('Validées')), ButtonSegment(value: 'review', label: Text('À revoir'))],
                  selected: {filter.toReviewOnly ? 'review' : (filter.status ?? 'all')},
                  onSelectionChanged: (s) {
                    final v = s.first;
                    ref.read(entryFilterProvider.notifier).set(EntryFilter(journalId: filter.journalId, month: filter.month, search: filter.search, status: v == 'all' || v == 'review' ? null : v, toReviewOnly: v == 'review'));
                  },
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Montant, libellé, compte, tiers, n°', suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _search.clear();
                      ref.read(entryFilterProvider.notifier).set(filter.copyWith(search: ''));
                    })),
                    onSubmitted: (v) => ref.read(entryFilterProvider.notifier).set(filter.copyWith(search: v)),
                  ),
                ),
                if (_selected.isNotEmpty && canValidate)
                  FilledButton.icon(
                    key: const Key('validate-selected'),
                    onPressed: () => _validateSelected(context),
                    icon: const Icon(Icons.check),
                    label: Text('Valider ${_selected.length} brouillard(s)'),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: entries,
            onRetry: () => ref.invalidate(entriesListProvider(widget.entity.id)),
            builder: (list) => list.isEmpty
                ? const Center(child: Text('Aucune écriture pour ces critères.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _EntryTile(
                      entry: list[i],
                      selected: _selected.contains(list[i].id),
                      onSelect: list[i].isDraft && canValidate ? (v) => setState(() => v ? _selected.add(list[i].id) : _selected.remove(list[i].id)) : null,
                      onOpen: () => context.go('/saisie/${list[i].id}'),
                      onReview: canReview && !list[i].isDraft ? () => _review(context, list[i]) : null,
                      onReverse: canReverse && !list[i].isDraft && list[i].reversedBy == null ? () => _reverse(context, list[i]) : null,
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _validateSelected(BuildContext context) async {
    try {
      await ref.read(entriesRepositoryProvider).validateMany(_selected.toList());
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selected.length} écriture(s) validée(s).')));
      setState(_selected.clear);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchEntryError(e)), backgroundColor: AkColors.toCorrect));
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
    ref.invalidate(entityDashboardProvider);
  }

  Future<void> _review(BuildContext context, EntryModel e) async {
    final result = await showDialog<(String, String?)>(context: context, builder: (_) => ReviewDialog(entry: e));
    if (result == null) return;
    try {
      await ref.read(entriesRepositoryProvider).review(e.id, status: result.$1, comment: result.$2);
    } catch (err) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchEntryError(err))));
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
    ref.invalidate(entityDashboardProvider);
  }

  Future<void> _reverse(BuildContext context, EntryModel e) async {
    final result = await showDialog<(String, DateTime)>(context: context, builder: (_) => ReversalDialog(entry: e));
    if (result == null) return;
    try {
      await ref.read(entriesRepositoryProvider).reverse(e.id, reason: result.$1, date: result.$2);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Écriture contre-passée (écriture inverse validée).')));
    } catch (err) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchEntryError(err)), backgroundColor: AkColors.toCorrect));
    }
    ref.invalidate(entriesListProvider(widget.entity.id));
  }
}

String frenchEntryError(Object e) {
  final m = e.toString();
  final match = RegExp(r'message: ([^,}]+)').firstMatch(m);
  return match?.group(1) ?? m;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.selected, this.onSelect, required this.onOpen, this.onReview, this.onReverse});

  final EntryModel entry;
  final bool selected;
  final ValueChanged<bool>? onSelect;
  final VoidCallback onOpen;
  final VoidCallback? onReview;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: onSelect == null ? const SizedBox(width: 40) : Checkbox(value: selected, onChanged: (v) => onSelect!(v ?? false)),
      title: Row(children: [
        SizedBox(width: 90, child: Text(Fmt.date(entry.entryDate))),
        SizedBox(width: 110, child: Text(entry.numberLabel, style: const TextStyle(fontFamily: 'monospace'))),
        Expanded(child: Text(entry.label, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 120, child: Text(Fmt.fcfa(entry.totalDebit, showZero: true), textAlign: TextAlign.right)),
        const SizedBox(width: 12),
        StatusChip(StatusChip.of(status: entry.status, reviewStatus: entry.reviewStatus)),
        if (entry.isGenerated) const Padding(padding: EdgeInsets.only(left: 6), child: Tooltip(message: 'Écriture générée', child: Icon(Icons.auto_awesome, size: 16))),
        if (entry.reversedBy != null) const Padding(padding: EdgeInsets.only(left: 6), child: Tooltip(message: 'Contre-passée', child: Icon(Icons.undo, size: 16))),
      ]),
      subtitle: entry.reviewComment != null ? Text('Revue : ${entry.reviewComment}', style: const TextStyle(color: AkColors.toCorrect)) : null,
      onTap: onOpen,
      trailing: (onReview == null && onReverse == null)
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) => v == 'review' ? onReview?.call() : onReverse?.call(),
              itemBuilder: (_) => [
                if (onReview != null) const PopupMenuItem(value: 'review', child: Text('Revue…')),
                if (onReverse != null) const PopupMenuItem(value: 'reverse', child: Text('Contre-passer…')),
              ],
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
    return AlertDialog(
      title: Text('Revue de ${widget.entry.numberLabel}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioGroup<String>(
          groupValue: _status,
          onChanged: (v) => setState(() => _status = v ?? 'reviewed'),
          child: const Column(children: [
            RadioListTile(value: 'reviewed', title: Text('Revue, conforme')),
            RadioListTile(value: 'to_correct', title: Text('À corriger (commentaire obligatoire)')),
            RadioListTile(value: 'not_reviewed', title: Text('Remettre en « non revue »')),
          ]),
        ),
        TextField(controller: _comment, key: const Key('review-comment'), decoration: const InputDecoration(labelText: 'Commentaire'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _status == 'to_correct' && _comment.text.trim().isEmpty ? null : () => Navigator.pop(context, (_status, _comment.text.trim().isEmpty ? null : _comment.text.trim())),
          child: const Text('Enregistrer'),
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
    return AlertDialog(
      title: Text('Contre-passer ${widget.entry.numberLabel}'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Une écriture inverse, liée à l\'originale, est créée et validée dans une période ouverte.'),
          const SizedBox(height: 8),
          TextField(controller: _reason, key: const Key('reversal-reason'), decoration: const InputDecoration(labelText: 'Motif (obligatoire)'), onChanged: (_) => setState(() {}), autofocus: true),
          const SizedBox(height: 8),
          TextField(controller: _date, decoration: const InputDecoration(labelText: 'Date (jj/mm/aaaa)'), onChanged: (_) => setState(() {})),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty || date == null ? null : () => Navigator.pop(context, (_reason.text.trim(), date)),
          child: const Text('Contre-passer'),
        ),
      ],
    );
  }
}
