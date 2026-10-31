import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'consultation_repository.dart';
import 'supabase_providers.dart';
import '../infrastructure/supabase/mappers/inventory_repository_mappers.dart';

class FixedAsset {
  const FixedAsset({required this.id, required this.code, required this.designation, required this.assetAccountCode, required this.acquisitionDate, required this.serviceDate, required this.grossValue, required this.salvageValue, required this.method, required this.durationMonths, this.decliningCoefficient, required this.priorDepreciation, required this.status, this.disposalDate, this.disposalPrice});

  final String id;
  final String code;
  final String designation;
  final String assetAccountCode;
  final DateTime acquisitionDate;
  final DateTime serviceDate;
  final int grossValue;
  final int salvageValue;
  final String method;
  final int durationMonths;
  final double? decliningCoefficient;
  final int priorDepreciation;
  final String status;
  final DateTime? disposalDate;
  final int? disposalPrice;

  String get statusLabel => switch (status) { 'in_service' => 'En service', 'disposed' => 'Cédée', 'scrapped' => 'Rebut', _ => status };
}

class PlanRow {
  const PlanRow({required this.yearNo, required this.periodStart, required this.periodEnd, required this.rate, required this.charge, required this.cumulated, required this.netBookValue});

  final int yearNo;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double rate;
  final int charge;
  final int cumulated;
  final int netBookValue;
}

class StockRow {
  const StockRow({required this.id, required this.stockAccountCode, required this.variationAccountCode, required this.openingValue, required this.closingValue, this.entryId});

  final String id;
  final String stockAccountCode;
  final String variationAccountCode;
  final int openingValue;
  final int closingValue;
  final String? entryId;
}

class ProvisionRow {
  const ProvisionRow({required this.id, required this.kind, this.thirdPartyCode, required this.baseAmount, this.rate, required this.amount, required this.previousAmount, this.note, this.entryId});

  final String id;
  final String kind;
  final String? thirdPartyCode;
  final int baseAmount;
  final double? rate;
  final int amount;
  final int previousAmount;
  final String? note;
  final String? entryId;
}

class AccrualRow {
  const AccrualRow({required this.id, required this.kind, required this.description, required this.accountCode, required this.counterpartCode, required this.totalAmount, required this.periodFrom, required this.periodTo, required this.amount, this.entryId, this.reversalEntryId});

  final String id;
  final String kind;
  final String description;
  final String accountCode;
  final String counterpartCode;
  final int totalAmount;
  final DateTime periodFrom;
  final DateTime periodTo;
  final int amount;
  final String? entryId;
  final String? reversalEntryId;

  static const kindLabels = {'cap': 'Charge à payer', 'par': 'Produit à recevoir', 'cca': 'Charge constatée d\'avance', 'pca': 'Produit constaté d\'avance'};
}

