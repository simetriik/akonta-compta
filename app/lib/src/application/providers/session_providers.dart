import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_models.dart';
import '../../domain/models.dart';
import '../preferences/last_entity_store.dart';
import 'repositories.dart';

/// Changements d'état d'authentification (tous, jeton renouvelé compris).
final authChangesProvider = StreamProvider<AuthChange>((ref) => ref.watch(authRepositoryProvider).changes());

/// Utilisateur connecté ; recalculé à chaque événement d'authentification.
final currentUserProvider = Provider<AuthSession?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(authRepositoryProvider).currentSession;
});

/// Identifiant de l'utilisateur connecté : ne change qu'à la connexion / déconnexion, pas à chaque
/// rafraîchissement de jeton (évite de recharger profil et permissions en boucle).
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.userId);

/// Niveau d'assurance de la session (aal) : recalculé après vérification TOTP.
final mfaStatusProvider = FutureProvider<MfaStatus?>((ref) async {
  ref.watch(authChangesProvider);
  if (ref.watch(currentUserProvider) == null) return null;
  return ref.watch(authRepositoryProvider).mfaStatus();
});

/// Profil du collaborateur connecté (table profiles, RLS : son cabinet).
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(sessionRepositoryProvider).profile(userId);
});

final currentCabinetProvider = FutureProvider<Cabinet?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(sessionRepositoryProvider).cabinet(profile.cabinetId);
});

/// Permissions de l'utilisateur : affectations → rôles → permissions unitaires.
final permissionsProvider = FutureProvider<PermissionSet>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return PermissionSet.empty;
  return ref.watch(sessionRepositoryProvider).permissions(userId);
});

/// Dossiers accessibles avec leurs indicateurs (fonction SQL entity_dashboard).
final entityDashboardProvider = FutureProvider<List<EntitySummary>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(sessionRepositoryProvider).dashboard();
});

/// Mémoire du dernier dossier ouvert ; la composition fournit l'adaptateur réel.
final lastEntityStoreProvider = Provider<LastEntityStore>((ref) => const NoLastEntityStore());

/// Identifiant du dernier dossier ouvert par l'utilisateur connecté (lu une fois par connexion).
final savedEntityIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  try {
    return await ref.watch(lastEntityStoreProvider).read(userId);
  } catch (_) {
    return null; // mémoire illisible : on repart sans dossier, sans bloquer l'application
  }
});

/// Dossier courant, toujours visible dans l'interface (conception §12.3).
/// Le choix est mémorisé par utilisateur et retrouvé au prochain chargement (voir [restoreSavedEntity]).
class CurrentEntityNotifier extends Notifier<EntitySummary?> {
  @override
  EntitySummary? build() {
    ref.watch(currentUserIdProvider); // changement d'utilisateur : le dossier courant est oublié
    return null;
  }

  void select(EntitySummary? entity) {
    state = entity;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      // Mémorisation sans attente : un échec d'écriture ne doit jamais gêner le choix du dossier.
      ref.read(lastEntityStoreProvider).write(userId, entity?.id).ignore();
    }
  }
}

/// Retrouve le dossier mémorisé parmi les dossiers accessibles ; renvoie null s'il n'y en a pas
/// (dossier supprimé ou accès retiré : on ne force rien, l'utilisateur choisit).
EntitySummary? restoreSavedEntity(List<EntitySummary> accessible, String? savedId) {
  if (savedId == null) return null;
  return accessible.where((e) => e.id == savedId).firstOrNull;
}

final currentEntityProvider = NotifierProvider<CurrentEntityNotifier, EntitySummary?>(CurrentEntityNotifier.new);
