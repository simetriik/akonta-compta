import '../connectivity/connectivity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../../domain/models.dart';

/// Cas d'usage admin : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class AdminService {
  AdminService(this._repository, this._online);

  final AdminRepository _repository;
  final OnlinePolicy _online;

  Future<List<Profile>> profiles() async {
    _online.require('L\'administration');
    return _repository.profiles();
  }

  Future<void> setActive(String userId, bool active) async {
    _online.require('L\'administration');
    return _repository.setActive(userId, active);
  }

  Future<void> updateProfile(String userId, {required String fullName, String? jobTitle}) async {
    _online.require('L\'administration');
    return _repository.updateProfile(userId, fullName: fullName, jobTitle: jobTitle);
  }

  /// [firstPartner] : donne le rôle Associé à l'invité (permis une seule fois par cabinet, vérifié par la base).
  Future<InviteResult> invite({String? email, String? fullName, String? jobTitle, String? csv, bool firstPartner = false, String? role, String? entityId}) async {
    _online.require('L\'administration');
    return _repository.invite(email: email, fullName: fullName, jobTitle: jobTitle, csv: csv, firstPartner: firstPartner, role: role, entityId: entityId);
  }

  Future<TemporaryAccess> resetPassword(String userId) async {
    _online.require('L\'administration');
    return _repository.resetPassword(userId);
  }

  Future<void> deleteMember(String userId) async {
    _online.require('L\'administration');
    return _repository.deleteMember(userId);
  }

  Future<bool> cabinetHasPartner() async {
    _online.require('L\'administration');
    return _repository.cabinetHasPartner();
  }

  Future<List<PermissionDef>> permissions() async {
    _online.require('L\'administration');
    return _repository.permissions();
  }

  Future<List<RoleDef>> roles() async {
    _online.require('L\'administration');
    return _repository.roles();
  }

  Future<void> setRolePermission(String roleId, String code, bool granted) async {
    _online.require('L\'administration');
    return _repository.setRolePermission(roleId, code, granted);
  }

  Future<List<Assignment>> assignments() async {
    _online.require('L\'administration');
    return _repository.assignments();
  }

  Future<List<({String id, String name})>> entities() async {
    _online.require('L\'administration');
    return _repository.entities();
  }

  Future<void> addAssignment({required String cabinetId, required String userId, required String roleId, String? entityId}) async {
    _online.require('L\'administration');
    return _repository.addAssignment(cabinetId: cabinetId, userId: userId, roleId: roleId, entityId: entityId);
  }

  Future<void> designatePartner(String userId) async {
    _online.require('L\'administration');
    return _repository.designatePartner(userId);
  }

  Future<void> revokePartner(String userId) async {
    _online.require('L\'administration');
    return _repository.revokePartner(userId);
  }

  Future<List<TeamCandidate>> teamCandidates(String entityId, {String? role}) async {
    _online.require('L\'administration');
    return _repository.teamCandidates(entityId, role: role);
  }

  Future<void> replaceManager({required String entityId, required String userId}) async {
    _online.require('L\'administration');
    return _repository.replaceManager(entityId: entityId, userId: userId);
  }

  Future<void> removeAssignment(String id) async {
    _online.require('L\'administration');
    return _repository.removeAssignment(id);
  }

  /// Réaffectation en masse : tous les dossiers d'un collaborateur passent à un autre (même rôle).
  Future<int> reassignAll({required String cabinetId, required String fromUserId, required String toUserId}) async {
    _online.require('L\'administration');
    return _repository.reassignAll(cabinetId: cabinetId, fromUserId: fromUserId, toUserId: toUserId);
  }

  Future<List<AuditEvent>> auditLog({String? action, String? entityId, DateTime? from, DateTime? to, int limit = 200}) async {
    _online.require('L\'administration');
    return _repository.auditLog(action: action, entityId: entityId, from: from, to: to, limit: limit);
  }

  /// Renvoie null si la chaîne est intègre, sinon l'identifiant du premier maillon rompu.
  Future<int?> verifyChain(String cabinetId) async {
    _online.require('L\'administration');
    return _repository.verifyChain(cabinetId);
  }

  Future<void> updateCabinet(String id, Map<String, dynamic> values) async {
    _online.require('L\'administration');
    return _repository.updateCabinet(id, values);
  }
}
