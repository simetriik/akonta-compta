import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entity_models.dart';
import 'supabase_providers.dart';

/// Module 2 : entités, dirigeants, exercices, associés, périodes, journaux d'ouverture.
class EntitiesRepository {
  EntitiesRepository(this._client);

  final SupabaseClient _client;

  Future<List<EntityDetail>> list() async {
    final rows = await _client.from('entities').select().order('name');
    return rows.map(EntityDetail.fromJson).toList();
  }

  Future<EntityDetail> get(String id) async => EntityDetail.fromJson(await _client.from('entities').select().eq('id', id).single());

  Future<EntityDetail> create(String cabinetId, EntityInput input) async {
    final row = await _client.from('entities').insert({'cabinet_id': cabinetId, ...input.toJson()}).select().single();
    return EntityDetail.fromJson(row);
  }

  Future<void> update(String id, EntityInput input) => _client.from('entities').update(input.toJson()).eq('id', id);

  Future<void> setActive(String id, bool active) => _client.from('entities').update({'is_active': active}).eq('id', id);

  Future<List<Director>> directors(String entityId) async {
    final rows = await _client.from('entity_directors').select().eq('entity_id', entityId).order('sort_order');
    return rows.map(Director.fromJson).toList();
  }

  Future<void> addDirector(String cabinetId, String entityId, {required String fullName, required String position, String? nationality, String? address, bool board = false}) =>
      _client.from('entity_directors').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'full_name': fullName, 'position': position, 'nationality': nationality, 'address': address, 'is_board_member': board});

  Future<void> removeDirector(String id) => _client.from('entity_directors').delete().eq('id', id);

  Future<List<FiscalYear>> fiscalYears(String entityId) async {
    final rows = await _client.from('fiscal_years').select().eq('entity_id', entityId).order('start_date');
    return rows.map(FiscalYear.fromJson).toList();
  }

  Future<FiscalYear> createFiscalYear(String cabinetId, String entityId, {required DateTime start, required DateTime end, String? label, int? capital, int? headcount}) async {
    final row = await _client.from('fiscal_years').insert({
      'cabinet_id': cabinetId,
      'entity_id': entityId,
      'start_date': start.toIso8601String().substring(0, 10),
      'end_date': end.toIso8601String().substring(0, 10),
      'label': ?label,
      'capital': capital,
      'headcount': headcount,
    }).select().single();
    return FiscalYear.fromJson(row);
  }

  Future<void> updateFiscalYear(String id, {int? capital, int? headcount}) =>
      _client.from('fiscal_years').update({'capital': capital, 'headcount': headcount}).eq('id', id);

  Future<List<FiscalYearPartner>> partners(String fiscalYearId) async {
    final rows = await _client.from('fiscal_year_partners').select().eq('fiscal_year_id', fiscalYearId).order('created_at');
    return rows.map(FiscalYearPartner.fromJson).toList();
  }

  Future<void> addPartner(String cabinetId, String fiscalYearId, {required String name, required double sharePercent}) =>
      _client.from('fiscal_year_partners').insert({'cabinet_id': cabinetId, 'fiscal_year_id': fiscalYearId, 'name': name, 'share_percent': sharePercent});

  Future<void> removePartner(String id) => _client.from('fiscal_year_partners').delete().eq('id', id);

  Future<List<Period>> periods(String fiscalYearId) async {
    final rows = await _client.from('periods').select().eq('fiscal_year_id', fiscalYearId).order('period_no');
    return rows.map(Period.fromJson).toList();
  }

  Future<void> lockPeriod(String id) => _client.from('periods').update({'is_locked': true}).eq('id', id);

  Future<void> unlockPeriod(String id, String reason) => _client.from('periods').update({'is_locked': false, 'unlock_reason': reason}).eq('id', id);

  Future<List<EntityHistoryItem>> history(String entityId) async {
    final rows = await _client.from('entity_history').select().eq('entity_id', entityId).order('changed_at', ascending: false).limit(100);
    return rows.map(EntityHistoryItem.fromJson).toList();
  }

  Future<List<JournalTemplate>> journalTemplates() async {
    final rows = await _client.from('journal_templates').select().order('sort_order');
    return rows.map(JournalTemplate.fromJson).toList();
  }

  Future<int> createJournalsFromTemplate(String entityId, List<String> codes) async {
    final r = await _client.rpc('create_journals_from_template', params: {'p_entity': entityId, 'p_codes': codes});
    return (r as num).toInt();
  }

  Future<void> createTreasuryJournal(String cabinetId, String entityId, {required String code, required String label, required String type, required String accountId}) =>
      _client.from('journals').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'code': code, 'label': label, 'type': type, 'treasury_account_id': accountId});

  Future<List<AccountRef>> treasuryAccounts(String entityId) async {
    final rows = await _client.from('accounts').select('id, code, label').eq('entity_id', entityId).eq('class', 5).eq('allow_posting', true).eq('is_active', true).order('code');
    return rows.map(AccountRef.fromJson).toList();
  }

  Future<int> accountCount(String entityId) async {
    final r = await _client.from('accounts').count().eq('entity_id', entityId);
    return r;
  }
}

final entitiesRepositoryProvider = Provider<EntitiesRepository>((ref) => EntitiesRepository(ref.watch(supabaseClientProvider)));
final entitiesListProvider = FutureProvider<List<EntityDetail>>((ref) => ref.watch(entitiesRepositoryProvider).list());
final entityProvider = FutureProvider.family<EntityDetail, String>((ref, id) => ref.watch(entitiesRepositoryProvider).get(id));
final fiscalYearsProvider = FutureProvider.family<List<FiscalYear>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).fiscalYears(entityId));
final periodsProvider = FutureProvider.family<List<Period>, String>((ref, fyId) => ref.watch(entitiesRepositoryProvider).periods(fyId));
final directorsProvider = FutureProvider.family<List<Director>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).directors(entityId));
final entityHistoryProvider = FutureProvider.family<List<EntityHistoryItem>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).history(entityId));
final journalTemplatesProvider = FutureProvider<List<JournalTemplate>>((ref) => ref.watch(entitiesRepositoryProvider).journalTemplates());
