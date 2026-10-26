import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/entities_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entity_models.dart';
import '../widgets/async_view.dart';
import '../widgets/ak_widgets.dart';
import 'entity_form.dart';

/// Dossier : fiche, dirigeants, exercices et périodes (verrouillage), historique.
class EntityDetailScreen extends ConsumerWidget {
  const EntityDetailScreen({super.key, required this.entityId});

  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(entityProvider(entityId));
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return AsyncView(
      value: entity,
      onRetry: () => ref.invalidate(entityProvider(entityId)),
      builder: (e) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
              child: AkPageHead(
                title: e.name,
                subtitle: (e.taxId == null || e.taxId!.isEmpty) ? null : 'IFU ${e.taxId}',
              ),
            ),
            const SizedBox(height: AkSpace.s2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: const Align(alignment: Alignment.centerLeft, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Fiche'), Tab(text: 'Dirigeants'), Tab(text: 'Exercices et périodes'), Tab(text: 'Historique')])),
            ),
            Expanded(
              child: TabBarView(children: [
                _FicheTab(entity: e),
                _DirectorsTab(entity: e),
                FiscalYearsTab(entity: e),
                _HistoryTab(entityId: e.id),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FicheTab extends ConsumerWidget {
  const _FicheTab({required this.entity});

  final EntityDetail entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider).value;
    final fys = ref.watch(fiscalYearsProvider(entity.id)).value ?? const [];
    return EntityForm(
      initial: entity,
      canEditAccountingParams: perms?.has('cabinet.settings') ?? false,
      accountLengthLocked: fys.isNotEmpty,
      onSubmit: (input) async {
        await ref.read(entitiesRepositoryProvider).update(entity.id, input);
        ref.invalidate(entityProvider(entity.id));
        ref.invalidate(entitiesListProvider);
        ref.invalidate(entityDashboardProvider);
        ref.invalidate(entityHistoryProvider(entity.id));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      },
    );
  }
}

class _DirectorsTab extends ConsumerWidget {
  const _DirectorsTab({required this.entity});

  final EntityDetail entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directors = ref.watch(directorsProvider(entity.id));
    final t = context.ak;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return AsyncView(
      value: directors,
      builder: (list) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          Row(children: [
            Expanded(child: Text('Dirigeants et membres du conseil (R3)', style: AkText.heading.copyWith(color: t.text))),
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => DirectorDialog(entity: entity)),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Ajouter'),
            ),
          ]),
          const SizedBox(height: AkSpace.s3),
          AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.border),
                ListTile(
                  title: Text(list[i].fullName, style: AkText.bodyStrong.copyWith(color: t.text)),
                  subtitle: Text([list[i].position, if (list[i].nationality != null) list[i].nationality!, if (list[i].isBoardMember) 'membre du CA'].join(' · '), style: AkText.caption.copyWith(color: t.textMuted)),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(entitiesRepositoryProvider).removeDirector(list[i].id);
                      ref.invalidate(directorsProvider(entity.id));
                    },
                  ),
                ),
              ],
              if (list.isEmpty) const Padding(padding: EdgeInsets.all(AkSpace.s4), child: Text('Aucun dirigeant renseigné.')),
            ]),
            ),
          ),
        ],
      ),
    );
  }
}

class DirectorDialog extends ConsumerStatefulWidget {
  const DirectorDialog({super.key, required this.entity});

  final EntityDetail entity;

  @override
  ConsumerState<DirectorDialog> createState() => _DirectorDialogState();
}