/// Module 8 : immobilisations, stocks, provisions, régularisations, écarts de conversion.
class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<List<FixedAsset>> assets(String entityId) async {
    final rows = await _client.from('fixed_assets').select('*, accounts!fixed_assets_asset_account_id_fkey(code)').eq('entity_id', entityId).order('code', ascending: true);
    return rows.map(fixedAssetFromJson).toList();
  }

  Future<void> saveAsset(String cabinetId, String entityId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await _client.from('fixed_assets').insert({'cabinet_id': cabinetId, 'entity_id': entityId, ...values});
    } else {
      await _client.from('fixed_assets').update(values).eq('id', id);
    }
  }

  Future<List<PlanRow>> plan(String assetId) async {
    final rows = await _client.rpc('depreciation_plan', params: {'p_asset': assetId}) as List;
    return rows.map((j) => planRowFromJson(j as Map<String, dynamic>)).toList();
  }

  Future<String?> generateDepreciation(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_depreciation', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  Future<String?> disposeAsset(String assetId, {required DateTime date, int price = 0, String? counterpartAccountId, String? thirdPartyId, bool scrap = false}) async =>
      (await _client.rpc('dispose_asset', params: {'p_asset': assetId, 'p_date': _d(date), 'p_price': price, 'p_counterpart_account': counterpartAccountId, 'p_third_party': thirdPartyId, 'p_scrap': scrap})) as String?;

  Future<List<StockRow>> stocks(String fiscalYearId) async {
    final rows = await _client.from('inventory_stocks').select('*, stock:accounts!inventory_stocks_stock_account_id_fkey(code), variation:accounts!inventory_stocks_variation_account_id_fkey(code)').eq('fiscal_year_id', fiscalYearId).order('created_at', ascending: true);
    return rows.map(stockRowFromJson).toList();
  }

  Future<void> upsertStock(String cabinetId, String entityId, String fiscalYearId, {required String stockAccountId, required String variationAccountId, required int closingValue}) =>
      _client.from('inventory_stocks').upsert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'stock_account_id': stockAccountId, 'variation_account_id': variationAccountId, 'closing_value': closingValue}, onConflict: 'fiscal_year_id,stock_account_id');

  Future<String?> generateStockVariations(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_stock_variations', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  Future<List<ProvisionRow>> provisions(String fiscalYearId) async {
    final rows = await _client.from('provisions').select('*, third_parties(code)').eq('fiscal_year_id', fiscalYearId).order('kind', ascending: true).order('created_at', ascending: true);
    return rows.map(provisionRowFromJson).toList();
  }

  Future<int> proposeReceivableProvisions(String entityId, String fiscalYearId, {required double rate91to180, required double rateOver180, Map<String, double> byThirdParty = const {}}) async =>
      ((await _client.rpc('propose_receivable_provisions', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId, 'p_bucket_rates': {'d91_180': rate91to180, 'over_180': rateOver180}, 'p_third_party_rates': byThirdParty})) as num).toInt();

  Future<void> updateProvisionAmount(String id, int amount) => _client.from('provisions').update({'amount': amount}).eq('id', id);

  Future<void> addRiskProvision(String cabinetId, String entityId, String fiscalYearId, {required String provisionAccountId, required String expenseAccountId, required String reversalAccountId, required int amount, required int previousAmount, String? note}) =>
      _client.from('provisions').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'kind': 'risk', 'provision_account_id': provisionAccountId, 'expense_account_id': expenseAccountId, 'reversal_account_id': reversalAccountId, 'amount': amount, 'previous_amount': previousAmount, 'note': note});

  Future<String?> generateProvisionEntries(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_provision_entries', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  Future<List<AccrualRow>> accruals(String fiscalYearId) async {
    final rows = await _client.from('accruals').select('*, account:accounts!accruals_account_id_fkey(code), counterpart:accounts!accruals_counterpart_account_id_fkey(code)').eq('fiscal_year_id', fiscalYearId).order('created_at', ascending: true);
    return rows.map(accrualRowFromJson).toList();
  }

  Future<void> addAccrual(String cabinetId, String entityId, String fiscalYearId, {required String kind, required String description, required String accountId, required String counterpartAccountId, String? thirdPartyId, required int totalAmount, required DateTime from, required DateTime to}) =>
      _client.from('accruals').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'fiscal_year_id': fiscalYearId, 'kind': kind, 'description': description, 'account_id': accountId, 'counterpart_account_id': counterpartAccountId, 'third_party_id': thirdPartyId, 'total_amount': totalAmount, 'period_from': _d(from), 'period_to': _d(to), 'amount': 0});

  Future<void> deleteAccrual(String id) => _client.from('accruals').delete().eq('id', id);

  Future<String?> generateAccruals(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_accruals', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  Future<List<String>> generateReversals(String entityId, String fiscalYearId) async =>
      ((await _client.rpc('generate_reversals', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as List).cast<String>();

  Future<String?> generateFxRevaluation(String entityId, String fiscalYearId) async =>
      (await _client.rpc('generate_fx_revaluation', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId})) as String?;

  Future<void> setClosingRate(String cabinetId, String currency, DateTime asOf, double rate) =>
      _client.from('closing_rates').upsert({'cabinet_id': cabinetId, 'currency_code': currency, 'as_of': _d(asOf), 'rate': rate});
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => InventoryRepository(ref.watch(supabaseClientProvider)));
final fixedAssetsProvider = FutureProvider.family<List<FixedAsset>, String>((ref, entityId) => ref.watch(inventoryRepositoryProvider).assets(entityId));
final stocksProvider = FutureProvider.family<List<StockRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).stocks(fyId));
final provisionsProvider = FutureProvider.family<List<ProvisionRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).provisions(fyId));
final accrualsProvider = FutureProvider.family<List<AccrualRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).accruals(fyId));

/// Stock initial par compte de stock : solde des comptes de classe 3 à la date d'ouverture de l'exercice
/// (à-nouveaux), lu dans la balance ; affiché avant même la génération des variations.
final stockOpeningBalancesProvider = FutureProvider.family<Map<String, int>, ({String entityId, DateTime startDate})>((ref, key) async {
  final rows = await ref.watch(consultationRepositoryProvider).trialBalance(ConsultationParams(entityId: key.entityId, from: key.startDate, to: key.startDate, classNo: 3));
  return {for (final r in rows) r.accountCode: r.openingDebit - r.openingCredit + r.periodDebit - r.periodCredit};
});
