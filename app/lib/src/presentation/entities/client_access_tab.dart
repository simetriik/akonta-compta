import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../domain/admin_models.dart';
import '../../domain/models.dart';
import '../admin/users_screen.dart';
import '../widgets/async_view.dart';
import '../widgets/error_display.dart';

/// État de l'accès des clients à un dossier.
final clientAccessProvider = FutureProvider.autoDispose.family<String, String>((ref, entityId) => ref.watch(clientAccessServiceProvider).access(entityId));

/// Comptes clients d'un dossier : affectations dont le rôle est un rôle client.
final clientMembersProvider = FutureProvider.autoDispose.family<List<Assignment>, String>((ref, entityId) async {
  final all = await ref.watch(adminServiceProvider).assignments();
  return all.where((a) => a.entityId == entityId && a.roleCode.startsWith('client_')).toList();
});

const _statusLabels = {'disabled': 'Fermé', 'active': 'Ouvert', 'suspended': 'Suspendu (lecture seule)'};

/// Onglet « Clients » du dossier : ouvrir, suspendre ou fermer l'accès, et gérer les comptes des clients (D-044).
class ClientAccessTab extends ConsumerWidget {
  const ClientAccessTab({super.key, required this.entityId});

  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canSwitch = perms.has('client_access.manage', entityId: entityId);
    final canInvite = perms.has('assignments.manage');
    final status = ref.watch(clientAccessProvider(entityId));
    final members = ref.watch(clientMembersProvider(entityId));
    return ListView(
      padding: EdgeInsets.all(akPageMargin(context)),
      children: [
        AsyncView(
          value: status,
          onRetry: () => ref.invalidate(clientAccessProvider(entityId)),
          builder: (s) => _StatusCard(entityId: entityId, status: s, canSwitch: canSwitch),
        ),
        const SizedBox(height: AkSpace.s6),
        AkPageHead(
          title: 'Comptes des clients',
          actions: [
            if (canInvite)
              AkButton.primary('Inviter un client', key: const Key('invite-client'), icon: Icons.person_add_alt_outlined, onPressed: () => _invite(context, ref)),
          ],
        ),
        const SizedBox(height: AkSpace.s3),
        AsyncView(
          value: members,
          onRetry: () => ref.invalidate(clientMembersProvider(entityId)),
          builder: (list) => list.isEmpty
              ? const AkBanner(kind: AkBannerKind.info, child: Text('Aucun compte client sur ce dossier.'))
              : Column(children: [for (final a in list) _MemberRow(assignment: a, entityId: entityId, canManage: canInvite)]),
        ),
      ],
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<InviteResult>(context: context, builder: (_) => _InviteClientDialog(entityId: entityId));
    if (result == null || !context.mounted) return;
    ref.invalidate(clientMembersProvider(entityId));
    showDialog<void>(context: context, builder: (_) => TemporaryAccessDialog(title: 'Compte client créé', accesses: result.invited));
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.entityId, required this.status, required this.canSwitch});

  final String entityId;
  final String status;
  final bool canSwitch;

  Future<void> _change(BuildContext context, WidgetRef ref, String next, String title, String message) async {
    if (!await showAkConfirm(context, title: title, message: message, confirmLabel: 'Confirmer', danger: next != 'active')) return;
    try {
      await ref.read(clientAccessServiceProvider).setAccess(entityId, next);
      ref.invalidate(clientAccessProvider(entityId));
      ref.invalidate(entityDashboardProvider);
    } catch (e) {
      if (context.mounted) showError(context, e, action: 'Le changement d\'accès');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    return AkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AkSectionTitle('Accès des clients à ce dossier'),
          const SizedBox(height: AkSpace.s2),
          Text(_statusLabels[status] ?? status, key: const Key('client-access-status'), style: AkText.heading.copyWith(color: t.textStrong)),
          const SizedBox(height: AkSpace.s1),
          Text(
            'Un client voit uniquement son brouillard et ses factures. Il ne valide jamais : la validation reste au cabinet.',
            style: AkText.caption.copyWith(color: t.textMuted),
          ),
          if (canSwitch) ...[
            const SizedBox(height: AkSpace.s3),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                if (status != 'active')
                  AkButton.primary(
                    status == 'suspended' ? 'Réactiver l\'accès' : 'Ouvrir l\'accès',
                    key: const Key('client-access-open'),
                    onPressed: () => _change(context, ref, 'active', 'Ouvrir l\'accès ?', 'Les clients de ce dossier pourront saisir leur brouillard et émettre leurs factures.'),
                  ),
                if (status == 'active')
                  AkButton.secondary(
                    'Suspendre',
                    key: const Key('client-access-suspend'),
                    onPressed: () => _change(context, ref, 'suspended', 'Suspendre l\'accès ?', 'Les clients gardent la lecture mais ne peuvent plus saisir ni émettre. Une facture déjà soumise reste finalisable.'),
                  ),
                if (status != 'disabled')
                  AkButton.dangerOutline(
                    'Fermer l\'accès',
                    key: const Key('client-access-close'),
                    onPressed: () => _change(context, ref, 'disabled', 'Fermer l\'accès ?', 'Les clients ne verront plus rien de ce dossier.'),
                  ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: Text('Seul un associé ouvre ou suspend l\'accès.', style: AkText.caption.copyWith(color: t.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.assignment, required this.entityId, required this.canManage});

  final Assignment assignment;
  final String entityId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AkListRow(
      title: Text(assignment.userName),
      subtitle: Text(assignment.roleName),
      trailing: canManage
          ? AkButton.ghost(
              'Retirer',
              onPressed: () async {
                if (!await showAkConfirm(context, title: 'Retirer ce client ?', message: 'Son accès à ce dossier est supprimé. Le compte reste, désactivez-le dans « Collaborateurs » si besoin.', danger: true)) return;
                try {
                  await ref.read(adminServiceProvider).removeAssignment(assignment.id);
                  ref.invalidate(clientMembersProvider(entityId));
                } catch (e) {
                  if (context.mounted) showError(context, e, action: 'Le retrait');
                }
              },
            )
          : null,
    );
  }
}

String? _validateName(String? v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null;

String? _validateEmail(String? v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Adresse e-mail invalide';

class _InviteClientDialog extends ConsumerStatefulWidget {
  const _InviteClientDialog({required this.entityId});

  final String entityId;

  @override
  ConsumerState<_InviteClientDialog> createState() => _InviteClientDialogState();
}

class _InviteClientDialogState extends ConsumerState<_InviteClientDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _role = 'client_saisie';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminServiceProvider).invite(email: _email.text.trim(), fullName: _name.text.trim(), role: _role, entityId: widget.entityId);
      if (!mounted) return;
      if (result.invited.isEmpty) {
        setState(() => _error = result.failed.isNotEmpty ? result.failed.join(' ; ') : 'Le compte n\'a pas été créé.');
      } else {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) showError(context, e, action: 'L\'invitation');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Inviter un client',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(controller: _name, key: const Key('client-name'), label: 'Nom complet', validator: _validateName, autofocus: true),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _email, key: const Key('client-email'), label: 'Adresse e-mail', validator: _validateEmail, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              key: const Key('client-role'),
              value: _role,
              label: 'Rôle',
              items: const [AkOption('client_saisie', 'Saisie (ses propres brouillards)'), AkOption('client_gerant', 'Gérant (tout le brouillard du dossier, émet des factures)')],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: AkSpace.s3), child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!))),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: _busy ? null : () => Navigator.pop(context)),
        AkButton.primary('Créer le compte', key: const Key('client-submit'), loading: _busy, onPressed: _submit),
      ],
    );
  }
}
