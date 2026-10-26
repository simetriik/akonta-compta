import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:akonta/design/design.dart';

import '../../data/auth_repository.dart';

/// Saisie du code TOTP à la connexion (facteur déjà enrôlé).
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final factorId = await repo.firstVerifiedTotpFactorId();
      if (factorId == null) throw const AuthException('Aucun facteur TOTP enrôlé');
      await repo.verifyTotp(factorId: factorId, code: _code.text);
      ref.invalidate(mfaStatusProvider);
      widget.onVerified();
    } on AuthException catch (e) {
      setState(() => _error = e.message.toLowerCase().contains('invalid') ? 'Code incorrect ou expiré.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MfaScaffold(
      title: 'Vérification en deux étapes',
      children: [
        const Text('Saisissez le code à 6 chiffres de votre application d\'authentification.'),
        const SizedBox(height: 16),
        CodeField(controller: _code, onSubmitted: _verify),
        if (_error != null) ...[const SizedBox(height: 8), AkBanner(kind: AkBannerKind.danger, child: Text(_error!))],
        const SizedBox(height: 16),
        AkButton.primary('Vérifier', expand: true, loading: _busy, onPressed: _verify),
        const SizedBox(height: AkSpace.s2),
        AkButton.ghost('Se déconnecter', onPressed: () => ref.read(authRepositoryProvider).signOut()),
      ],
    );
  }
}

/// Enrôlement TOTP obligatoire pour l'associé et l'administrateur, proposé aux autres.
class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key, required this.mandatory, required this.onDone});

  final bool mandatory;
  final VoidCallback onDone;

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _code = TextEditingController();
  AuthMFAEnrollResponse? _enrollment;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final r = await ref.read(authRepositoryProvider).enrollTotp();
      if (mounted) setState(() => _enrollment = r);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _confirm() async {
    final e = _enrollment;
    if (e == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyTotp(factorId: e.id, code: _code.text);
      ref.invalidate(mfaStatusProvider);
      widget.onDone();
    } on AuthException catch (ex) {
      setState(() => _error = ex.message.toLowerCase().contains('invalid') ? 'Code incorrect : vérifiez l\'heure de votre téléphone.' : ex.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _enrollment;
    final totp = e?.totp;
    return MfaScaffold(
      title: 'Activer la vérification en deux étapes',
      children: [
        Text(
          widget.mandatory
              ? 'Votre rôle exige une application d\'authentification (TOTP) : Google Authenticator, Aegis, Microsoft Authenticator…'
              : 'Protégez votre compte avec une application d\'authentification (recommandé).',
        ),
        const SizedBox(height: 16),
        if (e == null && _error == null) const AkLoading(),
        if (e != null && totp != null) ...[
          Center(
            child: QrImageView(data: totp.uri, size: 180, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 8),
          SelectableText('Clé manuelle : ${totp.secret}', style: AkText.code.copyWith(color: context.ak.text)),
          const SizedBox(height: 16),
          CodeField(controller: _code, onSubmitted: _confirm),
        ],
        if (_error != null) ...[const SizedBox(height: 8), AkBanner(kind: AkBannerKind.danger, child: Text(_error!))],
        const SizedBox(height: 16),
        AkButton.primary('Confirmer', expand: true, loading: _busy, onPressed: e == null ? null : _confirm),
        const SizedBox(height: AkSpace.s2),
        if (!widget.mandatory) AkButton.ghost('Plus tard', onPressed: widget.onDone),
        if (widget.mandatory) AkButton.ghost('Se déconnecter', onPressed: () => ref.read(authRepositoryProvider).signOut()),
      ],
    );
  }
}

class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AkTextField(
      key: const Key('mfa-code'),
      controller: controller,
      label: 'Code à 6 chiffres',
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      mono: true,
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

class MfaScaffold extends StatelessWidget {
  const MfaScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
                const Center(child: AkLogo(height: 56)),
                const SizedBox(height: AkSpace.s6),
                AkCard(
                  padding: const EdgeInsets.all(AkSpace.s8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: AkText.titleLg.copyWith(color: t.text)),
                      const SizedBox(height: AkSpace.s4),
                      ...children,
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
