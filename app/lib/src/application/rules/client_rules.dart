/// Ce qu'un client du cabinet peut ouvrir dans l'application (D-044). La base reste la garantie ; ceci évite d'afficher
/// des écrans vides ou en erreur.
abstract final class ClientRules {
  static const _routes = ['/saisie', '/pieces', '/factures'];

  /// Accueil, saisie du brouillard, pièces et factures : liste fermée, tout le reste ramène à l'accueil.
  static bool allows(String location) => location == '/' || _routes.any((r) => location == r || location.startsWith('$r/'));
}
