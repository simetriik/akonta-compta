import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../../application/providers/session_providers.dart';
import 'client_home_screen.dart';

/// Tableau de bord des dossiers : chef de mission, dernier mois saisi, brouillards, écritures non revues (§10.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Un client du cabinet a son propre accueil : jamais le tableau de bord du personnel.
    if (ref.watch(permissionsProvider).value?.isClient ?? false) return const ClientHomeScreen();
    final data = ref.watch(entityDashboardProvider);
    final pad = akPageMargin(context);
    return data.when(
      skipLoadingOnReload: true,
      loading: () => const AkLoading(),
      error: (e, _) => AkErrorMessage(errorText(e, action: 'Chargement impossible'), onRetry: () => ref.invalidate(entityDashboardProvider)),
      data: (entities) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(entityDashboardProvider),
        child: entities.isEmpty
            ? ListView(
                padding: EdgeInsets.all(pad),
                children: [_NoEntity(perms: ref.watch(permissionsProvider).value ?? PermissionSet.empty)],
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
    int sum(int Function(EntitySummary) f) => entities.fold(0, (a, e) => a + f(e));
    final items = [
      ('Brouillards', sum((e) => e.draftCount), false, Icons.edit_outlined),
      ('Écritures non revues', sum((e) => e.unreviewedCount), false, Icons.fact_check_outlined),
      ('À corriger', sum((e) => e.toCorrectCount), true, Icons.error_outline),
      ('Pièces en attente', sum((e) => e.inboxCount), false, Icons.receipt_long_outlined),
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
            for (final (label, value, problem, icon) in items)
              SizedBox(
                width: w,
                child: AkStat(label: label, value: '$value', icon: icon, problem: problem && value > 0),
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
      onTap: () {
        // Ouvrir un dossier = le rendre courant puis afficher sa fiche.
        ref.read(currentEntityProvider.notifier).select(entity);
        context.go('/dossiers/${entity.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(selected ? Icons.folder_open : Icons.folder_outlined, size: 20, color: selected ? t.textStrong : t.textMuted),
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
              if (status != null) ...[const SizedBox(width: AkSpace.s2), FiscalYearBadge(status: status)],
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
                if (selected) Text('Dossier courant', style: AkText.label.copyWith(color: t.textStrong)),
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
class FiscalYearBadge extends StatelessWidget {
  const FiscalYearBadge({super.key, required this.status});

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

/// Aucun dossier : dit quoi faire selon le rôle (créer le premier dossier, créer les comptes, ou demander une affectation).
class _NoEntity extends StatelessWidget {
  const _NoEntity({required this.perms});

  final PermissionSet perms;

  @override
  Widget build(BuildContext context) {
    if (perms.has('entities.manage')) {
      return AkEmptyState(
        'Aucun dossier pour l\'instant. L\'assistant d\'ouverture vous guide en cinq étapes.',
        icon: Icons.create_new_folder_outlined,
        title: 'Bienvenue dans Akonta',
        action: AkButton.primary('Créer le premier dossier', key: const Key('first-entity'), icon: Icons.add, onPressed: () => context.go('/dossiers/nouveau')),
      );
    }
    if (perms.has('users.manage')) {
      return AkEmptyState(
        'Créez les comptes de l\'équipe en commençant par l\'associé gérant : il ouvrira ensuite les dossiers et donnera leurs rôles aux autres.',
        icon: Icons.group_add_outlined,
        title: 'Bienvenue dans Akonta',
        action: AkButton.primary('Gérer les collaborateurs', key: const Key('first-users'), icon: Icons.manage_accounts_outlined, onPressed: () => context.go('/utilisateurs')),
      );
    }
    // Aucun rôle du tout (compte créé par import CSV, par exemple) : la demande d'affectation à un dossier serait trompeuse.
    if (perms.roles.isEmpty) {
      return const AkEmptyState(
        'Aucun rôle ne vous est attribué. Demandez à l\'administrateur technique du cabinet de vous en donner un (par exemple « Désigner comme associé »).',
        icon: Icons.admin_panel_settings_outlined,
        title: 'Compte sans rôle',
      );
    }
    return const AkEmptyState(
      'Aucun dossier ne vous est affecté. Demandez à l\'associé ou au chef de mission de vous affecter à un dossier.',
      icon: Icons.folder_off_outlined,
    );
  }
}
