import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/closing_models.dart';
import '../../domain/entry_models.dart';
import '../../application/providers/entries_providers.dart';
import '../../application/rules/closing_check_text.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';

class ChecksStep extends ConsumerStatefulWidget {
  const ChecksStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<ChecksStep> createState() => _ChecksStepState();
}

class _ChecksStepState extends ConsumerState<ChecksStep> {
  late Future<List<ClosingCheck>> _future = ref.read(closingServiceProvider).runChecks(widget.entity.id, widget.fy.id);

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canWaive = perms.has('closing.override_alerts', entityId: widget.entity.id);
    return FutureBuilder<List<ClosingCheck>>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasError) return AkErrorMessage(errorText(snap.error!));
        if (!snap.hasData) return const AkLoading();
        final checks = snap.data!;
        final blocking = checks.where((c) => c.status == 'failed' && c.severity == 'blocking').length;
        return ListView(
          padding: closingBodyPadding(context),
          children: [
            AkSectionTitle(
              'Contrôles de clôture',
              trailing: AkButton.secondary(
                'Relancer',
                icon: Icons.refresh,
                onPressed: () => setState(() => _future = ref.read(closingServiceProvider).runChecks(widget.entity.id, widget.fy.id)),
              ),
            ),
            const SizedBox(height: AkSpace.s3),
            if (blocking > 0) ...[
              AkBanner(
                kind: AkBannerKind.danger,
                icon: Icons.block,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$blocking contrôle${blocking > 1 ? 's bloquants empêchent' : ' bloquant empêche'}', style: AkText.bodyStrong),
                      const TextSpan(text: ' de prononcer la clôture. Les alertes peuvent être levées avec un commentaire.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AkSpace.s3),
            ],
            closingRowsCard(context, [for (final c in checks) _checkRow(context, c, canWaive)]),
          ],
        );
      },
    );
  }

  /// Ouvre l'écran où corriger le contrôle ; les filtres de la saisie sont posés avant l'ouverture.
  void _open(ClosingCheckTarget target) {
    final filters = ref.read(entryFilterProvider.notifier);
    switch (target) {
      case ClosingCheckTarget.draftEntries:
        filters.set(const EntryFilter(status: 'draft'));
        context.go('/saisie');
      case ClosingCheckTarget.entriesToCorrect:
        filters.set(const EntryFilter(reviewStatus: 'to_correct'));
        context.go('/saisie');
      case ClosingCheckTarget.entriesToReview:
        filters.set(const EntryFilter(toReviewOnly: true));
        context.go('/saisie');
      case ClosingCheckTarget.periods:
        context.go('/dossiers/${widget.entity.id}');
      case ClosingCheckTarget.reconciliation:
        context.go('/rapprochement');
      case ClosingCheckTarget.inventory:
        context.go('/inventaire');
      case ClosingCheckTarget.references:
        context.go('/referentiels');
      case ClosingCheckTarget.consultation:
        context.go('/consultation');
    }
  }

  Widget _checkRow(BuildContext context, ClosingCheck c, bool canWaive) {
    final t = context.ak;
    final passed = c.status == 'passed';
    final waived = c.status == 'waived';
    final blocking = c.severity == 'blocking';
    final (icon, color) = passed
        ? (Icons.check_circle, t.success)
        : (waived ? (Icons.remove_circle_outline, t.info) : (blocking ? (Icons.cancel, t.danger) : (Icons.warning_amber, t.warning)));
    final badge = passed
        ? AkBadge(label: 'Conforme', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
        : waived
        ? AkBadge(label: 'Levée', color: t.info, tint: t.infoTint, icon: Icons.remove_circle_outline)
        : blocking
        ? AkBadge(label: 'Bloquant', color: t.danger, tint: t.dangerTint, icon: Icons.block)
        : AkBadge(label: 'Alerte', color: t.warning, tint: t.warningTint, icon: Icons.warning_amber);
    final action = ClosingCheckText.action(c);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AkSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label, style: AkText.bodyStrong.copyWith(color: t.text)),
                Text(ClosingCheckText.subtitle(c), style: AkText.caption.copyWith(color: t.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (action != null) AkButton.secondary(action.label, dense: true, onPressed: () => _open(action.target)),
              badge,
              if (c.status == 'failed' && c.severity == 'warning' && canWaive)
                AkButton.secondary(
                  'Lever l\'alerte',
                  dense: true,
                  onPressed: () async {
                    final comment = await askText(context, title: 'Lever : ${c.label}', label: 'Commentaire (obligatoire)', confirmLabel: 'Lever l\'alerte');
                    if (comment == null || comment.trim().isEmpty) return;
                    try {
                      await ref.read(closingServiceProvider).waive(widget.fy.id, c.code, comment.trim());
                    } catch (e) {
                      if (context.mounted) showErrorSnack(context, errorText(e));
                    }
                    setState(() => _future = ref.read(closingServiceProvider).runChecks(widget.entity.id, widget.fy.id));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
