import '../inventory_models.dart';

abstract interface class InventoryRepository {
  Future<List<FixedAsset>> assets(String entityId);

  Future<void> saveAsset(String cabinetId, String entityId, Map<String, dynamic> values, {String? id});

  Future<List<PlanRow>> plan(String assetId);

  Future<String?> generateDepreciation(String entityId, String fiscalYearId);

  Future<String?> disposeAsset(String assetId, {required DateTime date, int price = 0, String? counterpartAccountId, String? thirdPartyId, bool scrap = false});

  Future<List<StockRow>> stocks(String fiscalYearId);

  Future<void> upsertStock(String cabinetId, String entityId, String fiscalYearId, {required String stockAccountId, required String variationAccountId, required int closingValue});

  Future<String?> generateStockVariations(String entityId, String fiscalYearId);

  Future<List<ProvisionRow>> provisions(String fiscalYearId);

  Future<int> proposeReceivableProvisions(String entityId, String fiscalYearId, {required double rate91to180, required double rateOver180, Map<String, double> byThirdParty = const {}});

  Future<void> updateProvisionAmount(String id, int amount);

  Future<void> addRiskProvision(String cabinetId, String entityId, String fiscalYearId, {required String provisionAccountId, required String expenseAccountId, required String reversalAccountId, required int amount, required int previousAmount, String? note});

  Future<String?> generateProvisionEntries(String entityId, String fiscalYearId);

  Future<List<AccrualRow>> accruals(String fiscalYearId);

  Future<void> addAccrual(String cabinetId, String entityId, String fiscalYearId, {required String kind, required String description, required String accountId, required String counterpartAccountId, String? thirdPartyId, required int totalAmount, required DateTime from, required DateTime to});

  Future<void> deleteAccrual(String id);

  Future<String?> generateAccruals(String entityId, String fiscalYearId);

  Future<List<String>> generateReversals(String entityId, String fiscalYearId);

  Future<String?> generateFxRevaluation(String entityId, String fiscalYearId);

  Future<void> setClosingRate(String cabinetId, String currency, DateTime asOf, double rate);
}