class _DirectorDialogState extends ConsumerState<DirectorDialog> {
  final _name = TextEditingController();
  final _position = TextEditingController();
  final _nationality = TextEditingController();
  final _address = TextEditingController();
  bool _board = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dirigeant'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom complet'), autofocus: true),
          const SizedBox(height: 8),
          TextField(controller: _position, decoration: const InputDecoration(labelText: 'Qualité (gérant, PDG, administrateur…)')),
          const SizedBox(height: 8),
          TextField(controller: _nationality, decoration: const InputDecoration(labelText: 'Nationalité')),
          const SizedBox(height: 8),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
          CheckboxListTile(value: _board, onChanged: (v) => setState(() => _board = v ?? false), title: const Text('Membre du conseil d\'administration')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().length < 2 || _position.text.trim().isEmpty) return;
            await ref.read(entitiesRepositoryProvider).addDirector(widget.entity.cabinetId, widget.entity.id,
                fullName: _name.text.trim(), position: _position.text.trim(), nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
                address: _address.text.trim().isEmpty ? null : _address.text.trim(), board: _board);
            ref.invalidate(directorsProvider(widget.entity.id));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

/// Exercices (statut, capital, effectif, associés) et grille des 12 périodes avec verrouillage.
class FiscalYearsTab extends ConsumerWidget {
  const FiscalYearsTab({super.key, required this.entity});

  final EntityDetail entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fys = ref.watch(fiscalYearsProvider(entity.id));
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return AsyncView(
      value: fys,
      builder: (list) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('new-fiscal-year'),
              onPressed: () => showDialog(context: context, builder: (_) => FiscalYearDialog(entity: entity, previous: fys.value?.lastOrNull)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel exercice'),
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          for (final fy in list.reversed) _FiscalYearCard(entity: entity, fiscalYear: fy),
          if (list.isEmpty) const Text('Aucun exercice : créez le premier.'),
        ],
      ),
    );
  }
}

class _FiscalYearCard extends ConsumerWidget {
  const _FiscalYearCard({required this.entity, required this.fiscalYear});

  final EntityDetail entity;
  final FiscalYear fiscalYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(periodsProvider(fiscalYear.id));
    final perms = ref.watch(permissionsProvider).value;
    final canUnlock = perms?.has('cabinet.settings') ?? false;
    final canLock = canUnlock || (entity.monthlyLockEnabled && (perms?.has('closing.provisional', entityId: entity.id) ?? false));
    final t = context.ak;
    final (color, tint, icon) = switch (fiscalYear.status) {
      'open' => (t.statusDraft, t.statusDraftTint, Icons.edit_note),
      'closing' => (t.statusReview, t.statusReviewTint, Icons.hourglass_empty),
      _ => (t.textMuted, t.surfaceSunken, Icons.lock_outline),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: AkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AkSpace.s3, runSpacing: AkSpace.s1, children: [
              Text('Exercice ${fiscalYear.label}', style: AkText.heading.copyWith(color: t.text)),
              AkBadge(label: fiscalYear.statusLabel, color: color, tint: tint, icon: icon),
              Text('du ${Fmt.date(fiscalYear.startDate)} au ${Fmt.date(fiscalYear.endDate)}', style: AkText.table.copyWith(color: t.textMuted)),
            ]),
            if (fiscalYear.capital != null || fiscalYear.headcount != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text([
                if (fiscalYear.capital != null) 'Capital ${Fmt.fcfa(fiscalYear.capital, showZero: true)} FCFA',
                if (fiscalYear.headcount != null) 'Effectif ${fiscalYear.headcount}',
              ].join(' · '), style: AkText.table.copyWith(color: t.textMuted)),
            ],
            const SizedBox(height: AkSpace.s3),
            periods.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Périodes : $e'),
              data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Périodes · ${list.where((p) => p.isLocked).length} mois verrouillés sur ${list.length}', style: AkText.caption.copyWith(color: t.textMuted)),
                const SizedBox(height: AkSpace.s2),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in list)
                      FilterChip(
                        key: Key('period-${p.periodNo}'),
                        label: Text(Fmt.month(p.startDate)),
                        avatar: Icon(p.isLocked ? Icons.lock : Icons.lock_open, size: 16),
                        selected: p.isLocked,
                        onSelected: (fiscalYear.status != 'open' || (p.isLocked ? !canUnlock : !canLock))
                            ? null
                            : (lock) => _toggle(context, ref, p, lock),
                      ),
                  ],
                ),
                const SizedBox(height: AkSpace.s2),
                Row(children: [
                  Icon(Icons.info_outline, size: 14, color: t.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Déverrouillage réservé à l\'associé, avec motif obligatoire, consigné dans la piste d\'audit.', style: AkText.caption.copyWith(color: t.textMuted))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Period p, bool lock) async {
    final repo = ref.read(entitiesRepositoryProvider);
    try {
      if (lock) {
        await repo.lockPeriod(p.id);
      } else {
        final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
        if (reason == null || reason.trim().isEmpty) return;
        await repo.unlockPeriod(p.id, reason.trim());
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refusé : $e')));
    }
    ref.invalidate(periodsProvider(fiscalYear.id));
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Motif du déverrouillage'),
      content: TextField(controller: _c, autofocus: true, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Déverrouiller')),
      ],
    );
  }
}

