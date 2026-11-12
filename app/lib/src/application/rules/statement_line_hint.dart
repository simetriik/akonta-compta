/// Contrôle de cohérence entre le sens d'une ligne de relevé et la classe du compte de contrepartie (AN-14).
class StatementLineHint {
  const StatementLineHint._();

  /// Avertissement quand une entrée d'argent est affectée à un compte de charges (classe 6)
  /// ou une sortie d'argent à un compte de produits (classe 7) ; `null` sinon.
  /// [isInflow] : la ligne du relevé est une entrée (crédit bancaire).
  static String? counterpartWarning({required bool isInflow, required int accountClass}) {
    if (isInflow && accountClass == 6) {
      return 'Une entrée d\'argent est affectée à un compte de charges (classe 6). S\'il s\'agit de l\'encaissement d\'un client, choisissez plutôt un compte de tiers (411) ; '
          'un remboursement de charge reste possible.';
    }
    if (!isInflow && accountClass == 7) {
      return 'Une sortie d\'argent est affectée à un compte de produits (classe 7). S\'il s\'agit d\'un paiement à un fournisseur, choisissez plutôt un compte de tiers (401) ou de charges.';
    }
    return null;
  }
}
