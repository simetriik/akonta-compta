import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity.dart';
import '../services/admin_service.dart';
import '../services/closing_service.dart';
import '../services/consultation_service.dart';
import '../services/documents_service.dart';
import '../services/invoices_service.dart';
import '../services/entities_service.dart';
import '../services/entries_service.dart';
import '../services/import_service.dart';
import '../services/inventory_service.dart';
import '../services/lettering_service.dart';
import '../services/reconciliation_service.dart';
import '../services/references_service.dart';
import '../services/suggestions_service.dart';
import 'repositories.dart';
import 'session_providers.dart';

/// État de la connexion : la composition fournit le moniteur réel ; sans lui, l'appareil est supposé en ligne.
final connectivityProvider = Provider<ConnectivityPort>((ref) => const AlwaysOnline());

/// Règle de connexion, **liée à l'utilisateur connecté** : tous les services en dépendent, donc tous les écrans qui lisent leurs
/// données par un service sont relus quand l'utilisateur change. Sans cela, après une déconnexion puis une connexion sans rechargement
/// de la page, un compte voyait les listes (collaborateurs, rôles, affectations…) chargées par le compte précédent.
final onlinePolicyProvider = Provider<OnlinePolicy>((ref) {
  ref.watch(currentUserIdProvider);
  return OnlinePolicy(ref.watch(connectivityProvider));
});

/// Vrai tant que l'appareil est en ligne ; les écrans s'en servent pour désactiver les fonctions réservées à la connexion.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  yield connectivity.isOnline;
  yield* connectivity.changes;
});

final adminServiceProvider = Provider<AdminService>((ref) => AdminService(ref.watch(adminRepositoryProvider), ref.watch(onlinePolicyProvider)));
final closingServiceProvider = Provider<ClosingService>((ref) => ClosingService(ref.watch(closingRepositoryProvider), ref.watch(onlinePolicyProvider)));
final consultationServiceProvider = Provider<ConsultationService>(
  (ref) => ConsultationService(ref.watch(consultationRepositoryProvider), ref.watch(onlinePolicyProvider)),
);
final invoicesServiceProvider = Provider<InvoicesService>(
  (ref) => InvoicesService(ref.watch(invoicesRepositoryProvider), ref.watch(onlinePolicyProvider)),
);

final documentsServiceProvider = Provider<DocumentsService>(
  (ref) => DocumentsService(ref.watch(documentsRepositoryProvider), ref.watch(onlinePolicyProvider), ref.watch(outboxRepositoryProvider)),
);
final entitiesServiceProvider = Provider<EntitiesService>((ref) => EntitiesService(ref.watch(entitiesRepositoryProvider), ref.watch(onlinePolicyProvider)));
final entriesServiceProvider = Provider<EntriesService>(
  (ref) => EntriesService(ref.watch(entriesRepositoryProvider), ref.watch(onlinePolicyProvider), ref.watch(outboxRepositoryProvider)),
);
final importServiceProvider = Provider<ImportService>((ref) => ImportService(ref.watch(importRepositoryProvider), ref.watch(onlinePolicyProvider)));
final inventoryServiceProvider = Provider<InventoryService>((ref) => InventoryService(ref.watch(inventoryRepositoryProvider), ref.watch(onlinePolicyProvider)));
final letteringServiceProvider = Provider<LetteringService>((ref) => LetteringService(ref.watch(letteringRepositoryProvider), ref.watch(onlinePolicyProvider)));
final reconciliationServiceProvider = Provider<ReconciliationService>(
  (ref) => ReconciliationService(ref.watch(reconciliationRepositoryProvider), ref.watch(onlinePolicyProvider)),
);
final referencesServiceProvider = Provider<ReferencesService>(
  (ref) => ReferencesService(ref.watch(referencesRepositoryProvider), ref.watch(onlinePolicyProvider)),
);
final suggestionsServiceProvider = Provider<SuggestionsService>(
  (ref) => SuggestionsService(ref.watch(suggestionsRepositoryProvider), ref.watch(onlinePolicyProvider)),
);
