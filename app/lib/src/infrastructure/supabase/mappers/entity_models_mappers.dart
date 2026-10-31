import '../../../domain/entity_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

  String? _n(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

EntityDetail entityDetailFromJson(Map<String, dynamic> j) => EntityDetail(
        id: j['id'] as String,
        cabinetId: j['cabinet_id'] as String,
        name: j['name'] as String,
        acronym: j['acronym'] as String?,
        legalForm: j['legal_form'] as String?,
        address: j['address'] as String?,
        countryCode: (j['country_code'] as String?) ?? 'BJ',
        taxId: j['tax_id'] as String?,
        tradeRegister: j['trade_register'] as String?,
        taxRegime: j['tax_regime'] as String?,
        incorporationDate: j['incorporation_date'] == null ? null : DateTime.parse(j['incorporation_date'] as String),
        establishmentsCount: (j['establishments_count'] as num?)?.toInt(),
        controlType: j['control_type'] as String?,
        controlOrigin: j['control_origin'] as String?,
        mainActivity: j['main_activity'] as String?,
        secondaryActivities: ((j['secondary_activities'] as List?) ?? const []).cast<String>(),
        activityCode: j['activity_code'] as String?,
        accountLength: (j['account_length'] as num?)?.toInt() ?? 7,
        accountingSystem: (j['accounting_system'] as String?) ?? 'normal',
        monthlyLockEnabled: (j['monthly_lock_enabled'] as bool?) ?? false,
        isActive: (j['is_active'] as bool?) ?? true,
      );

Director directorFromJson(Map<String, dynamic> j) => Director(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        position: j['position'] as String,
        nationality: j['nationality'] as String?,
        address: j['address'] as String?,
        isBoardMember: (j['is_board_member'] as bool?) ?? false,
      );

FiscalYear fiscalYearFromJson(Map<String, dynamic> j) => FiscalYear(
        id: j['id'] as String,
        entityId: j['entity_id'] as String,
        label: j['label'] as String,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        status: j['status'] as String,
        capital: (j['capital'] as num?)?.toInt(),
        headcount: (j['headcount'] as num?)?.toInt(),
        finalClosedAt: j['final_closed_at'] == null ? null : DateTime.parse(j['final_closed_at'] as String).toLocal(),
      );

Period periodFromJson(Map<String, dynamic> j) => Period(
        id: j['id'] as String,
        fiscalYearId: j['fiscal_year_id'] as String,
        periodNo: (j['period_no'] as num).toInt(),
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        isLocked: j['is_locked'] as bool,
        unlockReason: j['unlock_reason'] as String?,
      );

FiscalYearPartner fiscalYearPartnerFromJson(Map<String, dynamic> j) =>
      FiscalYearPartner(id: j['id'] as String, name: j['name'] as String, sharePercent: double.parse('${j['share_percent']}'));

JournalTemplate journalTemplateFromJson(Map<String, dynamic> j) =>
      JournalTemplate(code: j['code'] as String, label: j['label'] as String, type: j['type'] as String, isDefaultChecked: j['is_default_checked'] as bool);

AccountRef accountRefFromJson(Map<String, dynamic> j) => AccountRef(id: j['id'] as String, code: j['code'] as String, label: j['label'] as String);

EntityHistoryItem entityHistoryItemFromJson(Map<String, dynamic> j) => EntityHistoryItem(
        changedAt: DateTime.parse(j['changed_at'] as String).toLocal(),
        changes: (j['changes'] as Map).cast<String, dynamic>(),
        changedBy: j['changed_by'] as String?,
      );

extension EntityInputJson on EntityInput {
  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'acronym': _n(acronym),
        'legal_form': _n(legalForm),
        'address': _n(address),
        'country_code': countryCode,
        'tax_id': _n(taxId),
        'trade_register': _n(tradeRegister),
        'tax_regime': _n(taxRegime),
        'incorporation_date': incorporationDate?.toIso8601String().substring(0, 10),
        'establishments_count': establishmentsCount,
        'control_type': controlType,
        'control_origin': controlOrigin,
        'main_activity': _n(mainActivity),
        'secondary_activities': secondaryActivities,
        'activity_code': _n(activityCode),
        if (accountLength != null) 'account_length': accountLength,
        if (accountingSystem != null) 'accounting_system': accountingSystem,
        if (monthlyLockEnabled != null) 'monthly_lock_enabled': monthlyLockEnabled,
      };
}
