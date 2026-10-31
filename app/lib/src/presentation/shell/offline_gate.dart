import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/offline_providers.dart';
import '../../application/providers/services.dart';
import '../../core/errors/errors.dart';

/// Parties de l'application qui exigent une connexion (calculs, validation, clôture, administration) : remplacées par un message
/// clair tant que l'appareil est hors ligne. Les brouillons, les référentiels, les dossiers et les pièces restent utilisables.
const onlineOnlyRoutes = ['/consultation', '/cloture', '/inventaire', '/lettrage', '/rapprochement', '/import', '/utilisateurs', '/cabinet', '/dossiers/nouveau'];

bool isOnlineOnlyRoute(String location) => onlineOnlyRoutes.any((r) => location == r || location.startsWith('$r/'));

/// Bandeau d'état de la connexion et de la file d'envoi, placé au-dessus du contenu ; masque les écrans réservés à la connexion.
class OfflineGate extends ConsumerWidget {
  const OfflineGate({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncAutoProvider); // synchronisation automatique au retour de la connexion
    final online = ref.watch(isOnlineProvider).value ?? true;
    final items = ref.watch(outboxItemsProvider).value ?? const [];
    final failed = items.where((i) => i.hasFailed && i.attempts >= 1).toList();
    final pending = items.length;
    final blocked = !online && isOnlineOnlyRoute(location);
    return Column(
      children: [
        if (!online)
          AkBanner(
            key: const Key('offline-banner'),
            kind: AkBannerKind.warning,
            icon: Icons.cloud_off_outlined,
            child: Text(
              'Mode hors connexion. Vous pouvez saisir des brouillons d\'écritures, déposer des pièces et consulter les données déjà chargées. '
              'Grand livre, balance, états, validation et clôture nécessitent une connexion.${pending > 0 ? ' · $pending élément${pending > 1 ? 's' : ''} en attente d\'envoi.' : ''}',
            ),
          )
        else if (failed.isNotEmpty)
          AkBanner(
            key: const Key('sync-failed-banner'),
            kind: AkBannerKind.danger,
            icon: Icons.sync_problem_outlined,
            child: Row(
              children: [
                Expanded(child: Text('${failed.length} élément${failed.length > 1 ? 's' : ''} saisi${failed.length > 1 ? 's' : ''} hors connexion n\'${failed.length > 1 ? 'ont' : 'a'} pas pu être envoyé${failed.length > 1 ? 's' : ''} : ${failed.first.lastError}')),
                AkButton.secondary('Réessayer', onPressed: () => _sync(context, ref)),
              ],
            ),
          )
        else if (pending > 0)
          AkBanner(
            key: const Key('sync-pending-banner'),
            kind: AkBannerKind.info,
            icon: Icons.sync_outlined,
            child: Row(
              children: [
                Expanded(child: Text('$pending élément${pending > 1 ? 's' : ''} saisi${pending > 1 ? 's' : ''} hors connexion à envoyer.')),
                AkButton.secondary('Synchroniser maintenant', onPressed: () => _sync(context, ref)),
              ],
            ),
          ),
        Expanded(
          child: blocked
              ? const AkEmptyState(
                  'Cette partie nécessite une connexion internet. Reconnectez-vous pour y accéder ; vos brouillons et vos pièces saisis hors connexion seront envoyés automatiquement.',
                )
              : child,
        ),
      ],
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      final report = await ref.read(syncServiceProvider).flush(retryFailed: true);
      if (context.mounted) {
        showAkToast(context, report.failed > 0 ? '${report.sent} envoyé(s), ${report.failed} en échec.' : '${report.sent} élément(s) envoyé(s).', kind: report.failed > 0 ? AkToastKind.warning : AkToastKind.success);
      }
    } catch (e) {
      if (context.mounted) showAkToast(context, errorText(e), kind: AkToastKind.danger);
    }
  }
}
