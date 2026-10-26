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
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur de chargement : $e')),
      data: (entities) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(entityDashboardProvider),
        child: entities.isEmpty
            ? const Center(child: Text('Aucun dossier ne vous est affecté.'))
            : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  AkPageHead(title: 'Mes dossiers', subtitle: '${entities.length} dossier${entities.length > 1 ? 's' : ''} affecté${entities.length > 1 ? 's' : ''}'),
                  const SizedBox(height: AkSpace.s4),
                  _Totals(entities: entities),
                  const SizedBox(height: AkSpace.s4),
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
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (label, value, color) in items)
          SizedBox(
            width: w,
            child: AkCard(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _Dot(color: color),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, style: AkText.caption.copyWith(color: t.textMuted), overflow: TextOverflow.ellipsis)),
                ]),
                Text('$value', style: AkText.amount.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: t.text)),
              ]),
            ),
          ),
      ]);
    });
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.entities});

  final List<EntitySummary> entities;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final e in entities) SizedBox(width: w, child: DossierCard(entity: e)),
      ]);
    });
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class DossierCard extends ConsumerWidget {
  const DossierCard({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final selected = ref.watch(currentEntityProvider)?.id == entity.id;
    final meta = [
      if (entity.lastEntryDate != null) 'Dernière écriture : ${Fmt.date(entity.lastEntryDate)}',
      if (entity.fiscalYearStatus != null) 'Exercice ${_status(entity.fiscalYearStatus!)}',
    ].join(' · ');
    return InkWell(
      borderRadius: AkRadius.lgAll,
      onTap: () => ref.read(currentEntityProvider.notifier).select(entity),
      child: AkCard(
        selected: selected,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(selected ? Icons.folder_open : Icons.folder_outlined, size: 20, color: selected ? t.brandText : t.textMuted),
            const SizedBox(width: AkSpace.s2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entity.dossierLabel, style: AkText.heading.copyWith(color: t.text)),
                if (entity.managerNames != null) Text('Chef de mission : ${entity.managerNames}', style: AkText.caption.copyWith(color: t.textMuted)),
              ]),
            ),
          ]),
          if (meta.isNotEmpty || selected) ...[
            const SizedBox(height: AkSpace.s2),
            Row(children: [
              Expanded(child: Text(meta, style: AkText.caption.copyWith(color: t.textMuted))),
              if (selected) Text('Dossier courant', style: AkText.label.copyWith(color: t.brandText)),
            ]),
          ],
          const SizedBox(height: AkSpace.s3),
          Row(children: [
            _Counter(label: 'brouillards', value: entity.draftCount, color: t.statusDraft),
            _Counter(label: 'non revues', value: entity.unreviewedCount, color: t.statusReview),
            _Counter(label: 'à corriger', value: entity.toCorrectCount, color: t.statusFix),
            _Counter(label: 'pièces en attente', value: entity.inboxCount, color: t.textMuted),
          ]),
        ]),
      ),
    );
  }

  String _status(String s) => switch (s) {
        'open' => 'ouvert',
        'closing' => 'en clôture',
        'closed' => 'clôturé',
        _ => s,
      };
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Expanded(
      child: Opacity(
        opacity: value > 0 ? 1 : 0.55,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: AkText.amount.copyWith(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: t.text)),
          Row(children: [
            _Dot(color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: AkText.caption.copyWith(color: t.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
          ]),
        ]),
      ),
    );
  }
}
