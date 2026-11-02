import '../../domain/admin_models.dart';
import '../../domain/models.dart';

/// Règles de l'équipe d'un dossier côté application (miroir de ce que la base impose, D-037 et D-038).
abstract final class TeamRules {
  /// L'utilisateur peut-il modifier l'équipe de ce dossier ? Associé (tout le cabinet) ou chef de mission du dossier.
  static bool canManage(PermissionSet perms, String entityId) => perms.has('assignments.manage') || perms.has('team.assign', entityId: entityId);

  /// Seul l'associé choisit ou remplace le chef de mission.
  static bool canSetManager(PermissionSet perms) => perms.has('assignments.manage');

  /// Rôles que l'utilisateur peut attribuer sur ce dossier, dans l'ordre d'affichage.
  static List<RoleDef> assignableRoles(PermissionSet perms, String entityId, List<RoleDef> roles) {
    final allowed = canSetManager(perms)
        ? const ['manager', 'assistant', 'trainee']
        : perms.has('team.assign', entityId: entityId)
        ? const ['assistant', 'trainee']
        : const <String>[];
    return [for (final code in allowed) ...roles.where((r) => r.code == code)];
  }

  /// Équipe du dossier : affectations rattachées à ce dossier, chef de mission d'abord.
  static List<Assignment> teamOf(List<Assignment> all, String entityId) {
    const order = {'manager': 0, 'assistant': 1, 'trainee': 2};
    // Les comptes clients ont leur propre onglet : ils ne font pas partie de l'équipe du cabinet.
    final team = all.where((a) => a.entityId == entityId && !a.roleCode.startsWith('client_')).toList();
    team.sort((a, b) {
      final byRole = (order[a.roleCode] ?? 9).compareTo(order[b.roleCode] ?? 9);
      return byRole != 0 ? byRole : a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });
    return team;
  }

  static Assignment? manager(List<Assignment> team) => team.where((a) => a.roleCode == 'manager').firstOrNull;
}
