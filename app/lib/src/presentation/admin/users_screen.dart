import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/admin_models.dart';
import '../../domain/models.dart';
import '../inventory/inventory_widgets.dart' show showErrorSnack;
import '../widgets/async_view.dart';
import '../widgets/copy_text.dart';
import '../../application/providers/admin_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../../application/rules/member_rules.dart';

/// Collaborateurs : l'administrateur technique gère tous les comptes, l'associé son équipe (chefs de mission, assistants, stagiaires).
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final assignments = ref.watch(assignmentsProvider).value ?? const <Assignment>[];
    final rolesByUser = MemberRules.roleCodesByUser(assignments);
    final me = ref.watch(currentUserIdProvider);
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
              if (MemberRules.isAdmin(perms)) AkButton.secondary('Importer des collaborateurs (CSV)', icon: Icons.upload_file_outlined, dense: true, onPressed: () => _importCsv(context, ref)),
              AkButton.primary(
                'Ajouter un collaborateur',
                key: const Key('invite-user'),
                icon: Icons.person_add_alt,
                dense: true,
                onPressed: () async {
                  final created = await showDialog<InviteResult>(context: context, builder: (_) => const InviteUserDialog());
                  if (created == null || !context.mounted) return;
                  showDialog<void>(context: context, builder: (_) => TemporaryAccessDialog(title: 'Compte créé', accesses: created.invited));
                },
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
                    isSelf: list[i].id == me,
                    canManage: MemberRules.canManage(perms, rolesByUser[list[i].id] ?? const {}, isSelf: list[i].id == me),
                    canDesignate: MemberRules.canDesignatePartner(perms, rolesByUser[list[i].id] ?? const {}, isSelf: list[i].id == me),
                    canRevoke: MemberRules.canRevokePartner(perms, rolesByUser[list[i].id] ?? const {}, isSelf: list[i].id == me),
                    rolesLabel: MemberRules.rolesLabel(assignments, list[i].id),
                    onDesignate: () => _designate(context, ref, list[i], true),
                    onRevoke: () => _designate(context, ref, list[i], false),
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
                    onResetPassword: () => _resetPassword(context, ref, list[i]),
                    onResetMfa: () => _resetMfa(context, ref, list[i]),
                    onEdit: () => showDialog(
                      context: context,
                      builder: (_) => EditMemberDialog(profile: list[i]),
                    ),
                    onDelete: () => _delete(context, ref, list[i]),
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

  /// Désignation ou retrait du rôle d'associé (administrateur technique), avec confirmation : droits étendus à tous les dossiers.
  Future<void> _designate(BuildContext context, WidgetRef ref, Profile p, bool grant) async {
    final name = p.fullName.isEmpty ? p.email : p.fullName;
    final ok = await showAkConfirm(
      context,
      title: grant ? 'Désigner un associé' : 'Retirer le rôle d\'associé',
      message: grant
          ? 'Donner le rôle d\'associé à $name ? Il aura accès à tous les dossiers du cabinet, gérera l\'équipe et verra toute la comptabilité. L\'opération est inscrite dans la piste d\'audit.'
          : 'Retirer le rôle d\'associé à $name ? Il perdra l\'accès à l\'ensemble des dossiers. Le cabinet doit garder au moins un associé.',
      danger: !grant,
    );
    if (!ok || !context.mounted) return;
    try {
      final admin = ref.read(adminServiceProvider);
      if (grant) {
        await admin.designatePartner(p.id);
      } else {
        await admin.revokePartner(p.id);
      }
      ref.invalidate(assignmentsProvider);
      ref.invalidate(profilesProvider);
      ref.invalidate(cabinetHasPartnerProvider);
      if (context.mounted) showAkToast(context, grant ? '$name est maintenant associé' : 'Rôle d\'associé retiré à $name');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorText(e, action: grant ? 'Désignation impossible' : 'Retrait impossible'));
    }
  }

  /// Nouveau mot de passe provisoire (oubli) : affiché une seule fois à l'administrateur, à transmettre au membre.
  Future<void> _resetPassword(BuildContext context, WidgetRef ref, Profile p) async {
    final name = p.fullName.isEmpty ? p.email : p.fullName;
    final ok = await showAkConfirm(
      context,
      title: 'Nouveau mot de passe provisoire',
      message: 'Donner un nouveau mot de passe provisoire à $name ? L\'ancien ne fonctionnera plus ; $name devra en choisir un à sa prochaine connexion.',
    );
    if (!ok || !context.mounted) return;
    try {
      final access = await ref.read(adminServiceProvider).resetPassword(p.id);
      if (context.mounted) showDialog<void>(context: context, builder: (_) => TemporaryAccessDialog(title: 'Mot de passe provisoire', accesses: [access]));
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorText(e, action: 'Réinitialisation impossible'));
    }
  }

  /// Double vérification perdue (téléphone changé ou perdu) : on supprime ses facteurs, le membre en enrôle un nouveau.
  Future<void> _resetMfa(BuildContext context, WidgetRef ref, Profile p) async {
    final name = p.fullName.isEmpty ? p.email : p.fullName;
    final ok = await showAkConfirm(
      context,
      title: 'Réinitialiser la double vérification',
      message: 'Supprimer la double vérification de $name ? Son mot de passe ne change pas. À sa prochaine connexion, $name devra enregistrer de nouveau son application d\'authentification.',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final removed = await ref.read(adminServiceProvider).resetMfa(p.id);
      if (!context.mounted) return;
      showAkToast(context, removed == 0 ? '$name n\'avait aucune double vérification enregistrée' : 'Double vérification de $name réinitialisée');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorText(e, action: 'Réinitialisation impossible'));
    }
  }

  /// Suppression définitive, réservée aux membres sans trace : la base refuse sinon et on propose la désactivation.
  Future<void> _delete(BuildContext context, WidgetRef ref, Profile p) async {
    final name = p.fullName.isEmpty ? p.email : p.fullName;
    final ok = await showAkConfirm(
      context,
      title: 'Supprimer le membre',
      message:
          'Supprimer définitivement $name ? Possible seulement s\'il n\'a rien saisi ni validé ; sinon désactivez-le. La suppression est inscrite dans la piste d\'audit.',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(adminServiceProvider).deleteMember(p.id);
      ref.invalidate(profilesProvider);
      if (context.mounted) showAkToast(context, '$name supprimé');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorText(e, action: 'Suppression impossible'));
    }
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
      builder: (_) => TemporaryAccessDialog(
        title: 'Résultat de l\'import',
        accesses: result.invited,
        notes: [
          if (result.failed.isNotEmpty) 'Échecs :\n${result.failed.join('\n')}',
          if (result.parseErrors.isNotEmpty) 'Lignes ignorées :\n${result.parseErrors.join('\n')}',
        ],
      ),
    );
  }
}

