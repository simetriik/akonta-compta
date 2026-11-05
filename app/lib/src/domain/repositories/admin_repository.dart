import '../admin_models.dart';
import '../models.dart';

abstract interface class AdminRepository {
  Future<List<Profile>> profiles();

  Future<void> setActive(String userId, bool active);

  Future<void> updateProfile(String userId, {required String fullName, String? jobTitle});

  Future<InviteResult> invite({String? email, String? fullName, String? jobTitle, String? csv, bool firstPartner = false, String? role, String? entityId});

  /// Nouveau mot de passe provisoire pour un membre (oubli) ; il devra le changer à sa prochaine connexion.
  Future<TemporaryAccess> resetPassword(String userId);

  /// Supprime la double vérification d'un membre (appareil perdu) ; renvoie le nombre de facteurs retirés.
  /// Le membre en enrôle un nouveau à sa prochaine connexion ; son mot de passe ne change pas.
  Future<int> resetMfa(String userId);

  /// Le cabinet de l'utilisateur courant a-t-il déjà un associé ?
  Future<bool> cabinetHasPartner();

  /// Supprime un membre sans aucune trace ; la base refuse sinon (il faut alors le désactiver).
  Future<void> deleteMember(String userId);

  Future<List<PermissionDef>> permissions();

  Future<List<RoleDef>> roles();

  Future<void> setRolePermission(String roleId, String code, bool granted);

  Future<List<Assignment>> assignments();

  Future<List<({String id, String name})>> entities();

  Future<void> addAssignment({required String cabinetId, required String userId, required String roleId, String? entityId});

  Future<void> removeAssignment(String id);

  /// Désigne un associé (administrateur technique) ; [revokePartner] lui retire ce rôle, le dernier associé étant protégé.
  Future<void> designatePartner(String userId);

  Future<void> revokePartner(String userId);

  /// Collaborateurs affectables à ce dossier ; [role] précise le rôle visé (ex. `manager`).
  Future<List<TeamCandidate>> teamCandidates(String entityId, {String? role});

  /// Remplace le chef de mission d'un dossier (associé) : retire l'ancien et pose le nouveau en une opération.
  Future<void> replaceManager({required String entityId, required String userId});

  /// Réaffectation en masse : tous les dossiers d'un collaborateur passent à un autre (même rôle).
  Future<int> reassignAll({required String cabinetId, required String fromUserId, required String toUserId});

  Future<List<AuditEvent>> auditLog({String? action, String? entityId, DateTime? from, DateTime? to, int limit = 200});

  /// Renvoie null si la chaîne est intègre, sinon l'identifiant du premier maillon rompu.
  Future<int?> verifyChain(String cabinetId);

  Future<void> updateCabinet(String id, Map<String, dynamic> values);
}
