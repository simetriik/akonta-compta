import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/entities_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../widgets/error_display.dart';

/// Un dossier « vide » d'après le tableau de bord : aucune écriture, aucun brouillard, aucune pièce en attente.
/// Garde d'affichage seulement : la base refuse de toute façon dès qu'il contient une donnée (tiers, import, facture…).
bool looksEmpty(EntitySummary s) =>
    s.lastEntryDate == null && s.draftCount == 0 && s.unreviewedCount == 0 && s.toCorrectCount == 0 && s.inboxCount == 0;

/// Outil de reprise après une double création : supprime le dossier s'il est encore vide. La base refuse dès qu'il
/// contient une écriture, une pièce, un tiers, un import, etc. ; il n'y a alors rien à faire d'autre que l'archiver.
class DuplicateEntityButton extends ConsumerStatefulWidget {
  const DuplicateEntityButton({super.key, required this.entity});

  final EntityDetail entity;

  @override
  ConsumerState<DuplicateEntityButton> createState() => _DuplicateEntityButtonState();
}

class _DuplicateEntityButtonState extends ConsumerState<DuplicateEntityButton> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showAkConfirm(
      context,
      title: 'Supprimer ce dossier en double ?',
      message: 'Le dossier « ${widget.entity.name} » sera supprimé définitivement. C\'est possible uniquement tant qu\'il est vide (aucune écriture, pièce, tiers ni import). Cette action est irréversible.',
      confirmLabel: 'Supprimer le dossier',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(entitiesServiceProvider).deleteEmptyDuplicate(widget.entity.id);
      if (ref.read(currentEntityProvider)?.id == widget.entity.id) ref.read(currentEntityProvider.notifier).select(null);
      ref.invalidate(entitiesListProvider);
      ref.invalidate(entityDashboardProvider);
      if (!mounted) return;
      showAkToast(context, 'Dossier supprimé.');
      context.go('/dossiers');
    } catch (e) {
      if (mounted) showError(context, e, action: 'Suppression impossible');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(permissionsProvider).value?.has('entities.manage', entityId: widget.entity.id) ?? false;
    // Le bouton n'a de sens que sur un dossier encore vide : sur un dossier en service il serait trompeur.
    final summary = ref.watch(entityDashboardProvider).value?.where((e) => e.id == widget.entity.id).firstOrNull;
    if (!canManage || summary == null || !looksEmpty(summary)) return const SizedBox.shrink();
    return AkButton.dangerOutline(
      'Supprimer ce doublon',
      key: const Key('delete-duplicate-entity'),
      icon: Icons.delete_outline,
      loading: _busy,
      loadingLabel: 'Suppression en cours…',
      onPressed: _delete,
    );
  }
}
