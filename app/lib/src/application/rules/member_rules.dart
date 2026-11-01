import '../../domain/admin_models.dart';
import '../../domain/models.dart';

/// Qui peut gérer quel membre (miroir de `can_manage_member` et des fonctions d'administration, D-039).
abstract final class MemberRules {
  /// L'écran Collaborateurs est ouvert à l'administrateur technique et à l'associé.
  static bool canOpenMembers(PermissionSet perms) => perms.has('users.manage') || perms.has('team.manage');

  static bool isAdmin(PermissionSet perms) => perms.has('users.manage');

  static bool _isPrivileged(Set<String> roleCodes) => roleCodes.contains('partner') || roleCodes.contains('tech_admin');

  /// Modifier, désactiver, supprimer, réinitialiser le mot de passe : administrateur (tous, sauf soi-même) ou associé (équipe seulement).
  static bool canManage(PermissionSet perms, Set<String> roleCodes, {required bool isSelf}) {
    if (isSelf) return false;
    if (perms.has('users.manage')) return true;
    return perms.has('team.manage') && !_isPrivileged(roleCodes);
  }

  static bool canDesignatePartner(PermissionSet perms, Set<String> roleCodes, {required bool isSelf}) =>
      perms.has('users.manage') && !isSelf && !_isPrivileged(roleCodes);

  static bool canRevokePartner(PermissionSet perms, Set<String> roleCodes, {required bool isSelf}) =>
      perms.has('users.manage') && !isSelf && roleCodes.contains('partner');

  /// Codes de rôle de chaque membre, d'après les affectations visibles de l'appelant.
  static Map<String, Set<String>> roleCodesByUser(List<Assignment> assignments) {
    final byUser = <String, Set<String>>{};
    for (final a in assignments) {
      byUser.putIfAbsent(a.userId, () => {}).add(a.roleCode);
    }
    return byUser;
  }

  /// Libellé des rôles d'un membre (« Associé », « Chef de mission, Assistant »), vide s'il n'en a aucun.
  static String rolesLabel(List<Assignment> assignments, String userId) {
    final names = <String>{for (final a in assignments) if (a.userId == userId) a.roleName};
    return names.join(', ');
  }
}
