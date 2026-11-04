import '../../core/formatting.dart';
import '../../domain/closing_models.dart';

/// Destination d'un contrôle en échec : où aller pour le corriger.
enum ClosingCheckTarget { draftEntries, entriesToCorrect, entriesToReview, periods, reconciliation, inventory, references, consultation }

/// Lien proposé sur la ligne d'un contrôle : libellé du bouton et destination.
class ClosingCheckAction {
  const ClosingCheckAction(this.label, this.target);

  final String label;
  final ClosingCheckTarget target;
}

/// Rend les contrôles de clôture lisibles : la phrase qui remplace les clés techniques du résultat SQL
/// (`count`, `accounts`, `debit`…), et le lien vers l'endroit où corriger.
abstract final class ClosingCheckText {
  /// Phrase décrivant le résultat, ou null s'il n'y a rien à ajouter (contrôle conforme, détails absents).
  static String? summary(ClosingCheck c) {
    if (c.status == 'passed') return null;
    final d = c.details;
    switch (c.code) {
      case 'drafts_pending':
        return _count(d, 'écriture en brouillard', 'écritures en brouillard');
      case 'to_correct':
        return _count(d, 'écriture à corriger', 'écritures à corriger');
      case 'unreviewed':
        return _count(d, 'écriture validée pas encore revue', 'écritures validées pas encore revues');
      case 'unlocked_periods':
        return _count(d, 'période non verrouillée', 'périodes non verrouillées');
      case 'unbalanced':
        final debit = _int(d['debit']), credit = _int(d['credit']);
        if (debit == null || credit == null) return null;
        return 'Débit ${Fmt.fcfa(debit, showZero: true)} · crédit ${Fmt.fcfa(credit, showZero: true)} · écart ${Fmt.fcfa((debit - credit).abs(), showZero: true)}';
      case 'inactive_accounts':
        return _list(d['accounts'], 'Compte désactivé mouvementé', 'Comptes désactivés mouvementés');
      case 'reconciliation':
      case 'reconciliations':
        return _list(d['journals'], 'Journal sans état figé', 'Journaux sans état figé');
      case 'suspense_471':
        final balance = _int(d['balance']);
        if (balance == null || balance == 0) return null;
        return 'Solde restant : ${Fmt.balance(balance)}';
      default:
        return null;
    }
  }

  /// Lien vers l'écran qui permet de corriger, pour un contrôle en échec ou levé seulement si utile.
  static ClosingCheckAction? action(ClosingCheck c) {
    if (c.status != 'failed') return null;
    return switch (c.code) {
      'drafts_pending' => const ClosingCheckAction('Voir les brouillons', ClosingCheckTarget.draftEntries),
      'to_correct' => const ClosingCheckAction('Voir les écritures', ClosingCheckTarget.entriesToCorrect),
      'unreviewed' => const ClosingCheckAction('Voir les écritures', ClosingCheckTarget.entriesToReview),
      'unlocked_periods' => const ClosingCheckAction('Voir les périodes', ClosingCheckTarget.periods),
      'reconciliations' || 'reconciliation' => const ClosingCheckAction('Ouvrir le rapprochement', ClosingCheckTarget.reconciliation),
      'depreciation' => const ClosingCheckAction('Ouvrir l\'inventaire', ClosingCheckTarget.inventory),
      'inactive_accounts' => const ClosingCheckAction('Ouvrir les référentiels', ClosingCheckTarget.references),
      'suspense_471' => const ClosingCheckAction('Voir le grand livre', ClosingCheckTarget.consultation),
      _ => null,
    };
  }

  /// Gravité et état en phrase : « Bloquant · en échec » devient « À corriger avant la clôture ».
  static String state(ClosingCheck c) {
    final blocking = c.severity == 'blocking';
    return switch (c.status) {
      'passed' => blocking ? 'Contrôle bloquant' : 'Contrôle d\'alerte',
      'waived' => 'Alerte levée avec un commentaire',
      _ => blocking ? 'À corriger avant la clôture' : 'Alerte : à traiter, ou à lever avec un commentaire',
    };
  }

  /// Ligne complète sous le titre : état puis résultat chiffré s'il y en a un.
  static String subtitle(ClosingCheck c) {
    final s = summary(c);
    return s == null ? state(c) : '${state(c)} · $s';
  }

  static String? _count(Map<String, dynamic> d, String one, String many) {
    final n = _int(d['count']);
    if (n == null) return null;
    return '$n ${n > 1 ? many : one}';
  }

  static String? _list(Object? value, String one, String many) {
    if (value is! List || value.isEmpty) return null;
    final items = value.map((e) => '$e').toList();
    return '${items.length > 1 ? many : one} : ${items.join(', ')}';
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
}
