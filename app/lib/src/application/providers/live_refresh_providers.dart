import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../realtime/change_feed.dart';
import '../realtime/live_refresh.dart';
import 'consultation_providers.dart';
import 'documents_providers.dart';
import 'entries_providers.dart';
import 'invoices_providers.dart';
import 'services.dart';
import 'session_providers.dart';

/// Écoute des changements : la composition fournit l'adaptateur réel ; sans lui, aucune écoute.
final changeFeedProvider = Provider<ChangeFeedPort>((ref) => const NoChangeFeed());

/// Maintient les listes à jour quand un autre utilisateur saisit ou dépose une pièce ; à observer une fois, depuis le gabarit de l'application.
/// Repart à zéro quand l'utilisateur, le dossier courant ou l'état de la connexion changent.
final liveRefreshProvider = Provider<LiveRefresh>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final entityId = ref.watch(currentEntityProvider.select((e) => e?.id));
  final online = ref.watch(isOnlineProvider).value ?? true;
  final refresh = LiveRefresh(onRefresh: (topics) => _invalidate(ref, topics));
  ref.onDispose(refresh.dispose);
  if (userId != null && online) {
    final subscription = ref.watch(changeFeedProvider).open(userId: userId, entityId: entityId);
    if (subscription != null) refresh.attach(subscription);
  }
  return refresh;
});

/// Invalide les listes concernées ; celles qui ne sont affichées nulle part sont simplement relues à leur prochaine ouverture.
void _invalidate(Ref ref, Set<ChangeTopic> topics) {
  if (topics.contains(ChangeTopic.entries)) {
    ref.invalidate(entriesListProvider);
    ref.invalidate(entityDashboardProvider);
    ref.invalidate(generalLedgerProvider);
    ref.invalidate(trialBalanceProvider);
    ref.invalidate(auxiliaryBalanceProvider);
    ref.invalidate(agedBalanceProvider);
    ref.invalidate(centralizationProvider);
  }
  if (topics.contains(ChangeTopic.documents)) {
    ref.invalidate(documentsProvider);
    ref.invalidate(entryDocumentsProvider);
  }
  if (topics.contains(ChangeTopic.notifications)) ref.invalidate(notificationsProvider);
  if (topics.contains(ChangeTopic.invoices)) {
    ref.invalidate(invoicesProvider);
    ref.invalidate(invoiceProvider);
  }
}
