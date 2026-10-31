import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/admin_providers.dart';
import '../../application/providers/services.dart';

/// Utilisateurs et sécurité (administrateur technique) : invitation, import CSV eABC, désactivation (§10.1).
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final t = context.ak;
    return AsyncView(
      value: profiles,
      onRetry: () => ref.invalidate(profilesProvider),
      builder: (list) => AkPage(
        children: [
          AkPageHead(
            title: 'Collaborateurs',
            subtitle: '${list.where((p) => p.isActive).length} actif${list.where((p) => p.isActive).length > 1 ? 's' : ''} sur ${list.length}',
            actions: [
              AkButton.secondary('Importer un CSV eABC', icon: Icons.upload_file_outlined, dense: true, onPressed: () => _importCsv(context, ref)),
              AkButton.primary(
                'Inviter',
                key: const Key('invite-user'),
                icon: Icons.person_add_alt,
                dense: true,
                onPressed: () => showDialog(context: context, builder: (_) => const InviteUserDialog()),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  _UserRow(
                    profile: list[i],
                    onToggle: (v) async {
                      final p = list[i];
                      final ok =
                          v ||
                          await showAkConfirm(
                            context,
                            title: 'Désactiver le collaborateur',
                            message:
                                'Désactiver ${p.fullName.isEmpty ? p.email : p.fullName} ? Le compte est conservé (aucune suppression), la connexion devient impossible.',
                            danger: true,
                          );
                      if (!ok) return;
                      await ref.read(adminServiceProvider).setActive(p.id, v);
                      ref.invalidate(profilesProvider);
                    },
                  ),
                ],
                if (list.isEmpty) const AkEmptyState('Aucun collaborateur.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (picked.isEmpty || !context.mounted) return;
    final bytes = await picked.first.readAsBytes();
    if (!context.mounted) return;
    final csv = utf8.decode(bytes, allowMalformed: true);
    final result = await ref.read(adminServiceProvider).invite(csv: csv);
    ref.invalidate(profilesProvider);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AkDialog(
        title: 'Résultat de l\'import',
        content: Text(
          [
            '${result.invited.length} invitation(s) envoyée(s).',
            if (result.failed.isNotEmpty) '\nÉchecs :\n${result.failed.join('\n')}',
            if (result.parseErrors.isNotEmpty) '\nLignes ignorées :\n${result.parseErrors.join('\n')}',
          ].join('\n'),
        ),
        actions: [AkButton.primary('Fermer', onPressed: () => Navigator.pop(ctx))],
      ),
    );
  }
}

/// Ligne d'un collaborateur : avatar, identité, statut (icône + mot) et interrupteur d'activation.
class _UserRow extends StatelessWidget {
  const _UserRow({required this.profile, required this.onToggle});

  final Profile profile;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final p = profile;
    final name = p.fullName.isEmpty ? p.email : p.fullName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
      child: Row(
        children: [
          AkAvatar(name),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AkText.bodyStrong.copyWith(color: p.isActive ? t.text : t.textMuted, decoration: p.isActive ? null : TextDecoration.lineThrough),
                ),
                Text([p.email, if (p.jobTitle != null) p.jobTitle!].join(' · '), style: AkText.caption.copyWith(color: t.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          if (p.isActive)
            AkBadge(label: 'Actif', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
          else
            AkBadge(label: 'Désactivé', color: t.textMuted, tint: t.surfaceSunken, icon: Icons.block),
          const SizedBox(width: AkSpace.s2),
          AkSwitch(value: p.isActive, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// Invitation d'un collaborateur : e-mail, nom, fonction. Sans mot de passe : l'invité le choisit via le lien reçu.
class InviteUserDialog extends ConsumerStatefulWidget {
  const InviteUserDialog({super.key});

  @override
  ConsumerState<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<InviteUserDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _job = TextEditingController();
  bool _busy = false;
  String? _error;

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Adresse e-mail invalide';
    return null;
  }

  static String? validateName(String? v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(adminServiceProvider)
          .invite(email: _email.text.trim(), fullName: _name.text.trim(), jobTitle: _job.text.trim().isEmpty ? null : _job.text.trim());
      ref.invalidate(profilesProvider);
      if (!mounted) return;
      if (r.failed.isNotEmpty) {
        setState(() => _error = r.failed.join('\n'));
        return;
      }
      Navigator.pop(context);
      showAkToast(context, 'Invitation envoyée à ${_email.text.trim()}');
    } catch (e) {
      setState(() => _error = errorText(e, action: 'Invitation impossible'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Inviter un collaborateur',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(controller: _name, key: const Key('invite-name'), label: 'Nom complet', validator: validateName, autofocus: true),
            const SizedBox(height: AkSpace.s3),
            AkTextField(
              controller: _email,
              key: const Key('invite-email'),
              label: 'Adresse e-mail',
              validator: validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _job, label: 'Fonction (facultatif)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
              ),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: _busy ? null : () => Navigator.pop(context)),
        AkButton.primary('Envoyer l\'invitation', key: const Key('invite-submit'), loading: _busy, onPressed: _submit),
      ],
    );
  }
}

/// Petit profil éditable par chacun (nom), utilisé plus tard dans un écran « Mon compte ».
class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => AkListRow(title: Text(profile.fullName), subtitle: Text(profile.email));
}
