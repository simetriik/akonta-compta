import '../../../domain/models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

Profile profileFromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        cabinetId: j['cabinet_id'] as String,
        email: j['email'] as String,
        fullName: (j['full_name'] as String?) ?? '',
        isActive: (j['is_active'] as bool?) ?? true,
        jobTitle: j['job_title'] as String?,
      );

Cabinet cabinetFromJson(Map<String, dynamic> j) => Cabinet(
        id: j['id'] as String,
        name: j['name'] as String,
        defaultAccountLength: (j['default_account_length'] as num).toInt(),
        inactivityMinutes: (j['inactivity_minutes'] as num).toInt(),
        // Absent d'un cache hors connexion ancien : l'avertissement reste actif.
        warnMissingDocument: (j['warn_missing_document'] as bool?) ?? true,
      );

AssignedRole assignedRoleFromJson(Map<String, dynamic> j) {
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

EntitySummary entitySummaryFromJson(Map<String, dynamic> j) => EntitySummary(
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
