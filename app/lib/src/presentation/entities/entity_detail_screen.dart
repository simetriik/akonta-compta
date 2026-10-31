import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../widgets/error_display.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../widgets/async_view.dart';
import 'entity_form.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

/// Dossier : fiche, dirigeants, exercices et périodes (verrouillage), historique.
class EntityDetailScreen extends ConsumerWidget {
  const EntityDetailScreen({super.key, required this.entityId});

  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(entityProvider(entityId));
    final pad = akPageMargin(context);
    return AsyncView(
      value: entity,
      onRetry: () => ref.invalidate(entityProvider(entityId)),
      builder: (e) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
              child: AkPageHead(title: e.name, subtitle: (e.taxId == null || e.taxId!.isEmpty) ? null : 'IFU ${e.taxId}'),
            ),
            const SizedBox(height: AkSpace.s2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Fiche'),
                    Tab(text: 'Dirigeants'),
                    Tab(text: 'Exercices et périodes'),
                    Tab(text: 'Historique'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _FicheTab(entity: e),
                  _DirectorsTab(entity: e),
                  FiscalYearsTab(entity: e),
                  _HistoryTab(entityId: e.id),
                ],
              ),
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
        await ref.read(entitiesServiceProvider).update(entity.id, input);
        ref.invalidate(entityProvider(entity.id));
        ref.invalidate(entitiesListProvider);
        ref.invalidate(entityDashboardProvider);
        ref.invalidate(entityHistoryProvider(entity.id));
        if (context.mounted) showAkToast(context, 'Fiche enregistrée.');
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
    final pad = akPageMargin(context);
    return AsyncView(
      value: directors,
      builder: (list) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          AkSectionTitle(
            'Dirigeants et membres du conseil (R3)',
            trailing: AkButton.primary(
              'Ajouter',
              icon: Icons.person_add_alt,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DirectorDialog(entity: entity),
              ),
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          if (list.isEmpty)
            const AkEmptyState('Aucun dirigeant renseigné.', icon: Icons.groups_outlined)
          else
            AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: AkTable<Director>(
                rows: list,
                minWidth: 560,
                columns: [
                  AkColumn<Director>.text(label: 'Nom', flex: 3, text: (d) => d.fullName),
                  AkColumn<Director>.text(label: 'Qualité', flex: 2, text: (d) => d.position),
                  AkColumn<Director>.text(label: 'Nationalité', flex: 2, text: (d) => d.nationality ?? ''),
                  AkColumn<Director>.text(label: 'Conseil', flex: 2, text: (d) => d.isBoardMember ? 'membre du CA' : ''),
                  AkColumn<Director>(
                    label: '',
                    width: 56,
                    cell: (context, d) => AkIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Retirer',
                      dense: true,
                      onPressed: () async {
                        await ref.read(entitiesServiceProvider).removeDirector(d.id);
                        ref.invalidate(directorsProvider(entity.id));
                      },
                    ),
                  ),
                ],
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
    return AkDialog(
      title: 'Dirigeant',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(controller: _name, label: 'Nom complet', autofocus: true),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _position, label: 'Qualité (gérant, PDG, administrateur…)'),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _nationality, label: 'Nationalité'),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _address, label: 'Adresse'),
          const SizedBox(height: AkSpace.s2),
          AkCheckbox(value: _board, onChanged: (v) => setState(() => _board = v), label: 'Membre du conseil d\'administration'),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Ajouter',
          onPressed: () async {
            if (_name.text.trim().length < 2 || _position.text.trim().isEmpty) return;
            await ref
                .read(entitiesServiceProvider)
                .addDirector(
                  widget.entity.cabinetId,
                  widget.entity.id,
                  fullName: _name.text.trim(),
                  position: _position.text.trim(),
                  nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
                  address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                  board: _board,
                );
            ref.invalidate(directorsProvider(widget.entity.id));
            if (context.mounted) Navigator.pop(context);
          },
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
    final pad = akPageMargin(context);
    return AsyncView(
      value: fys,
      builder: (list) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AkButton.primary(
              'Nouvel exercice',
              key: const Key('new-fiscal-year'),
              icon: Icons.add,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => FiscalYearDialog(entity: entity, previous: fys.value?.lastOrNull),
              ),
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          for (final fy in list.reversed) _FiscalYearCard(entity: entity, fiscalYear: fy),
          if (list.isEmpty) const AkEmptyState('Aucun exercice : créez le premier.', icon: Icons.event_outlined),
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AkSpace.s3,
              runSpacing: AkSpace.s1,
              children: [
                Text('Exercice ${fiscalYear.label}', style: AkText.heading.copyWith(color: t.text)),
                AkBadge(label: fiscalYear.statusLabel, color: color, tint: tint, icon: icon),
                Text('du ${Fmt.date(fiscalYear.startDate)} au ${Fmt.date(fiscalYear.endDate)}', style: AkText.table.copyWith(color: t.textMuted)),
              ],
            ),
            if (fiscalYear.capital != null || fiscalYear.headcount != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text(
                [
                  if (fiscalYear.capital != null) 'Capital ${Fmt.fcfa(fiscalYear.capital, showZero: true)} FCFA',
                  if (fiscalYear.headcount != null) 'Effectif ${fiscalYear.headcount}',
                ].join(' · '),
                style: AkText.table.copyWith(color: t.textMuted),
              ),
            ],
            const SizedBox(height: AkSpace.s3),
            periods.when(
              loading: () => const AkLoading(),
              error: (e, _) => AkErrorMessage(errorText(e, action: 'Périodes')),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Périodes · ${list.where((p) => p.isLocked).length} mois verrouillés sur ${list.length}',
                    style: AkText.caption.copyWith(color: t.textMuted),
                  ),
                  const SizedBox(height: AkSpace.s2),
                  Wrap(
                    spacing: AkSpace.s2,
                    runSpacing: AkSpace.s2,
                    children: [
                      for (final p in list)
                        FilterChip(
                          key: Key('period-${p.periodNo}'),
                          label: Text(Fmt.month(p.startDate)),
                          avatar: Icon(p.isLocked ? Icons.lock : Icons.lock_open, size: 16),
                          selected: p.isLocked,
                          onSelected: (fiscalYear.status != 'open' || (p.isLocked ? !canUnlock : !canLock)) ? null : (lock) => _toggle(context, ref, p, lock),
                        ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s2),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: t.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Déverrouillage réservé à l\'associé, avec motif obligatoire, consigné dans la piste d\'audit.',
                          style: AkText.caption.copyWith(color: t.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Period p, bool lock) async {
    final repo = ref.read(entitiesServiceProvider);
    try {
      if (lock) {
        await repo.lockPeriod(p.id);
      } else {
        final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
        if (reason == null || reason.trim().isEmpty) return;
        await repo.unlockPeriod(p.id, reason.trim());
      }
    } catch (e) {
      if (context.mounted) showError(context, e, action: 'Refusé');
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
    return AkDialog(
      title: 'Motif du déverrouillage',
      content: AkTextField(controller: _c, label: 'Motif (obligatoire)', required: true, autofocus: true),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Déverrouiller', onPressed: () => Navigator.pop(context, _c.text)),
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
  late final _start = TextEditingController(
    text: widget.previous == null ? '01/01/${DateTime.now().year}' : Fmt.date(widget.previous!.endDate.add(const Duration(days: 1))),
  );
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
      final fy = await ref
          .read(entitiesServiceProvider)
          .createFiscalYear(
            widget.entity.cabinetId,
            widget.entity.id,
            start: start,
            end: end,
            capital: Fmt.parseAmount(_capital.text),
            headcount: int.tryParse(_headcount.text.trim()),
          );
      ref.invalidate(fiscalYearsProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
      widget.onCreated?.call(fy);
      if (mounted) Navigator.pop(context, fy);
    } catch (e) {
      setState(() => _error = errorText(e, action: 'Refusé'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: widget.previous == null ? 'Premier exercice' : 'Exercice suivant',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkDateField(key: const Key('fy-start'), controller: _start, label: 'Début'),
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: AkDateField(key: const Key('fy-end'), controller: _end, label: 'Fin'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _capital, label: 'Capital (FCFA)', showCurrency: false),
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: AkTextField(controller: _headcount, label: 'Effectif', keyboardType: TextInputType.number),
              ),
            ],
          ),
          if (widget.previous == null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: Text(
                'Le premier exercice peut être plus court ou plus long que 12 mois ; il se termine un 31 décembre.',
                style: AkText.caption.copyWith(color: context.ak.textMuted),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: AkBanner(
                kind: AkBannerKind.danger,
                child: Text(_error!, key: const Key('fy-error')),
              ),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Créer', key: const Key('fy-submit'), onPressed: _submit),
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
    final pad = akPageMargin(context);
    return AsyncView(
      value: history,
      builder: (items) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          for (final h in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s2),
              child: AkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.date(h.changedAt), style: AkText.bodyStrong.copyWith(color: t.text)),
                    const SizedBox(height: AkSpace.s1),
                    Text(
                      [for (final e in h.changes.entries) '${e.key} : ${(e.value as Map)['old'] ?? '—'} → ${(e.value as Map)['new'] ?? '—'}'].join('\n'),
                      style: AkText.table.copyWith(color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          if (items.isEmpty) const AkEmptyState('Aucune modification enregistrée.', icon: Icons.history),
        ],
      ),
    );
  }
}
