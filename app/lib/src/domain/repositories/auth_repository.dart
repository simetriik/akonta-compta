import '../auth_models.dart';

/// Authentification : connexion, MFA TOTP, réinitialisation du mot de passe, état de la session.
abstract interface class AuthRepository {
  /// Session courante ; null si personne n'est connecté.
  AuthSession? get currentSession;

  /// Changements d'état d'authentification (connexion, déconnexion, renouvellement de jeton, TOTP vérifié).
  Stream<AuthChange> changes();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Vrai tant que le membre utilise le mot de passe provisoire donné par l'administrateur.
  bool get mustChangePassword;

  /// Change le mot de passe de l'utilisateur connecté et lève l'obligation de le changer.
  Future<void> changePassword(String newPassword);

  Future<MfaStatus> mfaStatus();

  /// Démarre l'enrôlement TOTP.
  Future<TotpEnrollment> enrollTotp();

  /// Vérifie un code TOTP (enrôlement ou défi de connexion) : la session passe en aal2.
  Future<void> verifyTotp({required String factorId, required String code});

  Future<String?> firstVerifiedTotpFactorId();
}
