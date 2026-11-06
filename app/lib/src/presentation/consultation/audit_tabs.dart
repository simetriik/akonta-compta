import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/consultation_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../core/formatting.dart';
import '../../domain/consultation_models.dart';
import '../widgets/async_view.dart';

/// Contrôles automatiques de l'exercice : soldes anormaux et écritures hors période. Ils signalent, ils ne bloquent rien.
class ControlsTab extends ConsumerWidget {
  const ControlsTab({super.key, required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    return AsyncView(
      value: ref.watch(accountingControlsProvider(params)),
      onRetry: () => ref.invalidate(accountingControlsProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucune anomalie détectée sur cet exercice (soldes anormaux, écritures hors période).', icon: Icons.verified_outlined);
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return AkListRow(
              leading: Icon(Icons.warning_amber_rounded, color: t.statusReview),
              title: Text(c.title, style: AkText.bodyStrong.copyWith(color: t.text)),
              subtitle: Text(c.text, style: AkText.table.copyWith(color: t.textMuted)),
              // Une anomalie sur une écriture ouvre cette écriture ; une anomalie de solde n'a pas de cible unique.
              onTap: c.entryId == null ? null : () => context.go('/saisie/${c.entryId}'),
              trailing: c.entryId == null ? null : Icon(Icons.chevron_right, color: t.textMuted),
            );
          },
        );
      },
    );
  }
}

/// Piste d'audit des écritures du dossier sur la période : qui a saisi, modifié, validé, et quand.
class AuditTrailTab extends ConsumerWidget {
  const AuditTrailTab({super.key, required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value;
    if (!(perms?.has('audit.read', entityId: params.entityId) ?? false) && !(perms?.has('audit.read') ?? false)) {
      return const AkEmptyState('La piste d\'audit est réservée aux associés, aux chefs de mission et aux auditeurs affectés au dossier.', icon: Icons.lock_outline);
    }
    return AsyncView(
      value: ref.watch(entryAuditTrailProvider(params)),
      onRetry: () => ref.invalidate(entryAuditTrailProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucun événement sur cette période.', icon: Icons.history);
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final e = list[i];
            final when = '${Fmt.date(e.occurredAt)} ${e.occurredAt.hour.toString().padLeft(2, '0')}:${e.occurredAt.minute.toString().padLeft(2, '0')}';
            return AkListRow(
              leading: SizedBox(width: 120, child: Text(when, style: AkText.caption.copyWith(color: t.textMuted))),
              title: Row(
                children: [
                  SizedBox(width: 150, child: Text(e.actorLabel, style: AkText.table.copyWith(color: t.text), overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 190, child: Text(e.eventLabel, style: AkText.bodyStrong.copyWith(color: t.text))),
                  Expanded(child: Text('${e.entryRef} ${e.label ?? ''}'.trim(), style: AkText.table.copyWith(color: t.textMuted), overflow: TextOverflow.ellipsis)),
                ],
              ),
              onTap: e.entryId == null || e.event == 'deleted' ? null : () => context.go('/saisie/${e.entryId}'),
            );
          },
        );
      },
    );
  }
}