/// Ligne d'un collaborateur : avatar, identité, statut (icône + mot) et interrupteur d'activation.
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.profile,
    required this.onToggle,
    required this.isSelf,
    required this.canManage,
    required this.canDesignate,
    required this.canRevoke,
    required this.rolesLabel,
    required this.onDesignate,
    required this.onRevoke,
    required this.onResetPassword,
    required this.onResetMfa,
    required this.onEdit,
    required this.onDelete,
  });

  final Profile profile;
  final ValueChanged<bool> onToggle;
  final bool isSelf;

  /// Peut-on modifier, désactiver, supprimer ce membre et lui donner un mot de passe provisoire ?
  final bool canManage;
  final bool canDesignate;
  final bool canRevoke;
  final String rolesLabel;
  final VoidCallback onDesignate;
  final VoidCallback onRevoke;
  final VoidCallback onResetPassword;
  final VoidCallback onResetMfa;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                if (rolesLabel.isNotEmpty) Text(rolesLabel, key: Key('member-roles-${p.id}'), style: AkText.caption.copyWith(color: t.text, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          if (p.isActive)
            AkBadge(label: 'Actif', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
          else
            AkBadge(label: 'Désactivé', color: t.textMuted, tint: t.surfaceSunken, icon: Icons.block),
          const SizedBox(width: AkSpace.s2),
          // Sur sa propre ligne : ni désactivation, ni suppression, ni mot de passe provisoire (« Changer mon mot de passe » existe).
          // Sur la ligne d'un associé ou de l'administrateur, l'associé n'a aucune action (règle de la base).
          if (canManage) AkSwitch(value: p.isActive, onChanged: onToggle),
          if (canManage) AkIconButton(key: Key('reset-password-${p.id}'), icon: Icons.key_outlined, tooltip: 'Nouveau mot de passe provisoire', onPressed: onResetPassword),
          if (canManage) AkIconButton(key: Key('reset-mfa-${p.id}'), icon: Icons.phonelink_lock_outlined, tooltip: 'Réinitialiser la double vérification', onPressed: onResetMfa),
          if (canManage || isSelf) AkIconButton(key: Key('edit-member-${p.id}'), icon: Icons.edit_outlined, tooltip: 'Modifier le membre', onPressed: onEdit),
          if (canDesignate) AkIconButton(key: Key('designate-partner-${p.id}'), icon: Icons.workspace_premium_outlined, tooltip: 'Désigner comme associé', onPressed: onDesignate),
          if (canRevoke) AkIconButton(key: Key('revoke-partner-${p.id}'), icon: Icons.remove_moderator_outlined, tooltip: 'Retirer le rôle d\'associé', onPressed: onRevoke),
          if (canManage) AkIconButton(key: Key('delete-member-${p.id}'), icon: Icons.delete_outline, tooltip: 'Supprimer le membre', color: t.danger, onPressed: onDelete),
        ],
      ),
    );
  }
}

