import '../connectivity/connectivity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/inventory_models.dart';

/// Cas d'usage inventory : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class InventoryService {
  InventoryService(this._repository, this._online);

  final InventoryRepository _repository;
  final OnlinePolicy _online;

  Future<List<FixedAsset>> assets(String entityId) async {
    _online.require('L\'inventaire');
    return _repository.assets(entityId);
  }

  Future<void> saveAsset(String cabinetId, String entityId, Map<String, dynamic> values, {String? id}) async {
    _online.require('L\'inventaire');
    return _repository.saveAsset(cabinetId, entityId, values, id: id);
  }

  Future<List<PlanRow>> plan(String assetId) async {
    _online.require('L\'inventaire');
    return _repository.plan(assetId);
  }

  Future<String?> generateDepreciation(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateDepreciation(entityId, fiscalYearId);
  }

  Future<String?> disposeAsset(
    String assetId, {
    required DateTime date,
    int price = 0,
    String? counterpartAccountId,
    String? thirdPartyId,
    bool scrap = false,
  }) async {
    _online.require('L\'inventaire');
    return _repository.disposeAsset(assetId, date: date, price: price, counterpartAccountId: counterpartAccountId, thirdPartyId: thirdPartyId, scrap: scrap);
  }

  Future<List<StockRow>> stocks(String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.stocks(fiscalYearId);
  }

  Future<void> upsertStock(
    String cabinetId,
    String entityId,
    String fiscalYearId, {
    required String stockAccountId,
    required String variationAccountId,
    required int closingValue,
  }) async {
    _online.require('L\'inventaire');
    return _repository.upsertStock(
      cabinetId,
      entityId,
      fiscalYearId,
      stockAccountId: stockAccountId,
      variationAccountId: variationAccountId,
      closingValue: closingValue,
    );
  }

  Future<String?> generateStockVariations(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateStockVariations(entityId, fiscalYearId);
  }

  Future<List<ProvisionRow>> provisions(String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.provisions(fiscalYearId);
  }

  Future<int> proposeReceivableProvisions(
    String entityId,
    String fiscalYearId, {
    required double rate91to180,
    required double rateOver180,
    Map<String, double> byThirdParty = const {},
  }) async {
    _online.require('L\'inventaire');
    return _repository.proposeReceivableProvisions(entityId, fiscalYearId, rate91to180: rate91to180, rateOver180: rateOver180, byThirdParty: byThirdParty);
  }

  Future<void> updateProvisionAmount(String id, int amount) async {
    _online.require('L\'inventaire');
    return _repository.updateProvisionAmount(id, amount);
  }

  Future<void> addRiskProvision(
    String cabinetId,
    String entityId,
    String fiscalYearId, {
    required String provisionAccountId,
    required String expenseAccountId,
    required String reversalAccountId,
    required int amount,
    required int previousAmount,
    String? note,
  }) async {
    _online.require('L\'inventaire');
    return _repository.addRiskProvision(
      cabinetId,
      entityId,
      fiscalYearId,
      provisionAccountId: provisionAccountId,
      expenseAccountId: expenseAccountId,
      reversalAccountId: reversalAccountId,
      amount: amount,
      previousAmount: previousAmount,
      note: note,
    );
  }

  Future<String?> generateProvisionEntries(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateProvisionEntries(entityId, fiscalYearId);
  }

  Future<List<AccrualRow>> accruals(String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.accruals(fiscalYearId);
  }

  Future<void> addAccrual(
    String cabinetId,
    String entityId,
    String fiscalYearId, {
    required String kind,
    required String description,
    required String accountId,
    required String counterpartAccountId,
    String? thirdPartyId,
    required int totalAmount,
    required DateTime from,
    required DateTime to,
  }) async {
    _online.require('L\'inventaire');
    return _repository.addAccrual(
      cabinetId,
      entityId,
      fiscalYearId,
      kind: kind,
      description: description,
      accountId: accountId,
      counterpartAccountId: counterpartAccountId,
      thirdPartyId: thirdPartyId,
      totalAmount: totalAmount,
      from: from,
      to: to,
    );
  }

  Future<void> deleteAccrual(String id) async {
    _online.require('L\'inventaire');
    return _repository.deleteAccrual(id);
  }

  Future<String?> generateAccruals(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateAccruals(entityId, fiscalYearId);
  }

  Future<List<String>> generateReversals(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateReversals(entityId, fiscalYearId);
  }

  Future<String?> generateFxRevaluation(String entityId, String fiscalYearId) async {
    _online.require('L\'inventaire');
    return _repository.generateFxRevaluation(entityId, fiscalYearId);
  }

  Future<void> setClosingRate(String cabinetId, String currency, DateTime asOf, double rate) async {
    _online.require('L\'inventaire');
    return _repository.setClosingRate(cabinetId, currency, asOf, rate);
  }
}
