import '../connectivity/connectivity.dart';
import '../../domain/repositories/closing_repository.dart';
import '../../domain/closing_models.dart';

/// Cas d'usage closing : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class ClosingService {
  ClosingService(this._repository, this._online);

  final ClosingRepository _repository;
  final OnlinePolicy _online;

  Future<List<ClosingCheck>> runChecks(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.runChecks(entityId, fyId);
  }

  Future<void> waive(String fyId, String code, String comment) async {
    _online.require('La clôture');
    return _repository.waive(fyId, code, comment);
  }

  Future<int> accountingResult(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.accountingResult(entityId, fyId);
  }

  Future<List<TaxAdjustment>> proposeAdjustments(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.proposeAdjustments(entityId, fyId);
  }

  Future<TaxComputation> computeTax(String entityId, String fyId, List<TaxAdjustment> adjustments) async {
    _online.require('Le calcul de l\'impôt');
    return _repository.computeTax(entityId, fyId, adjustments);
  }

  Future<TaxComputation?> taxComputation(String fyId) async {
    _online.require('La clôture');
    return _repository.taxComputation(fyId);
  }

  Future<FinancialStatements> generateStatements(String entityId, String fyId) async {
    _online.require('Les états financiers');
    return _repository.generateStatements(entityId, fyId);
  }

  Future<FinancialStatements?> latestStatements(String fyId) async {
    _online.require('Les états financiers');
    return _repository.latestStatements(fyId);
  }

  Future<String?> generateResultEntry(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.generateResultEntry(entityId, fyId);
  }

  Future<void> closeProvisional(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.closeProvisional(entityId, fyId);
  }

  Future<void> reopen(String entityId, String fyId, String reason) async {
    _online.require('La clôture');
    return _repository.reopen(entityId, fyId, reason);
  }

  Future<String> closeFinal(String entityId, String fyId, String confirmation) async {
    _online.require('La clôture');
    return _repository.closeFinal(entityId, fyId, confirmation);
  }

  Future<String?> generateOpeningBalances(String entityId, String fyId) async {
    _online.require('La clôture');
    return _repository.generateOpeningBalances(entityId, fyId);
  }

  Future<String?> allocateResult(String entityId, String nextFyId, DateTime date, {required int legalReserve, required int freeReserve, required int dividends, required int carryForward}) async {
    _online.require('La clôture');
    return _repository.allocateResult(entityId, nextFyId, date, legalReserve: legalReserve, freeReserve: freeReserve, dividends: dividends, carryForward: carryForward);
  }
}
