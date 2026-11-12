import '../../core/formatting.dart';

/// Nature du résultat en instance d'affectation à l'ouverture d'un exercice.
enum ResultKind { none, profit, loss }

/// Règles de l'affectation du résultat (AN-38) : un bénéfice se répartit en totalité, une perte se reporte à nouveau.
class ResultAllocation {
  const ResultAllocation._();

  /// [pending] : résultat en instance (bénéfice > 0, perte < 0, 0 si rien ou à-nouveaux non validés).
  static ResultKind kind(int pending) => pending > 0 ? ResultKind.profit : (pending < 0 ? ResultKind.loss : ResultKind.none);

  /// Contrôle des montants saisis ; `null` si l'écriture peut être demandée.
  static String? check(int pending, {required int legal, required int free, required int dividends, required int carry}) {
    final total = legal + free + dividends + carry;
    switch (kind(pending)) {
      case ResultKind.loss:
        return total == 0 ? null : 'Le résultat est une perte : elle se reporte à nouveau, sans réserve ni dividende.';
      case ResultKind.profit:
        if (total == pending) return null;
        return 'Le total affecté (${Fmt.fcfa(total, showZero: true)}) doit égaler le bénéfice en instance (${Fmt.fcfa(pending, showZero: true)}).';
      case ResultKind.none:
        return total > 0 ? null : 'Montant à affecter nul. Validez d\'abord les à-nouveaux si le résultat est attendu.';
    }
  }
}
