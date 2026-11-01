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
}

class Cabinet {
  const Cabinet({
    required this.id,
    required this.name,
    required this.defaultAccountLength,
    required this.inactivityMinutes,
    this.warnMissingDocument = true,
  });

  final String id;
  final String name;
  final int defaultAccountLength;
  final int inactivityMinutes;

  /// Avertir (sans bloquer) à la validation d'une écriture sans pièce jointe.
  final bool warnMissingDocument;
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

  /// Libellé « dossier » affiché partout : entité + exercice (conception §2).
  String get dossierLabel => fiscalYearLabel == null ? name : '$name · $fiscalYearLabel';
}
