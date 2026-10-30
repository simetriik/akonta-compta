import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:akonta/design/design.dart';

import '../../core/config.dart';
import '../../data/auth_repository.dart';

/// Connexion e-mail + mot de passe (12 caractères minimum) et lien de réinitialisation.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onSignedIn});

  /// Appelé après connexion réussie (le routeur redirige sinon).
  final VoidCallback? onSignedIn;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Adresse e-mail requise';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Adresse e-mail invalide';
    return null;
  }

  static String? validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Mot de passe requis';
    if (s.length < AppConfig.minPasswordLength) return 'Au moins ${AppConfig.minPasswordLength} caractères';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(email: _email.text, password: _password.text);
      widget.onSignedIn?.call();
    } on AuthException catch (e) {
      setState(() => _error = _frenchAuthError(e));
    } catch (e) {
      setState(() => _error = 'Connexion impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _frenchAuthError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'E-mail ou mot de passe incorrect.';
    if (m.contains('too many requests') || m.contains('rate limit')) {
      return 'Trop de tentatives : compte temporairement verrouillé, réessayez dans quelques minutes.';
    }
    if (m.contains('email not confirmed')) return 'Adresse e-mail non confirmée : utilisez le lien reçu par e-mail.';
    return 'Connexion refusée : ${e.message}';
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (validateEmail(email) != null) {
      setState(() => _error = 'Saisissez votre adresse e-mail pour recevoir le lien de réinitialisation.');
      return;
    }
    await ref.read(authRepositoryProvider).resetPassword(email);
    if (!mounted) return;
    showAkToast(context, 'Si le compte existe, un e-mail de réinitialisation a été envoyé.');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AkSpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AkLogo(height: 72)),
                const SizedBox(height: AkSpace.s8),
                AkCard(
                  padding: const EdgeInsets.all(AkSpace.s8),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Connexion', style: AkText.titleLg.copyWith(color: t.text)),
                          const SizedBox(height: AkSpace.s5),
                          AkTextField(
                            key: const Key('login-email'),
                            controller: _email,
                            label: 'Adresse e-mail',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            validator: validateEmail,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AkSpace.s5),
                          AkTextField(
                            key: const Key('login-password'),
                            controller: _password,
                            label: 'Mot de passe',
                            obscureText: _hidePassword,
                            autofillHints: const [AutofillHints.password],
                            validator: validatePassword,
                            onSubmitted: (_) => _submit(),
                            helper: '${AppConfig.minPasswordLength} caractères minimum',
                            suffix: AkIconButton(
                              icon: _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              tooltip: _hidePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                              dense: true,
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AkButton.ghost('Mot de passe oublié ?', dense: true, onPressed: _busy ? null : _reset),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AkSpace.s2),
                            AkBanner(
                              kind: AkBannerKind.danger,
                              child: Text(_error!, key: const Key('login-error')),
                            ),
                          ],
                          const SizedBox(height: AkSpace.s5),
                          AkButton.primary('Se connecter', key: const Key('login-submit'), expand: true, loading: _busy, onPressed: _submit),
                          const SizedBox(height: AkSpace.s5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_outline, size: 16, color: t.textMuted),
                              const SizedBox(width: AkSpace.s2),
                              Expanded(
                                child: Text(
                                  'Pour l\'associé et l\'administrateur, un code de vérification sera demandé ensuite.',
                                  style: AkText.caption.copyWith(color: t.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AkSpace.s8),
                Text(
                  'La comptabilité OHADA, sans rien oublier',
                  textAlign: TextAlign.center,
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
