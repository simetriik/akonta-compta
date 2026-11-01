import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/repositories.dart';
import '../../core/errors/errors.dart';
import '../../core/password_policy.dart';

/// Formulaire de nouveau mot de passe (saisie + confirmation), partagé par l'écran obligatoire et la boîte « Mon compte ».
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key, required this.onDone, this.onCancel});

  final VoidCallback onDone;
  final VoidCallback? onCancel;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(_password.text);
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, action: 'Changement impossible'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(
              key: const Key('new-password'),
              controller: _password,
              label: 'Nouveau mot de passe',
              obscureText: _hide,
              autofillHints: const [AutofillHints.newPassword],
              validator: PasswordPolicy.validate,
              helper: '12 caractères minimum, avec minuscule, majuscule et chiffre',
              autofocus: true,
              suffix: AkIconButton(
                icon: _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: _hide ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                dense: true,
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            const SizedBox(height: AkSpace.s3),
            AkTextField(
              key: const Key('confirm-password'),
              controller: _confirm,
              label: 'Confirmer le mot de passe',
              obscureText: _hide,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => PasswordPolicy.validateConfirmation(v, _password.text),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
              ),
            const SizedBox(height: AkSpace.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null) ...[
                  AkButton.secondary('Annuler', onPressed: _busy ? null : widget.onCancel),
                  const SizedBox(width: AkSpace.s2),
                ],
                AkButton.primary('Enregistrer', key: const Key('password-submit'), loading: _busy, onPressed: _submit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Première connexion avec le mot de passe provisoire : le membre choisit le sien avant d'accéder à l'application.
class ChangePasswordScreen extends ConsumerWidget {
  const ChangePasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Center(child: AkLogo(height: 72, symbolOnly: true)),
                const SizedBox(height: AkSpace.s8),
                AkCard(
                  padding: const EdgeInsets.all(AkSpace.s8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Choisissez votre mot de passe', style: AkText.titleLg.copyWith(color: t.text)),
                      const SizedBox(height: AkSpace.s2),
                      Text(
                        'Vous utilisez un mot de passe provisoire. Choisissez-en un que vous seul connaissez.',
                        style: AkText.body.copyWith(color: t.textMuted),
                      ),
                      const SizedBox(height: AkSpace.s5),
                      ChangePasswordForm(onDone: onDone),
                      const SizedBox(height: AkSpace.s3),
                      AkButton.ghost('Se déconnecter', onPressed: () => ref.read(authRepositoryProvider).signOut()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Mon compte » : changement volontaire du mot de passe.
Future<void> showChangePasswordDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AkDialog(
    title: 'Changer mon mot de passe',
    size: AkDialogSize.s,
    content: ChangePasswordForm(
      onDone: () {
        Navigator.pop(ctx);
        showAkToast(context, 'Mot de passe modifié');
      },
      onCancel: () => Navigator.pop(ctx),
    ),
  ),
);
