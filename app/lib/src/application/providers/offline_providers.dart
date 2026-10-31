import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/outbox_models.dart';
import '../offline/sync_service.dart';
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
final syncAutoProvider = Provider<void>((ref) {
  final sync = ref.watch(syncServiceProvider);
  ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
    if (next.value == true) sync.flush();
  });
  if (ref.read(connectivityProvider).isOnline) sync.flush();
});
