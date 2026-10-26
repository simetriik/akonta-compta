import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';

/// Tableau de bord des dossiers : chef de mission, dernier mois saisi, brouillards, écritures non revues (§10.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(entityDashboardProvider);
    final pad = akPageMargin(context);
    return data.when(
      loading: () => const AkLoading(),
      error: (e, _) => AkErrorMessage('Erreur de chargement : $e', onRetry: () => ref.invalidate(entityDashboardProvider)),
      data: (entities) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(entityDashboardProvider),
        child: entities.isEmpty
            ? ListView(
                padding: EdgeInsets.all(pad),
                children: const [AkEmptyState('Aucun dossier ne vous est affecté.', icon: Icons.folder_off_outlined)],
              )
            : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  AkPageHead(
                    title: 'Mes dossiers',
                    subtitle: '${entities.length} dossier${entities.length > 1 ? 's' : ''} affecté${entities.length > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: AkSpace.s4),
                  _Totals(entities: entities),
                  const SizedBox(height: AkSpace.s6),
                  _CardGrid(entities: entities),
                ],
              ),
      ),
    );
  }
}

/// Totaux tous dossiers confondus (somme des compteurs de chaque dossier).
class _Totals extends StatelessWidget {
  const _Totals({required this.entities});

  final List<EntitySummary> entities;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    int sum(int Function(EntitySummary) f) => entities.fold(0, (a, e) => a + f(e));
    final items = [
      ('Brouillards', sum((e) => e.draftCount), t.statusDraft),
      ('Écritures non revues', sum((e) => e.unreviewedCount), t.statusReview),
      ('À corriger', sum((e) => e.toCorrectCount), t.statusFix),
      ('Pièces en attente', sum((e) => e.inboxCount), t.textMuted),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 4 : 2;
        const gap = AkSpace.s3;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, color) in items)
              SizedBox(
                width: w,
                child: AkCard(
                  padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Dot(color: color),
                          const SizedBox(width: AkSpace.s2),
                          Flexible(
                            child: Text(
                              label,
                              style: AkText.caption.copyWith(color: t.textMuted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AkSpace.s1),
                      Text(
                        '$value',
                        style: AkText.amount.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600, color: t.text),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.entities});

  final List<EntitySummary> entities;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
        const gap = AkSpace.s4;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final e in entities)
              SizedBox(
                width: w,
                child: DossierCard(entity: e),
              ),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class DossierCard extends ConsumerWidget {
  const DossierCard({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final selected = ref.watch(currentEntityProvider)?.id == entity.id;
    final status = entity.fiscalYearStatus;
    return AkCard(
      selected: selected,
      onTap: () => ref.read(currentEntityProvider.notifier).select(entity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(selected ? Icons.folder_open : Icons.folder_outlined, size: 20, color: selected ? t.brandText : t.textMuted),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entity.dossierLabel, style: AkText.heading.copyWith(color: t.text)),
                    if (entity.managerNames != null) Text('Chef de mission : ${entity.managerNames}', style: AkText.caption.copyWith(color: t.textMuted)),
                  ],
                ),
              ),
              if (status != null) ...[const SizedBox(width: AkSpace.s2), _FiscalYearBadge(status: status)],
            ],
          ),
          if (entity.lastEntryDate != null || selected) ...[
            const SizedBox(height: AkSpace.s2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entity.lastEntryDate == null ? '' : 'Dernière écriture : ${Fmt.date(entity.lastEntryDate)}',
                    style: AkText.caption.copyWith(color: t.textMuted),
                  ),
                ),
                if (selected) Text('Dossier courant', style: AkText.label.copyWith(color: t.brandText)),
              ],
            ),
          ],
          const SizedBox(height: AkSpace.s3),
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              _Counter(label: entity.draftCount > 1 ? 'brouillards' : 'brouillard', value: entity.draftCount, color: t.statusDraft, tint: t.statusDraftTint),
              _Counter(
                label: entity.unreviewedCount > 1 ? 'non revues' : 'non revue',
                value: entity.unreviewedCount,
                color: t.statusReview,
                tint: t.statusReviewTint,
              ),
              _Counter(label: 'à corriger', value: entity.toCorrectCount, color: t.statusFix, tint: t.statusFixTint),
              _Counter(
                label: entity.inboxCount > 1 ? 'pièces en attente' : 'pièce en attente',
                value: entity.inboxCount,
                color: t.textMuted,
                tint: t.surfaceSunken,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Statut de l'exercice du dossier : ouvert, en clôture ou clôturé.
class _FiscalYearBadge extends StatelessWidget {
  const _FiscalYearBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (label, color, tint, icon) = switch (status) {
      'open' => ('Exercice ouvert', t.statusDraft, t.statusDraftTint, Icons.edit_note),
      'closing' => ('Exercice en clôture', t.statusReview, t.statusReviewTint, Icons.hourglass_empty),
      'closed' => ('Exercice clôturé', t.textMuted, t.surfaceSunken, Icons.lock_outline),
      _ => ('Exercice $status', t.textMuted, t.surfaceSunken, Icons.info_outline),
    };
    return AkBadge(label: label, color: color, tint: tint, icon: icon);
  }
}

/// Compteur d'un dossier : pastille colorée si la valeur est non nulle, atténuée sinon.
class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color, required this.tint});

  final String label;
  final int value;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return value > 0 ? AkBadge(label: '$value $label', color: color, tint: tint) : AkBadge(label: '0 $label', color: t.textMuted, tint: Colors.transparent);
  }
}
