import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/outbox_models.dart';
import '../offline/sync_service.dart';
import 'live_refresh_providers.dart';
import 'repositories.dart';
import 'services.dart';

/// Actions saisies hors connexion et pas encore envoyées.
final outboxItemsProvider = StreamProvider<List<OutboxItem>>((ref) => ref.watch(outboxRepositoryProvider).watch());

/// Nombre d'éléments en attente d'envoi.
final pendingCountProvider = Provider<int>((ref) => ref.watch(outboxItemsProvider).value?.length ?? 0);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    outbox: ref.watch(outboxRepositoryProvider),
    entries: ref.watch(entriesRepositoryProvider),
    documents: ref.watch(documentsRepositoryProvider),
    connectivity: ref.watch(connectivityProvider),
  ),
);

/// Lance la synchronisation à chaque retour en ligne et au démarrage ; à observer une fois, depuis le gabarit de l'application.
/// Une fois la file envoyée, les listes sont relues : elles ont pu changer pendant la coupure.
final syncAutoProvider = Provider<void>((ref) {
  final sync = ref.watch(syncServiceProvider);
  final live = ref.watch(liveRefreshProvider);
  Future<void> syncThenRefresh() async {
    await sync.flush();
    if (ref.mounted) live.refreshAll();
  }

  ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
    if (next.value == true) syncThenRefresh();
  });
  if (ref.read(connectivityProvider).isOnline) syncThenRefresh();
});
