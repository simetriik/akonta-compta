/// Modèles d'authentification indépendants du fournisseur : session, niveau d'assurance, enrôlement TOTP.
library;

/// Niveau d'assurance de la session : aal1 (mot de passe), aal2 (mot de passe et code TOTP vérifié).
enum AssuranceLevel { aal1, aal2 }

/// Niveau d'assurance de la session et facteurs TOTP (conception §10.1).
class MfaStatus {
  const MfaStatus({required this.currentLevel, required this.nextLevel, required this.hasVerifiedTotp});

  final AssuranceLevel? currentLevel;
  final AssuranceLevel? nextLevel;
  final bool hasVerifiedTotp;

  /// Un facteur existe mais la session n'a pas encore été vérifiée : défi TOTP requis.
  bool get challengeRequired => currentLevel == AssuranceLevel.aal1 && nextLevel == AssuranceLevel.aal2;

  bool get isAal2 => currentLevel == AssuranceLevel.aal2;
}

/// Facteur TOTP en cours d'enrôlement : identifiant, secret à saisir à la main et URI otpauth du code QR.
class TotpEnrollment {
  const TotpEnrollment({required this.factorId, required this.secret, required this.uri});

  final String factorId;
  final String secret;
  final String uri;
}

/// Utilisateur connecté.
class AuthSession {
  const AuthSession({required this.userId, this.email});

  final String userId;
  final String? email;
}

/// Changement d'état d'authentification ; `isTokenRefresh` distingue le simple renouvellement du jeton (sans effet sur la navigation).
class AuthChange {
  const AuthChange({required this.session, required this.isTokenRefresh});

  final AuthSession? session;
  final bool isTokenRefresh;
}
