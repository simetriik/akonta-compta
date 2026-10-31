import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reference_models.dart';
import 'supabase_providers.dart';
import '../infrastructure/supabase/mappers/reference_models_mappers.dart';

/// Module 3 : plan de comptes de l'entité, tiers, journaux, modèles d'écritures, taux.
class ReferencesRepository {
  ReferencesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Account>> accounts(String entityId, {String? prefix, String? search, bool onlyActive = false}) async {
    var q = _client.from('accounts').select().eq('entity_id', entityId);
    if (prefix != null && prefix.isNotEmpty) q = q.like('code', '$prefix%');
    if (search != null && search.isNotEmpty) q = q.or('code.like.$search%,label.ilike.%$search%');
    if (onlyActive) q = q.eq('is_active', true);
    final rows = await q.order('code', ascending: true).limit(2000);
    return rows.map(accountFromJson).toList();
  }

  Future<Account> createAccount(String cabinetId, String entityId, {required String code, required String label, bool? isCollective}) async {
    final row = await _client.from('accounts').insert({
      'cabinet_id': cabinetId,
      'entity_id': entityId,
      'code': code,
      'label': label,
      // nature et sens sont hérités du parent par la base ; valeurs de remplissage obligatoires
      'nature': 'balance_sheet',
      'normal_side': 'debit',
      'is_collective': ?isCollective,
    }).select().single();
    return accountFromJson(row);
  }

  Future<void> renameAccount(String id, String label) => _client.from('accounts').update({'label': label}).eq('id', id);

  Future<void> setAccountActive(String id, bool active) => _client.from('accounts').update({'is_active': active}).eq('id', id);

  Future<void> deleteAccount(String id) => _client.from('accounts').delete().eq('id', id);

  Future<List<ThirdParty>> thirdParties(String entityId, {String? search}) async {
    var q = _client.from('third_parties').select('*, third_party_accounts(accounts(code))').eq('entity_id', entityId);
    if (search != null && search.isNotEmpty) q = q.or('code.ilike.%$search%,name.ilike.%$search%');
    final rows = await q.order('code', ascending: true);
    return rows.map(thirdPartyFromJson).toList();
  }

  Future<ThirdParty> saveThirdParty(String cabinetId, String entityId,
      {String? id, required String code, required String name, required String type, String? taxId, String? address, String? phone, String? email, required List<String> collectiveAccountIds}) async {
    final values = {'cabinet_id': cabinetId, 'entity_id': entityId, 'code': code.trim().toUpperCase(), 'name': name.trim(), 'type': type,
        'tax_id': _n(taxId), 'address': _n(address), 'phone': _n(phone), 'email': _n(email)};
    final row = id == null
        ? await _client.from('third_parties').insert(values).select().single()
        : await _client.from('third_parties').update(values).eq('id', id).select().single();
    final tpId = row['id'] as String;
    await _client.from('third_party_accounts').delete().eq('third_party_id', tpId);
    if (collectiveAccountIds.isNotEmpty) {
      await _client.from('third_party_accounts').insert([for (final a in collectiveAccountIds) {'third_party_id': tpId, 'account_id': a}]);
    }
    return thirdPartyFromJson(row);
  }

  Future<void> setThirdPartyActive(String id, bool active) => _client.from('third_parties').update({'is_active': active}).eq('id', id);

  Future<List<Journal>> journals(String entityId) async {
    final rows = await _client.from('journals').select('*, accounts(code)').eq('entity_id', entityId).order('code', ascending: true);
    return rows.map(journalFromJson).toList();
  }

  Future<void> saveJournal(String cabinetId, String entityId, {String? id, required String code, required String label, required String type, String? treasuryAccountId}) async {
    final values = {'cabinet_id': cabinetId, 'entity_id': entityId, 'code': code.trim().toUpperCase(), 'label': label.trim(), 'type': type, 'treasury_account_id': treasuryAccountId};
    if (id == null) {
      await _client.from('journals').insert(values);
    } else {
      await _client.from('journals').update({'label': label.trim(), 'treasury_account_id': treasuryAccountId}).eq('id', id);
    }
  }

  Future<void> setJournalActive(String id, bool active) => _client.from('journals').update({'is_active': active}).eq('id', id);

  /// Référentiel comptable de l'entité : ses modèles d'écritures utilisent les numéros de ce plan.
  Future<String> _accountingSystem(String entityId) async {
    final row = await _client.from('entities').select('accounting_system').eq('id', entityId).single();
    return row['accounting_system'] as String;
  }

  Future<List<EntryTemplate>> templates(String entityId) async {
    final system = await _accountingSystem(entityId);
    final rows = await _client
        .from('entry_templates')
        .select('*, entry_template_lines(*)')
        .or('entity_id.is.null,entity_id.eq.$entityId')
        .eq('accounting_system', system)
        .eq('is_active', true)
        .order('code', ascending: true);
    return rows.map(entryTemplateFromJson).toList();
  }

  Future<void> saveTemplate(String cabinetId, String? entityId, {required String code, required String label, String? journalType, String? description, required List<TemplateLine> lines}) async {
    final row = await _client.from('entry_templates').insert({
      'cabinet_id': cabinetId, 'entity_id': entityId, 'code': code.trim().toUpperCase(), 'label': label.trim(), 'journal_type': journalType, 'description': _n(description),
      if (entityId != null) 'accounting_system': await _accountingSystem(entityId),
    }).select().single();
    await _client.from('entry_template_lines').insert([for (final l in lines) {'template_id': row['id'], ...l.toJson()}]);
  }

  Future<void> deactivateTemplate(String id) => _client.from('entry_templates').update({'is_active': false}).eq('id', id);

  Future<List<TaxRate>> taxRates() async {
    final rows = await _client.from('tax_rates').select().order('code', ascending: true).order('valid_from', ascending: true);
    return rows.map(taxRateFromJson).toList();
  }

  /// Nouveau taux à partir d'une date : le taux précédent du même code est borné à la veille.
  Future<void> addTaxRate(String cabinetId, {required String code, required String label, required double rate, required DateTime validFrom}) async {
    final previous = await _client.from('tax_rates').select('id').eq('cabinet_id', cabinetId).eq('code', code).isFilter('valid_to', null).lt('valid_from', validFrom.toIso8601String().substring(0, 10));
    for (final p in previous) {
      await _client.from('tax_rates').update({'valid_to': validFrom.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}).eq('id', p['id'] as String);
    }
    await _client.from('tax_rates').insert({'cabinet_id': cabinetId, 'code': code.trim().toUpperCase(), 'label': label.trim(), 'rate': rate, 'valid_from': validFrom.toIso8601String().substring(0, 10)});
  }

  static String? _n(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final referencesRepositoryProvider = Provider<ReferencesRepository>((ref) => ReferencesRepository(ref.watch(supabaseClientProvider)));
final accountsProvider = FutureProvider.family<List<Account>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).accounts(entityId));
final thirdPartiesProvider = FutureProvider.family<List<ThirdParty>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).thirdParties(entityId));
final journalsProvider = FutureProvider.family<List<Journal>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).journals(entityId));
final templatesProvider = FutureProvider.family<List<EntryTemplate>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).templates(entityId));
final taxRatesProvider = FutureProvider<List<TaxRate>>((ref) => ref.watch(referencesRepositoryProvider).taxRates());
