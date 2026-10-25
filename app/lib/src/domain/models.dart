/// Modèles du domaine (miroir des tables PostgreSQL utilisées par l'interface).
library;

class Profile {
  const Profile({
    required this.id,
    required this.cabinetId,
    required this.email,
    required this.fullName,
    required this.isActive,
    this.jobTitle,
  });

  final String id;
  final String cabinetId;
  final String email;
  final String fullName;
  final bool isActive;
  final String? jobTitle;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        cabinetId: j['cabinet_id'] as String,
        email: j['email'] as String,
        fullName: (j['full_name'] as String?) ?? '',
        isActive: (j['is_active'] as bool?) ?? true,
        jobTitle: j['job_title'] as String?,
      );
}

class Cabinet {
  const Cabinet({
    required this.id,
    required this.name,
    required this.defaultAccountLength,
    required this.inactivityMinutes,
  });

  final String id;
  final String name;
  final int defaultAccountLength;
  final int inactivityMinutes;

  factory Cabinet.fromJson(Map<String, dynamic> j) => Cabinet(
        id: j['id'] as String,
        name: j['name'] as String,
        defaultAccountLength: (j['default_account_length'] as num).toInt(),
        inactivityMinutes: (j['inactivity_minutes'] as num).toInt(),
      );
}

/// Rôle tel que porté par une affectation de l'utilisateur courant.
class AssignedRole {
  const AssignedRole({
    required this.roleId,
    required this.code,
    required this.name,
    required this.entityId,
    required this.requiresMfa,
    required this.grantsAllEntities,
    required this.accountingAccess,
  });

  final String roleId;
  final String code;
  final String name;
  final String? entityId; // null = portée cabinet
  final bool requiresMfa;
  final bool grantsAllEntities;
  final bool accountingAccess;

  factory AssignedRole.fromJson(Map<String, dynamic> j) {
    final role = j['roles'] as Map<String, dynamic>;
    return AssignedRole(
      roleId: j['role_id'] as String,
      code: role['code'] as String,
      name: role['name'] as String,
      entityId: j['entity_id'] as String?,
      requiresMfa: role['requires_mfa'] as bool,
      grantsAllEntities: role['grants_all_entities'] as bool,
      accountingAccess: role['accounting_access'] as bool,
    );
  }
}

/// Permissions unitaires de l'utilisateur : par dossier, et de portée cabinet.
class PermissionSet {
  const PermissionSet({required this.byEntity, required this.cabinetWide, required this.roles});

  final Map<String, Set<String>> byEntity;
  final Set<String> cabinetWide;
  final List<AssignedRole> roles;

  static const empty = PermissionSet(byEntity: {}, cabinetWide: {}, roles: []);

  /// Même règle que `public.has_permission` : portée cabinet ou affectation sur le dossier.
  bool has(String code, {String? entityId}) {
    if (cabinetWide.contains(code)) return true;
    if (entityId == null) return false;
    return byEntity[entityId]?.contains(code) ?? false;
  }

  bool get requiresMfa => roles.any((r) => r.requiresMfa);
  bool get hasAccountingAccess => roles.any((r) => r.accountingAccess);
  bool get isTechAdminOnly => roles.isNotEmpty && roles.every((r) => !r.accountingAccess);
}

class EntitySummary {
  const EntitySummary({
    required this.id,
    required this.name,
    this.fiscalYearId,
    this.fiscalYearLabel,
    this.fiscalYearStatus,
    this.managerNames,
    this.lastEntryDate,
    this.draftCount = 0,
    this.unreviewedCount = 0,
    this.toCorrectCount = 0,
    this.inboxCount = 0,
  });

  final String id;
  final String name;
  final String? fiscalYearId;
  final String? fiscalYearLabel;
  final String? fiscalYearStatus;
  final String? managerNames;
  final DateTime? lastEntryDate;
  final int draftCount;
  final int unreviewedCount;
  final int toCorrectCount;
  final int inboxCount;

  factory EntitySummary.fromJson(Map<String, dynamic> j) => EntitySummary(
        id: j['entity_id'] as String,
        name: j['entity_name'] as String,
        fiscalYearId: j['fiscal_year_id'] as String?,
        fiscalYearLabel: j['fiscal_year_label'] as String?,
        fiscalYearStatus: j['fiscal_year_status'] as String?,
        managerNames: j['manager_names'] as String?,
        lastEntryDate: j['last_entry_date'] == null ? null : DateTime.parse(j['last_entry_date'] as String),
        draftCount: (j['draft_count'] as num?)?.toInt() ?? 0,
        unreviewedCount: (j['unreviewed_count'] as num?)?.toInt() ?? 0,
        toCorrectCount: (j['to_correct_count'] as num?)?.toInt() ?? 0,
        inboxCount: (j['inbox_count'] as num?)?.toInt() ?? 0,
      );

  /// Libellé « dossier » affiché partout : entité + exercice (conception §2).
  String get dossierLabel => fiscalYearLabel == null ? name : '$name · $fiscalYearLabel';
}
