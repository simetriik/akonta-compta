import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/entries_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/notification_text.dart';
import '../../domain/entry_models.dart';
import '../../domain/models.dart';
import '../../application/providers/services.dart';

/// Cloche de la barre haute : notifications non lues (affectations, écritures à corriger) et écritures à corriger du dossier courant.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.entity});

  final EntitySummary? entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final unread = ref.watch(notificationsProvider).value ?? const <Map<String, dynamic>>[];
    final toCorrect = entity?.toCorrectCount ?? 0;
    final count = unread.length + (toCorrect > 0 ? 1 : 0);
    final icon = Icon(count > 0 ? Icons.notifications : Icons.notifications_none_outlined);
    return Tooltip(
      message: count == 0 ? 'Aucune notification' : '$count notification(s)',
      child: InkWell(
        key: const Key('notification-bell'),
        borderRadius: AkRadius.mdAll,
        onTap: () => showDialog<void>(context: context, builder: (_) => _NotificationsDialog(toCorrect: toCorrect)),
        child: Padding(
          padding: const EdgeInsets.all(AkSpace.s2),
          child: count > 0 ? Badge(label: Text('$count'), backgroundColor: t.dangerSolid, textColor: t.onDanger, child: icon) : icon,
        ),
      ),
    );
  }
}

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog({required this.toCorrect});

  final int toCorrect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final unread = ref.watch(notificationsProvider).value ?? const <Map<String, dynamic>>[];

    Future<void> open(Map<String, dynamic> n) async {
      final entityId = NotificationText.entityId(n);
      await ref.read(entriesServiceProvider).markRead(n['id'] as int);
      ref.invalidate(notificationsProvider);
      ref.invalidate(entityDashboardProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (n['kind'] == 'assigned' && entityId != null) {
        final list = await ref.read(entityDashboardProvider.future);
        final target = list.where((e) => e.id == entityId).firstOrNull;
        if (target != null) ref.read(currentEntityProvider.notifier).select(target);
        if (context.mounted) context.go('/dossiers/$entityId');
      } else if (context.mounted) {
        context.go('/saisie');
      }
    }

    return AkDialog(
      title: 'Notifications',
      size: AkDialogSize.m,
      content: SizedBox(
        width: 440,
        child: (toCorrect == 0 && unread.isEmpty)
            ? const AkEmptyState('Rien de nouveau.', icon: Icons.notifications_none_outlined)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (toCorrect > 0)
                    AkListRow(
                      title: Text(toCorrect == 1 ? '1 écriture à corriger dans le dossier courant' : '$toCorrect écritures à corriger dans le dossier courant'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(entryFilterProvider.notifier).set(const EntryFilter(reviewStatus: 'to_correct'));
                        context.go('/saisie');
                      },
                    ),
                  for (final n in unread)
                    AkListRow(
                      key: Key('notification-${n['id']}'),
                      title: Text(NotificationText.describe(n), style: AkText.body.copyWith(color: t.text)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(n),
                    ),
                ],
              ),
      ),
      actions: [AkButton.primary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}
