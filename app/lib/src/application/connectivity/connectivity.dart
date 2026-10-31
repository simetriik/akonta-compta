import '../../core/errors/errors.dart';

/// État de la connexion de l'appareil au service de données ; implémenté par l'infrastructure.
abstract interface class ConnectivityPort {
  /// Dernier état connu.
  bool get isOnline;

  /// Changements d'état (true = en ligne).
  Stream<bool> get changes;

  /// Vérifie maintenant que le service répond.
  Future<bool> check();
}

/// Connexion supposée toujours disponible : valeur par défaut (tests, première génération) avant branchement du moniteur réel.
class AlwaysOnline implements ConnectivityPort {
  const AlwaysOnline();

  @override
  bool get isOnline => true;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> check() async => true;
}

/// Règle d'usage hors connexion : certaines fonctions (calculs, validation, clôture…) exigent d'être en ligne et sont refusées sinon,
/// avec un message clair ; les écrans désactivent alors les boutons correspondants.
class OnlinePolicy {
  const OnlinePolicy(this._connectivity);

  final ConnectivityPort _connectivity;

  bool get isOnline => _connectivity.isOnline;

  /// Lève une erreur « hors connexion » si l'appareil n'est pas en ligne ; `capability` commence la phrase (« Le grand livre »).
  void require(String capability) {
    if (!_connectivity.isOnline) throw AppError.offline(capability);
  }
}
