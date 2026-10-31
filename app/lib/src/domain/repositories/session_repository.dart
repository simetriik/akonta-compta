import '../models.dart';

/// Contexte de l'utilisateur connecté : profil, cabinet, permissions et dossiers accessibles avec leurs indicateurs.
abstract interface class SessionRepository {
  Future<Profile?> profile(String userId);

  Future<Cabinet?> cabinet(String cabinetId);

  /// Affectations → rôles → permissions unitaires.
  Future<PermissionSet> permissions(String userId);

  /// Dossiers accessibles avec leurs indicateurs.
  Future<List<EntitySummary>> dashboard();
}
