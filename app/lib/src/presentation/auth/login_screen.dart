import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/config.dart';
import '../../application/providers/repositories.dart';

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
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pas d'e-mail de réinitialisation : c'est l'administrateur du cabinet qui donne un nouveau mot de passe provisoire.
  Future<void> _forgot() => showDialog<void>(
    context: context,
    builder: (ctx) => AkDialog(
      title: 'Mot de passe oublié',
      size: AkDialogSize.s,
      content: const Text(
        'Demandez à l\'administrateur de votre cabinet un nouveau mot de passe provisoire '
        '(Collaborateurs, icône clé). Vous le changerez à votre prochaine connexion.',
      ),
      actions: [AkButton.primary('Compris', onPressed: () => Navigator.pop(ctx))],
    ),
  );

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
                const Center(child: AkLogo(height: 88, symbolOnly: true)),
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
                            child: AkButton.ghost('Mot de passe oublié ?', dense: true, onPressed: _busy ? null : _forgot),
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
