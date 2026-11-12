import '../closing_models.dart';

abstract interface class ClosingRepository {
  Future<List<ClosingCheck>> runChecks(String entityId, String fyId);

  Future<void> waive(String fyId, String code, String comment);

  Future<int> accountingResult(String entityId, String fyId);

  /// Résultat en instance d'affectation à l'ouverture de l'exercice suivant : bénéfice > 0, perte < 0, 0 si rien.
  Future<int> pendingResult(String entityId, String nextFyId);

  Future<List<TaxAdjustment>> proposeAdjustments(String entityId, String fyId);

  Future<TaxComputation> computeTax(String entityId, String fyId, List<TaxAdjustment> adjustments);

  Future<TaxComputation?> taxComputation(String fyId);

  Future<FinancialStatements> generateStatements(String entityId, String fyId);

  Future<FinancialStatements?> latestStatements(String fyId);

  Future<String?> generateResultEntry(String entityId, String fyId);

  Future<void> closeProvisional(String entityId, String fyId);

  Future<void> reopen(String entityId, String fyId, String reason);

  Future<String> closeFinal(String entityId, String fyId, String confirmation);

  Future<String?> generateOpeningBalances(String entityId, String fyId);

  Future<String?> allocateResult(String entityId, String nextFyId, DateTime date, {required int legalReserve, required int freeReserve, required int dividends, required int carryForward});
}
