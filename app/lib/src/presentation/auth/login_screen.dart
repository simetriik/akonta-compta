import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../widgets/akonta_logo.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Si le compte existe, un e-mail de réinitialisation a été envoyé.')));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AkontaLogo(height: 56)),
                        const SizedBox(height: 8),
                        Text('Connexion', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          key: const Key('login-email'),
                          decoration: const InputDecoration(labelText: 'Adresse e-mail'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          validator: validateEmail,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          key: const Key('login-password'),
                          decoration: const InputDecoration(labelText: 'Mot de passe'),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          validator: validatePassword,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, key: const Key('login-error'), style: const TextStyle(color: AkColors.toCorrect)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('login-submit'),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Se connecter'),
                        ),
                        TextButton(onPressed: _busy ? null : _reset, child: const Text('Mot de passe oublié ?')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