/// Création d'un collaborateur : nom, e-mail, fonction ; l'associé choisit en plus son rôle et son dossier. Sans mot de passe
/// saisi : un mot de passe provisoire est généré (D-036).
class InviteUserDialog extends ConsumerStatefulWidget {
  const InviteUserDialog({super.key, this.presetEntityId});

  /// Dossier imposé (création depuis l'onglet « Équipe » du dossier).
  final String? presetEntityId;

  @override
  ConsumerState<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<InviteUserDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _job = TextEditingController();
  bool _busy = false;
  bool _firstPartner = false;
  String? _roleCode; // rôle d'équipe donné à la création (associé seulement)
  String? _entityId;
  String? _error;

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Adresse e-mail invalide';
    return null;
  }

  static String? validateName(String? v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_roleCode != null && (widget.presetEntityId ?? _entityId) == null) {
      setState(() => _error = 'Choisissez le dossier sur lequel cette personne travaille.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(adminServiceProvider)
          .invite(
            email: _email.text.trim(),
            fullName: _name.text.trim(),
            jobTitle: _job.text.trim().isEmpty ? null : _job.text.trim(),
            firstPartner: _firstPartner,
            role: _roleCode,
            entityId: _roleCode == null ? null : (widget.presetEntityId ?? _entityId),
          );
      ref.invalidate(profilesProvider);
      ref.invalidate(cabinetHasPartnerProvider);
      if (!mounted) return;
      if (r.failed.isNotEmpty) {
        setState(() => _error = r.failed.join('\n'));
        return;
      }
      Navigator.pop(context, r);
    } catch (e) {
      setState(() => _error = errorText(e, action: 'Invitation impossible'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    // L'associé donne un rôle d'équipe dès la création ; l'administrateur technique, non (c'est l'affaire de l'associé).
    final withTeamRole = perms.has('team.manage') && !perms.has('users.manage');
    final entities = ref.watch(adminEntitiesProvider).value ?? const <({String id, String name})>[];
    return AkDialog(
      title: 'Créer un collaborateur',
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
            AkTextField(controller: _job, label: 'Fonction (facultatif)', textInputAction: TextInputAction.done, onSubmitted: (_) => _busy ? null : _submit()),
            if (withTeamRole) ...[
              const SizedBox(height: AkSpace.s3),
              AkDropdown<String>(
                key: const Key('invite-role'),
                value: _roleCode ?? '',
                label: 'Rôle',
                items: const [
                  AkOption('', 'Aucun pour l\'instant'),
                  AkOption('manager', 'Chef de mission'),
                  AkOption('assistant', 'Assistant'),
                  AkOption('trainee', 'Stagiaire'),
                ],
                onChanged: (v) => setState(() => _roleCode = (v == null || v.isEmpty) ? null : v),
              ),
              if (_roleCode != null && widget.presetEntityId == null) ...[
                const SizedBox(height: AkSpace.s3),
                AkDropdown<String>(
                  key: const Key('invite-entity'),
                  value: _entityId,
                  label: 'Dossier',
                  items: [for (final e in entities) AkOption(e.id, e.name)],
                  onChanged: (v) => setState(() => _entityId = v),
                ),
              ],
            ],
            // Proposé seulement tant que le cabinet n'a aucun associé ; en cas d'erreur de lecture, la case reste cachée.
            if (ref.watch(cabinetHasPartnerProvider).value == false)
              Padding(
                padding: const EdgeInsets.only(top: AkSpace.s3),
                child: AkCheckbox(
                  key: const Key('invite-first-partner'),
                  value: _firstPartner,
                  label: 'Premier associé du cabinet (rôle Associé)',
                  onChanged: _busy ? null : (v) => setState(() => _firstPartner = v),
                ),
              ),
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
        AkButton.primary('Créer le compte', key: const Key('invite-submit'), loading: _busy, onPressed: _submit),
      ],
    );
  }
}

/// Accès provisoires à transmettre (adresse + mot de passe), montrés une seule fois : ils ne sont conservés nulle part.
class TemporaryAccessDialog extends StatelessWidget {
  const TemporaryAccessDialog({super.key, required this.title, required this.accesses, this.notes = const []});

  final String title;
  final List<TemporaryAccess> accesses;
  final List<String> notes;

  /// Message prêt à envoyer (WhatsApp, SMS, e-mail) pour un membre.
  static String message(TemporaryAccess a, {String? address}) =>
      'Bonjour, votre compte Akonta est prêt.\n${address == null ? '' : 'Adresse : $address\n'}Identifiant : ${a.email}\nMot de passe provisoire : ${a.password}\n'
      'Vous devrez choisir votre propre mot de passe à la première connexion.';

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkDialog(
      title: title,
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accesses.isNotEmpty)
              const AkBanner(
                kind: AkBannerKind.warning,
                child: Text('Notez ou copiez le mot de passe provisoire maintenant : il ne sera plus affiché. Le membre devra en choisir un autre à sa première connexion.'),
              ),
            for (final a in accesses) ...[
              const SizedBox(height: AkSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.email, style: AkText.bodyStrong.copyWith(color: t.text)),
                  SelectableText(a.password, key: Key('temporary-password-${a.email}'), style: AkText.code.copyWith(color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AkSpace.s2),
                  Wrap(
                    spacing: AkSpace.s2,
                    runSpacing: AkSpace.s2,
                    children: [
                      AkButton.secondary(
                        'Copier le message',
                        key: Key('copy-message-${a.email}'),
                        icon: Icons.copy_outlined,
                        dense: true,
                        onPressed: () => copyWithFeedback(context, message(a, address: kIsWeb ? Uri.base.origin : null), successMessage: 'Message copié'),
                      ),
                      AkButton.secondary(
                        'Copier le mot de passe',
                        key: Key('copy-password-${a.email}'),
                        icon: Icons.key_outlined,
                        dense: true,
                        onPressed: () => copyWithFeedback(context, a.password, successMessage: 'Mot de passe copié'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            for (final n in notes) ...[const SizedBox(height: AkSpace.s3), Text(n, style: AkText.body.copyWith(color: t.text))],
          ],
        ),
      ),
      actions: [AkButton.primary('J\'ai noté, fermer', key: const Key('access-close'), onPressed: () => Navigator.pop(context))],
    );
  }
}

/// Modification d'un membre par l'administrateur : nom et fonction. L'adresse e-mail est l'identifiant de connexion : elle ne change pas ici.
class EditMemberDialog extends ConsumerStatefulWidget {
  const EditMemberDialog({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<EditMemberDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _job = TextEditingController(text: widget.profile.jobTitle ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminServiceProvider)
          .updateProfile(widget.profile.id, fullName: _name.text.trim(), jobTitle: _job.text.trim().isEmpty ? null : _job.text.trim());
      ref.invalidate(profilesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showAkToast(context, 'Membre modifié');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, action: 'Modification impossible'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Modifier le membre',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(controller: _name, key: const Key('edit-name'), label: 'Nom complet', validator: _InviteUserDialogState.validateName, autofocus: true),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _job, key: const Key('edit-job'), label: 'Fonction (facultatif)', textInputAction: TextInputAction.done, onSubmitted: (_) => _busy ? null : _submit()),
            const SizedBox(height: AkSpace.s3),
            Text(
              'Adresse e-mail : ${widget.profile.email} (identifiant de connexion, non modifiable ici)',
              style: AkText.caption.copyWith(color: context.ak.textMuted),
            ),
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
        AkButton.primary('Enregistrer', key: const Key('edit-submit'), loading: _busy, onPressed: _submit),
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
