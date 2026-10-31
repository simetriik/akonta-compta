import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_models.dart';
import '../../domain/models.dart';
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

/// Dossier courant, toujours visible dans l'interface (conception §12.3).
class CurrentEntityNotifier extends Notifier<EntitySummary?> {
  @override
  EntitySummary? build() {
    ref.watch(currentUserIdProvider); // changement d'utilisateur : le dossier courant est oublié
    return null;
  }

  void select(EntitySummary? entity) => state = entity;
}

final currentEntityProvider = NotifierProvider<CurrentEntityNotifier, EntitySummary?>(CurrentEntityNotifier.new);
