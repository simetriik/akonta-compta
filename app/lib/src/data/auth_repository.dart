import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';

/// Niveau d'assurance de la session et facteurs TOTP (conception §10.1).
class MfaStatus {
  const MfaStatus({required this.currentLevel, required this.nextLevel, required this.hasVerifiedTotp});

  final AuthenticatorAssuranceLevels? currentLevel;
  final AuthenticatorAssuranceLevels? nextLevel;
  final bool hasVerifiedTotp;

  /// Un facteur existe mais la session n'a pas encore été vérifiée : défi TOTP requis.
  bool get challengeRequired =>
      currentLevel == AuthenticatorAssuranceLevels.aal1 && nextLevel == AuthenticatorAssuranceLevels.aal2;

  bool get isAal2 => currentLevel == AuthenticatorAssuranceLevels.aal2;
}

/// Accès à Supabase Auth : connexion, MFA TOTP, réinitialisation, journalisation des connexions.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
    // Piste d'audit : connexion (fonction SQL, security definer).
    try {
      await _client.rpc('log_audit_event', params: {'p_action': 'login', 'p_payload': {}});
    } catch (_) {
      // La connexion n'échoue pas si la journalisation échoue ; l'écart apparaîtra côté serveur.
    }
  }

  Future<void> signOut() async {
    try {
      await _client.rpc('log_audit_event', params: {'p_action': 'logout', 'p_payload': {}});
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) => _auth.resetPasswordForEmail(email.trim());

  Future<void> updatePassword(String newPassword) => _auth.updateUser(UserAttributes(password: newPassword));

  /// Facteurs lus sur l'utilisateur courant : `listFactors()` rafraîchirait le jeton à chaque appel,
  /// ce qui émet un événement d'authentification et relancerait la redirection en boucle.
  List<Factor> get _verifiedTotpFactors =>
      (_auth.currentUser?.factors ?? const <Factor>[]).where((f) => f.factorType == FactorType.totp && f.status == FactorStatus.verified).toList();

  Future<MfaStatus> mfaStatus() async {
    final aal = _auth.mfa.getAuthenticatorAssuranceLevel();
    return MfaStatus(currentLevel: aal.currentLevel, nextLevel: aal.nextLevel, hasVerifiedTotp: _verifiedTotpFactors.isNotEmpty);
  }

  /// Démarre l'enrôlement TOTP : renvoie l'identifiant du facteur, le secret et l'URI otpauth.
  Future<AuthMFAEnrollResponse> enrollTotp() =>
      _auth.mfa.enroll(factorType: FactorType.totp, friendlyName: 'Akonta');

  /// Vérifie un code TOTP (enrôlement ou défi de connexion) : la session passe en aal2.
  Future<void> verifyTotp({required String factorId, required String code}) =>
      _auth.mfa.challengeAndVerify(factorId: factorId, code: code.trim());

  Future<String?> firstVerifiedTotpFactorId() async => _verifiedTotpFactors.firstOrNull?.id;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseClientProvider)));

final mfaStatusProvider = FutureProvider<MfaStatus?>((ref) async {
  ref.watch(authStateProvider);   // niveau aal : recalculé après vérification TOTP
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).mfaStatus();
});