/// Création d'un exercice : dates (12 mois sauf premier), capital, effectif.
class FiscalYearDialog extends ConsumerStatefulWidget {
  const FiscalYearDialog({super.key, required this.entity, this.previous, this.onCreated});

  final EntityDetail entity;
  final FiscalYear? previous;
  final void Function(FiscalYear fy)? onCreated;

  @override
  ConsumerState<FiscalYearDialog> createState() => _FiscalYearDialogState();
}

class _FiscalYearDialogState extends ConsumerState<FiscalYearDialog> {
  late final _start = TextEditingController(text: widget.previous == null ? '01/01/${DateTime.now().year}' : Fmt.date(widget.previous!.endDate.add(const Duration(days: 1))));
  late final _end = TextEditingController(text: widget.previous == null ? '31/12/${DateTime.now().year}' : '31/12/${widget.previous!.endDate.year + 1}');
  final _capital = TextEditingController();
  final _headcount = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    final start = Fmt.parseDate(_start.text);
    final end = Fmt.parseDate(_end.text);
    if (start == null || end == null) {
      setState(() => _error = 'Dates au format jj/mm/aaaa');
      return;
    }
    final v = validateFiscalYearDates(start: start, end: end, previousEnd: widget.previous?.endDate);
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    try {
      final fy = await ref.read(entitiesRepositoryProvider).createFiscalYear(widget.entity.cabinetId, widget.entity.id,
          start: start, end: end, capital: Fmt.parseAmount(_capital.text), headcount: int.tryParse(_headcount.text.trim()));
      ref.invalidate(fiscalYearsProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
      widget.onCreated?.call(fy);
      if (mounted) Navigator.pop(context, fy);
    } catch (e) {
      setState(() => _error = 'Refusé : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.previous == null ? 'Premier exercice' : 'Exercice suivant'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: _start, key: const Key('fy-start'), decoration: const InputDecoration(labelText: 'Début'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _end, key: const Key('fy-end'), decoration: const InputDecoration(labelText: 'Fin'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _capital, decoration: const InputDecoration(labelText: 'Capital (FCFA)'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _headcount, decoration: const InputDecoration(labelText: 'Effectif'), keyboardType: TextInputType.number)),
          ]),
          if (widget.previous == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Le premier exercice peut être plus court ou plus long que 12 mois ; il se termine un 31 décembre.', style: AkText.caption.copyWith(color: context.ak.textMuted))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('fy-error'), style: AkText.body.copyWith(color: context.ak.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(key: const Key('fy-submit'), onPressed: _submit, child: const Text('Créer')),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.entityId});

  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(entityHistoryProvider(entityId));
    final t = context.ak;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return AsyncView(
      value: history,
      builder: (items) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          for (final h in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s2),
              child: AkCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Fmt.date(h.changedAt), style: AkText.bodyStrong.copyWith(color: t.text)),
                  const SizedBox(height: AkSpace.s1),
                  Text([for (final e in h.changes.entries) '${e.key} : ${(e.value as Map)['old'] ?? '—'} → ${(e.value as Map)['new'] ?? '—'}'].join('\n'), style: AkText.table.copyWith(color: t.textMuted)),
                ]),
              ),
            ),
          if (items.isEmpty) const Text('Aucune modification enregistrée.'),
        ],
      ),
    );
  }
}
