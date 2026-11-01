/// Rôle d'un cabinet avec ses permissions (ajustables par l'associé).
class RoleDef {
  const RoleDef({required this.id, required this.code, required this.name, required this.isSystem, required this.permissions});

  final String id;
  final String code;
  final String name;
  final bool isSystem;
  final Set<String> permissions;
}

class PermissionDef {
  const PermissionDef({required this.code, required this.label, required this.category});

  final String code;
  final String label;
  final String category;
}

class Assignment {
  const Assignment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roleId,
    required this.roleName,
    required this.roleCode,
    this.entityId,
    this.entityName,
  });

  final String id;
  final String userId;
  final String userName;
  final String roleId;
  final String roleName;
  final String roleCode;
  final String? entityId;
  final String? entityName;
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.occurredAt,
    required this.action,
    this.actorName,
    this.tableName,
    this.recordId,
    this.entityId,
    required this.payload,
    required this.hash,
  });

  final int id;
  final DateTime occurredAt;
  final String action;
  final String? actorName;
  final String? tableName;
  final String? recordId;
  final String? entityId;
  final Map<String, dynamic> payload;
  final String hash;
}

/// Accès provisoire d'un membre : adresse e-mail et mot de passe provisoire, montrés une seule fois à l'administrateur.
class TemporaryAccess {
  const TemporaryAccess({required this.email, required this.password});

  final String email;
  final String password;
}

/// Collaborateur affectable à un dossier (fonction `team_candidates` de la base : ni associé, ni déjà dans l'équipe).
class TeamCandidate {
  const TeamCandidate({required this.id, required this.fullName, required this.email});

  final String id;
  final String fullName;
  final String email;

  String get label => fullName.isEmpty ? email : fullName;
}

class InviteResult {
  const InviteResult({required this.invited, required this.failed, required this.parseErrors});

  final List<TemporaryAccess> invited;
  final List<String> failed;
  final List<String> parseErrors;
}

/// Miroir côté application des règles de la base sur les rôles (D-037) : la base reste la garantie.
abstract final class AssignableRoles {
  /// Rôles qu'un associé attribue et retire.
  static const codes = {'manager', 'assistant', 'trainee'};

  /// Droits d'administration, jamais accordables à un rôle depuis l'application.
  static const reservedPermissions = {'users.manage', 'team.manage', 'team.assign', 'roles.manage', 'assignments.manage'};
}
