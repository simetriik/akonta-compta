import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/admin_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/team_rules.dart';
import '../../core/errors/errors.dart';
import '../../domain/admin_models.dart';
import '../../domain/models.dart';
import '../inventory/inventory_widgets.dart' show showErrorSnack;
import '../admin/users_screen.dart' show InviteUserDialog, TemporaryAccessDialog;
import '../widgets/async_view.dart';

/// Équipe d'un dossier : chef de mission, assistants, stagiaires. L'associé gère tout ; le chef de mission affecte assistants
/// et stagiaires de son dossier ; les autres consultent (D-038). Réutilisé par la fiche du dossier et l'assistant d'ouverture.
class TeamTab extends ConsumerWidget {
  const TeamTab({super.key, required this.entityId, this.embedded = false});

  final String entityId;

  /// Dans l'assistant d'ouverture : pas de titre, le contexte est donné par l'étape.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canManage = TeamRules.canManage(perms, entityId);
    final team = ref.watch(teamProvider(entityId));
    return AsyncView(
      value: team,
      onRetry: () => ref.invalidate(teamProvider(entityId)),
      builder: (members) {
        final manager = TeamRules.manager(members);
        // Équipe vide : le bouton est dans l'état vide (un seul « Affecter » à l'écran).
        final addButton = canManage && members.isNotEmpty
            ? AkButton.primary(
                'Affecter un collaborateur',
                key: const Key('team-add'),
                icon: Icons.person_add_alt,
                dense: true,
                onPressed: () => showDialog<void>(context: context, builder: (_) => TeamAssignDialog(entityId: entityId)),
              )
            : null;
        final body = <Widget>[
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s3),
              child: Row(
                children: [
                  Expanded(child: Text('Équipe du dossier', style: AkText.heading.copyWith(color: t.text))),
                  ?addButton,
                ],
              ),
            )
          else if (addButton != null)
            Padding(padding: const EdgeInsets.only(bottom: AkSpace.s3), child: Align(alignment: Alignment.centerLeft, child: addButton)),
          if (manager == null && members.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: AkSpace.s3),
              child: AkBanner(kind: AkBannerKind.warning, child: Text('Ce dossier n\'a pas de chef de mission.')),
            ),
          if (members.isEmpty)
            AkEmptyState(
              'Personne n\'est encore affecté à ce dossier.',
              icon: Icons.groups_outlined,
              action: canManage ? AkButton.primary('Affecter un collaborateur', icon: Icons.person_add_alt, onPressed: () => showDialog<void>(context: context, builder: (_) => TeamAssignDialog(entityId: entityId))) : null,
            )
          else
            AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < members.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: t.border),
                      _MemberRow(member: members[i], entityId: entityId, perms: perms),
                    ],
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AkSpace.s3),
            child: Text('Les associés ont accès à tous les dossiers du cabinet.', style: AkText.caption.copyWith(color: t.textMuted)),
          ),
        ];
        return embedded ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body) : ListView(padding: EdgeInsets.all(akPageMargin(context)), children: body);
      },
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member, required this.entityId, required this.perms});

  final Assignment member;
  final String entityId;
  final PermissionSet perms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManager = member.roleCode == 'manager';
    // L'associé remplace le chef de mission ; le chef de mission retire assistants et stagiaires ; chacun selon son droit.
    final canReplace = isManager && TeamRules.canSetManager(perms);
    final canRemove = !isManager && TeamRules.canManage(perms, entityId) || (isManager && TeamRules.canSetManager(perms));
    return AkListRow(
      title: Text(member.userName),
      subtitle: Text(member.roleName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canReplace)
            AkButton.ghost(
              'Remplacer',
              dense: true,
              key: const Key('team-replace-manager'),
              onPressed: () => showDialog<void>(context: context, builder: (_) => TeamAssignDialog(entityId: entityId, forceRole: 'manager')),
            ),
          if (canRemove)
            AkIconButton(
              key: Key('team-remove-${member.id}'),
              tooltip: 'Retirer du dossier',
              icon: Icons.person_remove_outlined,
              dense: true,
              onPressed: () async {
                final ok = await showAkConfirm(
                  context,
                  title: 'Retirer du dossier',
                  message: 'Retirer ${member.userName} (${member.roleName}) de ce dossier ? Son travail déjà saisi est conservé.',
                  danger: true,
                );
                if (!ok || !context.mounted) return;
                try {
                  await ref.read(adminServiceProvider).removeAssignment(member.id);
                  ref.invalidate(teamProvider(entityId));
                  ref.invalidate(assignmentsProvider);
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, errorText(e, action: 'Retrait impossible'));
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Affecte un collaborateur à ce dossier avec un rôle. Le chef de mission remplace l'actuel (associé seulement).
class TeamAssignDialog extends ConsumerStatefulWidget {
  const TeamAssignDialog({super.key, required this.entityId, this.forceRole});

  final String entityId;

  /// Code de rôle imposé (ex. `manager` pour « Remplacer »).
  final String? forceRole;

  @override
  ConsumerState<TeamAssignDialog> createState() => _TeamAssignDialogState();
}

class _TeamAssignDialogState extends ConsumerState<TeamAssignDialog> {
  String? _user;
  String? _roleId;
  String? _error;
  bool _busy = false;

  /// Crée le compte (rôle et dossier imposés par l'onglet), puis montre le mot de passe provisoire.
  Future<void> _createMember() async {
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    final created = await showDialog<InviteResult>(context: context, builder: (_) => InviteUserDialog(presetEntityId: widget.entityId));
    if (created == null || !mounted) return;
    ref.invalidate(teamProvider(widget.entityId));
    ref.invalidate(teamCandidatesProvider);
    ref.invalidate(assignmentsProvider);
    navigator.pop();
    if (rootContext.mounted) showDialog<void>(context: rootContext, builder: (_) => TemporaryAccessDialog(title: 'Compte créé', accesses: created.invited));
  }

  Future<void> _submit(List<RoleDef> roles, Assignment? manager) async {
    final role = roles.where((r) => r.id == _roleId).firstOrNull;
    if (_user == null || role == null) {
      setState(() => _error = 'Choisissez le collaborateur et son rôle.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final admin = ref.read(adminServiceProvider);
      if (role.code == 'manager' && manager != null) {
        await admin.replaceManager(entityId: widget.entityId, userId: _user!);
      } else {
        final cabinet = await ref.read(currentCabinetProvider.future);
        await admin.addAssignment(cabinetId: cabinet!.id, userId: _user!, roleId: role.id, entityId: widget.entityId);
      }
      ref.invalidate(teamProvider(widget.entityId));
      ref.invalidate(teamCandidatesProvider);
      ref.invalidate(assignmentsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, action: 'Affectation impossible'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final allRoles = ref.watch(rolesProvider).value ?? const <RoleDef>[];
    final team = ref.watch(teamProvider(widget.entityId)).value ?? const <Assignment>[];
    var roles = TeamRules.assignableRoles(perms, widget.entityId, allRoles);
    if (widget.forceRole != null) roles = roles.where((r) => r.code == widget.forceRole).toList();
    if (_roleId == null && roles.length == 1) _roleId = roles.first.id;
    final selected = roles.where((r) => r.id == _roleId).firstOrNull;
    final manager = TeamRules.manager(team);
    // Candidats fournis par la base : ni associés, ni personnes déjà dans l'équipe (pour le rôle visé).
    final candidates = ref.watch(teamCandidatesProvider((entityId: widget.entityId, role: selected?.code))).value ?? const <TeamCandidate>[];
    return AkDialog(
      title: widget.forceRole == 'manager' ? 'Remplacer le chef de mission' : 'Affecter un collaborateur',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDropdown<String>(
            key: const Key('team-user'),
            value: _user,
            label: 'Collaborateur',
            items: [for (final p in candidates) AkOption(p.id, p.label)],
            onChanged: (v) => setState(() => _user = v),
          ),
          const SizedBox(height: AkSpace.s3),
          AkDropdown<String>(
            key: const Key('team-role'),
            value: _roleId,
            label: 'Rôle',
            items: [for (final r in roles) AkOption(r.id, r.name)],
            onChanged: (v) => setState(() => _roleId = v),
          ),
          if (perms.has('team.manage'))
            Align(
              alignment: Alignment.centerLeft,
              child: AkButton.ghost(
                'La personne n\'a pas encore de compte ? La créer',
                key: const Key('team-create-member'),
                dense: true,
                icon: Icons.person_add_alt_1_outlined,
                onPressed: _busy ? null : _createMember,
              ),
            ),
          if (selected?.code == 'manager' && manager != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: AkBanner(kind: AkBannerKind.info, child: Text('${manager.userName} ne sera plus chef de mission de ce dossier.')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: _busy ? null : () => Navigator.pop(context)),
        AkButton.primary('Affecter', key: const Key('team-submit'), loading: _busy, onPressed: () => _submit(roles, manager)),
      ],
    );
  }
}
