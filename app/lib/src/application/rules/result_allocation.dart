import '../../core/formatting.dart';

/// Règles de l'affectation du bénéfice en instance (AN-38, AN-39). La perte ne se répartit pas : elle se reporte à nouveau (action distincte).
class ResultAllocation {
  const ResultAllocation._();

  /// Contrôle des montants saisis ; `null` si l'écriture peut être demandée. [profit] : bénéfice en instance (0 si aucun).
  static String? check(int profit, {required int legal, required int free, required int dividends, required int carry}) {
    final total = legal + free + dividends + carry;
    if (profit > 0) {
      return total == profit ? null : 'Le total affecté (${Fmt.fcfa(total, showZero: true)}) doit égaler le bénéfice en instance (${Fmt.fcfa(profit, showZero: true)}).';
    }
    return total > 0 ? null : 'Montant à affecter nul. Validez d\'abord les à-nouveaux si un résultat est attendu.';
  }
}
