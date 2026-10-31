import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';
import '../infrastructure/supabase/mappers/import_repository_mappers.dart';

class ImportBatch {
  const ImportBatch({required this.id, required this.kind, required this.status, this.sourceFileName, this.sourceJournal, this.periodFrom, this.periodTo, this.targetJournalId, required this.report, required this.createdAt});

  final String id;
  final String kind;
  final String status;
  final String? sourceFileName;
  final String? sourceJournal;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String? targetJournalId;
  final Map<String, dynamic> report;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'created' => 'Créé',
        'parsed' => 'Analysé',
        'mapped' => 'Correspondances proposées',
        'dry_run' => 'Essai effectué',
        'applied' => 'Appliqué',
        'cancelled' => 'Annulé',
        _ => status,
      };
}

class AccountMapping {
  const AccountMapping({required this.id, required this.rawAccount, this.accountCode, this.thirdPartyCode, this.thirdPartyName, required this.createThirdParty, this.note});

  final String id;
  final String rawAccount;
  final String? accountCode;
  final String? thirdPartyCode;
  final String? thirdPartyName;
  final bool createThirdParty;
  final String? note;
}

/// Décode un export Perfecto (Windows-1252) en texte Unicode. Les 32 caractères 0x80-0x9F suivent la table 1252.
String decodeWindows1252(Uint8List bytes) {
  const high = [
    0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
    0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
  ];
  final buf = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80 || b >= 0xA0) {
      buf.writeCharCode(b);
    } else {
      buf.writeCharCode(high[b - 0x80]);
    }
  }
  return buf.toString();
}

/// Le fichier est-il de l'UTF-8 valide ? Sinon on suppose Windows-1252 (export Perfecto).
String decodePerfectoText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return decodeWindows1252(bytes);
  }
}

/// Module 10 : lots d'import Perfecto, analyse côté base, correspondances éditables, essai, application.
class ImportRepository {
  ImportRepository(this._client);

  final SupabaseClient _client;

  Future<List<ImportBatch>> batches(String entityId) async {
    final rows = await _client.from('import_batches').select().eq('entity_id', entityId).order('created_at', ascending: false);
    return rows.map(importBatchFromJson).toList();
  }

  Future<ImportBatch> createBatch({required String cabinetId, required String entityId, required String kind, required String fileName, String? targetJournalId}) async {
    final row = await _client.from('import_batches').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'kind': kind, 'source_file_name': fileName, 'target_journal_id': targetJournalId}).select().single();
    return importBatchFromJson(row);
  }

  Future<Map<String, dynamic>> parseJournalText(String batchId, String text) async =>
      ((await _client.rpc('import_parse_perfecto_journal', params: {'p_batch': batchId, 'p_text': text})) as Map).cast<String, dynamic>();

  Future<int> loadLines(String batchId, List<Map<String, dynamic>> lines) async =>
      ((await _client.rpc('import_load_lines', params: {'p_batch': batchId, 'p_lines': lines})) as num).toInt();

  Future<Map<String, dynamic>> proposeMappings(String batchId) async =>
      ((await _client.rpc('import_propose_mappings', params: {'p_batch': batchId})) as Map).cast<String, dynamic>();

  Future<List<AccountMapping>> mappings(String entityId, String batchId) async {
    final raw = await _client.from('import_lines').select('raw_account').eq('batch_id', batchId);
    final used = {for (final r in raw) r['raw_account'] as String};
    final rows = await _client.from('import_account_mappings').select().eq('entity_id', entityId).inFilter('raw_account', used.toList()).order('raw_account', ascending: true);
    return rows.map(accountMappingFromJson).toList();
  }

  Future<void> updateMapping(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty}) =>
      _client.from('import_account_mappings').update({
        'account_code': accountCode?.trim().isEmpty == true ? null : accountCode?.trim(),
        'third_party_code': thirdPartyCode?.trim().isEmpty == true ? null : thirdPartyCode?.trim().toUpperCase(),
        'third_party_name': thirdPartyName?.trim().isEmpty == true ? null : thirdPartyName?.trim(),
        'create_third_party': ?createThirdParty,
      }).eq('id', id);

  Future<Map<String, dynamic>> apply(String batchId, {required bool dryRun}) async =>
      ((await _client.rpc('import_apply', params: {'p_batch': batchId, 'p_dry_run': dryRun})) as Map).cast<String, dynamic>();

  Future<void> setTargetJournal(String batchId, String? journalId) => _client.from('import_batches').update({'target_journal_id': journalId}).eq('id', batchId);
}

final importRepositoryProvider = Provider<ImportRepository>((ref) => ImportRepository(ref.watch(supabaseClientProvider)));
final importBatchesProvider = FutureProvider.family<List<ImportBatch>, String>((ref, entityId) => ref.watch(importRepositoryProvider).batches(entityId));
final importMappingsProvider = FutureProvider.family<List<AccountMapping>, (String, String)>((ref, key) => ref.watch(importRepositoryProvider).mappings(key.$1, key.$2));
