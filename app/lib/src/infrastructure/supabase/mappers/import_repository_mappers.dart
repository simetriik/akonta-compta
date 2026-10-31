import '../../../domain/import_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

ImportBatch importBatchFromJson(Map<String, dynamic> j) => ImportBatch(
        id: j['id'] as String,
        kind: j['kind'] as String,
        status: j['status'] as String,
        sourceFileName: j['source_file_name'] as String?,
        sourceJournal: j['source_journal'] as String?,
        periodFrom: j['period_from'] == null ? null : DateTime.parse(j['period_from'] as String),
        periodTo: j['period_to'] == null ? null : DateTime.parse(j['period_to'] as String),
        targetJournalId: j['target_journal_id'] as String?,
        report: (j['report'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

AccountMapping accountMappingFromJson(Map<String, dynamic> j) => AccountMapping(
        id: j['id'] as String,
        rawAccount: j['raw_account'] as String,
        accountCode: j['account_code'] as String?,
        thirdPartyCode: j['third_party_code'] as String?,
        thirdPartyName: j['third_party_name'] as String?,
        createThirdParty: j['create_third_party'] as bool,
        note: j['note'] as String?,
      );
