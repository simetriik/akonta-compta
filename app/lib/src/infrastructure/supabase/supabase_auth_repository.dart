import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_models.dart';
import '../../domain/repositories/auth_repository.dart';

/// Accès à Supabase Auth : connexion, MFA TOTP, réinitialisation, journalisation des connexions.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  AuthSession? _toSession(User? user) => user == null ? null : AuthSession(userId: user.id, email: user.email);

  AssuranceLevel? _level(AuthenticatorAssuranceLevels? l) => switch (l) {
        AuthenticatorAssuranceLevels.aal1 => AssuranceLevel.aal1,
        AuthenticatorAssuranceLevels.aal2 => AssuranceLevel.aal2,
        _ => null,
      };

  @override
  AuthSession? get currentSession => _toSession(_auth.currentUser);

  @override
  Stream<AuthChange> changes() => _auth.onAuthStateChange.map((s) => AuthChange(session: _toSession(s.session?.user), isTokenRefresh: s.event == AuthChangeEvent.tokenRefreshed));

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
    // Piste d'audit : connexion (fonction SQL, security definer).
    try {
      await _client.rpc('log_audit_event', params: {'p_action': 'login', 'p_payload': {}});
    } catch (_) {
      // La connexion n'échoue pas si la journalisation échoue ; l'écart apparaîtra côté serveur.
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.rpc('log_audit_event', params: {'p_action': 'logout', 'p_payload': {}});
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  bool get mustChangePassword => _auth.currentUser?.userMetadata?['must_change_password'] == true;

  @override
  Future<void> changePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword, data: {'must_change_password': false}));
    try {
      await _client.rpc('log_audit_event', params: {'p_action': 'password_changed', 'p_payload': {}});
    } catch (_) {
      // Le changement a réussi ; l'écart de journalisation apparaîtra côté serveur.
    }
  }

  /// Facteurs lus sur l'utilisateur courant : `listFactors()` rafraîchirait le jeton à chaque appel,
  /// ce qui émet un événement d'authentification et relancerait la redirection en boucle.
  List<Factor> get _verifiedTotpFactors =>
      (_auth.currentUser?.factors ?? const <Factor>[]).where((f) => f.factorType == FactorType.totp && f.status == FactorStatus.verified).toList();

  @override
  Future<MfaStatus> mfaStatus() async {
    final aal = _auth.mfa.getAuthenticatorAssuranceLevel();
    return MfaStatus(currentLevel: _level(aal.currentLevel), nextLevel: _level(aal.nextLevel), hasVerifiedTotp: _verifiedTotpFactors.isNotEmpty);
  }

  @override
  Future<TotpEnrollment> enrollTotp() async {
    final r = await _auth.mfa.enroll(factorType: FactorType.totp, friendlyName: 'Akonta');
    final totp = r.totp;
    if (totp == null) throw const AuthException('Enrôlement TOTP sans secret');
    return TotpEnrollment(factorId: r.id, secret: totp.secret, uri: totp.uri);
  }

  @override
  Future<void> verifyTotp({required String factorId, required String code}) => _auth.mfa.challengeAndVerify(factorId: factorId, code: code.trim());

  @override
  Future<String?> firstVerifiedTotpFactorId() async => _verifiedTotpFactors.firstOrNull?.id;
}
