import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';

/// Tableau de bord des dossiers : chef de mission, dernier mois saisi, brouillards, écritures non revues (§10.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(entityDashboardProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur de chargement : $e')),
      data: (entities) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(entityDashboardProvider),
        child: entities.isEmpty
            ? const Center(child: Text('Aucun dossier ne vous est affecté.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Mes dossiers', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final e in entities) DossierCard(entity: e),
                ],
              ),
      ),
    );
  }
}

class DossierCard extends ConsumerWidget {
  const DossierCard({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currentEntityProvider)?.id == entity.id;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? AkColors.terracotta : AkColors.sandDark),
      ),
      child: ListTile(
        onTap: () => ref.read(currentEntityProvider.notifier).select(entity),
        title: Text(entity.dossierLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (entity.managerNames != null) 'Chef de mission : ${entity.managerNames}',
          if (entity.lastEntryDate != null) 'Dernière écriture : ${Fmt.date(entity.lastEntryDate)}',
          if (entity.fiscalYearStatus != null) 'Exercice ${_status(entity.fiscalYearStatus!)}',
        ].join(' · ')),
        trailing: Wrap(
          spacing: 8,
          children: [
            _Counter(label: 'brouillards', value: entity.draftCount, color: AkColors.draft),
            _Counter(label: 'non revues', value: entity.unreviewedCount, color: AkColors.reviewed),
            _Counter(label: 'à corriger', value: entity.toCorrectCount, color: AkColors.toCorrect),
            _Counter(label: 'pièces en attente', value: entity.inboxCount, color: AkColors.ink),
          ],
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: TextStyle(color: value > 0 ? color : AkColors.ink.withValues(alpha: 0.4), fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
