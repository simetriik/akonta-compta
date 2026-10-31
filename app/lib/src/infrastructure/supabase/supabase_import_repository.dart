import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/import_models.dart';
import '../../domain/repositories/import_repository.dart';
import 'mappers/import_repository_mappers.dart';

/// Module 10 : lots d'import Perfecto, analyse côté base, correspondances éditables, essai, application.
class SupabaseImportRepository implements ImportRepository {
  SupabaseImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ImportBatch>> batches(String entityId) async {
    final rows = await _client.from('import_batches').select().eq('entity_id', entityId).order('created_at', ascending: false);
    return rows.map(importBatchFromJson).toList();
  }

  @override
  Future<ImportBatch> createBatch({required String cabinetId, required String entityId, required String kind, required String fileName, String? targetJournalId}) async {
    final row = await _client.from('import_batches').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'kind': kind, 'source_file_name': fileName, 'target_journal_id': targetJournalId}).select().single();
    return importBatchFromJson(row);
  }

  @override
  Future<Map<String, dynamic>> parseJournalText(String batchId, String text) async =>
      ((await _client.rpc('import_parse_perfecto_journal', params: {'p_batch': batchId, 'p_text': text})) as Map).cast<String, dynamic>();

  @override
  Future<int> loadLines(String batchId, List<Map<String, dynamic>> lines) async =>
      ((await _client.rpc('import_load_lines', params: {'p_batch': batchId, 'p_lines': lines})) as num).toInt();

  @override
  Future<Map<String, dynamic>> proposeMappings(String batchId) async =>
      ((await _client.rpc('import_propose_mappings', params: {'p_batch': batchId})) as Map).cast<String, dynamic>();

  @override
  Future<List<AccountMapping>> mappings(String entityId, String batchId) async {
    final raw = await _client.from('import_lines').select('raw_account').eq('batch_id', batchId);
    final used = {for (final r in raw) r['raw_account'] as String};
    final rows = await _client.from('import_account_mappings').select().eq('entity_id', entityId).inFilter('raw_account', used.toList()).order('raw_account', ascending: true);
    return rows.map(accountMappingFromJson).toList();
  }

  @override
  Future<void> updateMapping(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty}) =>
      _client.from('import_account_mappings').update({
        'account_code': accountCode?.trim().isEmpty == true ? null : accountCode?.trim(),
        'third_party_code': thirdPartyCode?.trim().isEmpty == true ? null : thirdPartyCode?.trim().toUpperCase(),
        'third_party_name': thirdPartyName?.trim().isEmpty == true ? null : thirdPartyName?.trim(),
        'create_third_party': ?createThirdParty,
      }).eq('id', id);

  @override
  Future<Map<String, dynamic>> apply(String batchId, {required bool dryRun}) async =>
      ((await _client.rpc('import_apply', params: {'p_batch': batchId, 'p_dry_run': dryRun})) as Map).cast<String, dynamic>();

  @override
  Future<void> setTargetJournal(String batchId, String? journalId) => _client.from('import_batches').update({'target_journal_id': journalId}).eq('id', batchId);
}
