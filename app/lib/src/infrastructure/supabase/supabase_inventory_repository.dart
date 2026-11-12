import 'package:supabase_flutter/supabase_flutter.dart';
import 'mappers/inventory_repository_mappers.dart';
import '../../domain/inventory_models.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Module 8 : immobilisations, stocks, provisions, régularisations, écarts de conversion.
class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<List<FixedAsset>> assets(String entityId) async {
    final rows = await _client.from('fixed_assets').select('*, accounts!fixed_assets_asset_account_id_fkey(code)').eq('entity_id', entityId).order('code', ascending: true);
    return rows.map(fixedAssetFromJson).toList();
  }

  @override
  Future<void> saveAsset(String cabinetId, String entityId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await _client.from('fixed_assets').insert({'cabinet_id': cabinetId, 'entity_id': entityId, ...values});
    } else {
      await _client.from('fixed_assets').update(values).eq('id', id);
    }
  }

  @override
  Future<List<PlanRow>> plan(String assetId) async {
    final rows = await _client.rpc('depreciation_plan', params: {'p_asset': assetId}) as List;
    return rows.map((j) => planRowFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<String?> generateDepreciation(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_depreciation', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  @override
  Future<String?> disposeAsset(String assetId, {required DateTime date, int price = 0, String? counterpartAccountId, String? thirdPartyId, bool scrap = false}) async =>
      (await _client.rpc('dispose_asset', params: {'p_asset': assetId, 'p_date': _d(date), 'p_price': price, 'p_counterpart_account': counterpartAccountId, 'p_third_party': thirdPartyId, 'p_scrap': scrap})) as String?;

  @override
  Future<List<StockRow>> stocks(String fiscalYearId) async {
    final rows = await _client.from('inventory_stocks').select('*, stock:accounts!inventory_stocks_stock_account_id_fkey(code), variation:accounts!inventory_stocks_variation_account_id_fkey(code)').eq('fiscal_year_id', fiscalYearId).order('created_at', ascending: true);
    return rows.map(stockRowFromJson).toList();
  }

  @override
  Future<void> upsertStock(String cabinetId, String entityId, String fiscalYearId, {required String stockAccountId, required String variationAccountId, required int closingValue}) =>
      _client.from('inventory_stocks').upsert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'stock_account_id': stockAccountId, 'variation_account_id': variationAccountId, 'closing_value': closingValue}, onConflict: 'fiscal_year_id,stock_account_id');

  @override
  Future<String?> generateStockVariations(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_stock_variations', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  @override
  Future<List<ProvisionRow>> provisions(String fiscalYearId) async {
    final rows = await _client.from('provisions').select('*, third_parties(code)').eq('fiscal_year_id', fiscalYearId).order('kind', ascending: true).order('created_at', ascending: true);
    return rows.map(provisionRowFromJson).toList();
  }

  @override
  Future<int> proposeReceivableProvisions(String entityId, String fiscalYearId, {required double rate91to180, required double rateOver180, Map<String, double> byThirdParty = const {}}) async =>
      ((await _client.rpc('propose_receivable_provisions', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId, 'p_bucket_rates': {'d91_180': rate91to180, 'over_180': rateOver180}, 'p_third_party_rates': byThirdParty})) as num).toInt();

  @override
  Future<void> deleteProvision(String id) => _client.from('provisions').delete().eq('id', id);

  @override
  Future<void> updateProvisionAmount(String id, int amount) => _client.from('provisions').update({'amount': amount}).eq('id', id);

  @override
  Future<void> addRiskProvision(String cabinetId, String entityId, String fiscalYearId, {required String provisionAccountId, required String expenseAccountId, required String reversalAccountId, required int amount, required int previousAmount, String? note}) =>
      _client.from('provisions').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'kind': 'risk', 'provision_account_id': provisionAccountId, 'expense_account_id': expenseAccountId, 'reversal_account_id': reversalAccountId, 'amount': amount, 'previous_amount': previousAmount, 'note': note});

  @override
  Future<String?> generateProvisionEntries(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_provision_entries', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  @override
  Future<List<AccrualRow>> accruals(String fiscalYearId) async {
    final rows = await _client.from('accruals').select('*, account:accounts!accruals_account_id_fkey(code), counterpart:accounts!accruals_counterpart_account_id_fkey(code)').eq('fiscal_year_id', fiscalYearId).order('created_at', ascending: true);
    return rows.map(accrualRowFromJson).toList();
  }

  @override
  Future<void> addAccrual(String cabinetId, String entityId, String fiscalYearId, {required String kind, required String description, required String accountId, required String counterpartAccountId, String? thirdPartyId, required int totalAmount, required DateTime from, required DateTime to}) =>
      _client.from('accruals').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'kind': kind, 'description': description, 'account_id': accountId, 'counterpart_account_id': counterpartAccountId, 'third_party_id': thirdPartyId, 'total_amount': totalAmount, 'period_from': _d(from), 'period_to': _d(to), 'amount': 0});

  @override
  Future<void> deleteAccrual(String id) => _client.from('accruals').delete().eq('id', id);

  @override
  Future<String?> generateAccruals(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_accruals', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  @override
  Future<List<String>> generateReversals(String entityId, String fiscalYearId) async =>
      ((await _client.rpc('generate_reversals', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as List).cast<String>();

  @override
  Future<String?> generateFxRevaluation(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_fx_revaluation', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  @override
  Future<void> setClosingRate(String cabinetId, String currency, DateTime asOf, double rate) =>
      _client.from('closing_rates').upsert({'cabinet_id': cabinetId, 'currency_code': currency, 'as_of': _d(asOf), 'rate': rate});
}
