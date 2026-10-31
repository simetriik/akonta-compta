import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/admin_providers.dart';
import '../../application/providers/repositories.dart';
import '../../domain/admin_models.dart';

/// Espace de l'associé : paramètres du cabinet, rôles et permissions, affectations, piste d'audit.
class CabinetScreen extends StatelessWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = akPageMargin(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, AkSpace.s4, pad, AkSpace.s2),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: AkPageHead(title: 'Cabinet', subtitle: 'Paramètres, rôles, affectations et piste d\'audit'),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Paramètres'),
                  Tab(text: 'Rôles'),
                  Tab(text: 'Affectations'),
                  Tab(text: 'Piste d\'audit'),
                ],
              ),
            ),
          ),
          const Expanded(child: TabBarView(children: [CabinetSettingsTab(), RolesTab(), AssignmentsTab(), AuditTab()])),
        ],
      ),
    );
  }
}

class CabinetSettingsTab extends ConsumerStatefulWidget {
  const CabinetSettingsTab({super.key});

  @override
  ConsumerState<CabinetSettingsTab> createState() => _CabinetSettingsTabState();
}

class _CabinetSettingsTabState extends ConsumerState<CabinetSettingsTab> {
  final _name = TextEditingController();
  final _length = TextEditingController();
  final _inactivity = TextEditingController();
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final cabinet = ref.watch(currentCabinetProvider);
    return AsyncView(
      value: cabinet,
      builder: (c) {
        if (c == null) return const AkEmptyState('Aucun cabinet.');
        if (!_loaded) {
          _name.text = c.name;
          _length.text = '${c.defaultAccountLength}';
          _inactivity.text = '${c.inactivityMinutes}';
          _loaded = true;
        }
        return AkPage(
          children: [
            AkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AkSectionTitle('Identité et sécurité'),
                  const SizedBox(height: AkSpace.s3),
                  AkTextField(controller: _name, label: 'Raison sociale'),
                  const SizedBox(height: AkSpace.s3),
                  Wrap(
                    spacing: AkSpace.s3,
                    runSpacing: AkSpace.s3,
                    children: [
                      SizedBox(
                        width: 320,
                        child: AkTextField(controller: _length, label: 'Longueur des comptes par défaut (6 à 12)', keyboardType: TextInputType.number),
                      ),
                      SizedBox(
                        width: 320,
                        child: AkTextField(controller: _inactivity, label: 'Déconnexion après inactivité (minutes)', keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AkButton.primary(
                      'Enregistrer',
                      onPressed: () async {
                        final len = int.tryParse(_length.text);
                        final min = int.tryParse(_inactivity.text);
                        if (len == null || len < 6 || len > 12 || min == null || min < 5 || min > 480) {
                          showAkToast(context, 'Longueur 6-12, inactivité 5-480 minutes.', kind: AkToastKind.warning);
                          return;
                        }
                        await ref.read(adminRepositoryProvider).updateCabinet(c.id, {
                          'name': _name.text.trim(),
                          'default_account_length': len,
                          'inactivity_minutes': min,
                        });
                        ref.invalidate(currentCabinetProvider);
                        if (context.mounted) showAkToast(context, 'Paramètres enregistrés.');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paquets de permissions par rôle : cases à cocher (associé).
class RolesTab extends ConsumerWidget {
  const RolesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final perms = ref.watch(permissionDefsProvider);
    return AsyncView(
      value: roles,
      builder: (roleList) => AsyncView(
        value: perms,
        builder: (permList) {
          final visibleRoles = roleList.where((r) => r.code != 'tech_admin').toList();
          return AkPage(
            children: [
              const AkSectionTitle('Rôles et permissions'),
              const SizedBox(height: AkSpace.s3),
              AkTable<PermissionDef>(
                minWidth: 280 + 120.0 * visibleRoles.length,
                rows: permList,
                columns: [
                  AkColumn<PermissionDef>.text(label: 'Permission', text: (p) => p.label, flex: 3),
                  for (final r in visibleRoles)
                    AkColumn<PermissionDef>(
                      label: r.name,
                      width: 120,
                      cell: (context, p) => AkCheckbox(
                        dense: true,
                        value: r.permissions.contains(p.code),
                        onChanged: (v) async {
                          await ref.read(adminRepositoryProvider).setRolePermission(r.id, p.code, v);
                          ref.invalidate(rolesProvider);
                          ref.invalidate(permissionsProvider);
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Affectations (utilisateur, dossier, rôle) et réaffectation en masse.
class AssignmentsTab extends ConsumerWidget {
  const AssignmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(assignmentsProvider);
    final t = context.ak;
    return AsyncView(
      value: data,
      onRetry: () => ref.invalidate(assignmentsProvider),
      builder: (list) {
        final byEntity = <String, List<Assignment>>{};
        for (final a in list) {
          byEntity.putIfAbsent(a.entityName ?? 'Portée cabinet', () => []).add(a);
        }
        return AkPage(
          children: [
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              alignment: WrapAlignment.end,
              children: [
                AkButton.secondary(
                  'Réaffecter en masse',
                  icon: Icons.swap_horiz,
                  dense: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const ReassignDialog()),
                ),
                AkButton.primary(
                  'Affecter',
                  icon: Icons.add,
                  dense: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const AssignmentDialog()),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            for (final e in byEntity.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AkSpace.s3),
                child: AkCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s1),
                          child: Text(e.key, style: AkText.heading.copyWith(color: t.text)),
                        ),
                        for (final a in e.value)
                          AkListRow(
                            title: Text(a.userName),
                            subtitle: Text(a.roleName),
                            trailing: AkIconButton(
                              tooltip: 'Retirer l\'affectation',
                              icon: Icons.delete_outline,
                              dense: true,
                              onPressed: () async {
                                await ref.read(adminRepositoryProvider).removeAssignment(a.id);
                                ref.invalidate(assignmentsProvider);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (list.isEmpty) const AkEmptyState('Aucune affectation.'),
          ],
        );
      },
    );
  }
}

class AssignmentDialog extends ConsumerStatefulWidget {
  const AssignmentDialog({super.key});

  @override
  ConsumerState<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends ConsumerState<AssignmentDialog> {
  String? _user;
  String? _role;
  String? _entity;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];
    final roles = ref.watch(rolesProvider).value ?? const <RoleDef>[];
    final entities = ref.watch(adminEntitiesProvider).value ?? const [];
    final cabinet = ref.watch(currentCabinetProvider).value;
    final roleDef = roles.where((r) => r.id == _role).firstOrNull;
    final cabinetScope = roleDef != null && (roleDef.code == 'partner' || roleDef.code == 'tech_admin');
    return AkDialog(
      title: 'Affecter un collaborateur',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDropdown<String>(
            value: _user,
            label: 'Collaborateur',
            items: [for (final p in profiles.where((p) => p.isActive)) AkOption(p.id, p.fullName.isEmpty ? p.email : p.fullName)],
            onChanged: (v) => setState(() => _user = v),
          ),
          const SizedBox(height: AkSpace.s3),
          AkDropdown<String>(value: _role, label: 'Rôle', items: [for (final r in roles) AkOption(r.id, r.name)], onChanged: (v) => setState(() => _role = v)),
          const SizedBox(height: AkSpace.s3),
          if (!cabinetScope)
            AkDropdown<String>(
              value: _entity,
              label: 'Dossier',
              items: [for (final e in entities) AkOption(e.id, e.name)],
              onChanged: (v) => setState(() => _entity = v),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Affecter',
          onPressed: () async {
            if (_user == null || _role == null || (!cabinetScope && _entity == null) || cabinet == null) {
              setState(() => _error = 'Renseignez le collaborateur, le rôle et le dossier.');
              return;
            }
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .addAssignment(cabinetId: cabinet.id, userId: _user!, roleId: _role!, entityId: cabinetScope ? null : _entity);
              ref.invalidate(assignmentsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
        ),
      ],
    );
  }
}

class ReassignDialog extends ConsumerStatefulWidget {
  const ReassignDialog({super.key});

  @override
  ConsumerState<ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends ConsumerState<ReassignDialog> {
  String? _from;
  String? _to;

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];
    final cabinet = ref.watch(currentCabinetProvider).value;
    return AkDialog(
      title: 'Réaffecter tous les dossiers',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDropdown<String>(
            value: _from,
            label: 'De',
            items: [for (final p in profiles) AkOption(p.id, p.fullName.isEmpty ? p.email : p.fullName)],
            onChanged: (v) => setState(() => _from = v),
          ),
          const SizedBox(height: AkSpace.s3),
          AkDropdown<String>(
            value: _to,
            label: 'Vers',
            items: [for (final p in profiles.where((p) => p.isActive)) AkOption(p.id, p.fullName.isEmpty ? p.email : p.fullName)],
            onChanged: (v) => setState(() => _to = v),
          ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Transférer',
          onPressed: _from == null || _to == null || _from == _to || cabinet == null
              ? null
              : () async {
                  final n = await ref.read(adminRepositoryProvider).reassignAll(cabinetId: cabinet.id, fromUserId: _from!, toUserId: _to!);
                  ref.invalidate(assignmentsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    showAkToast(context, '$n affectation(s) transférée(s).');
                  }
                },
        ),
      ],
    );
  }
}

/// Piste d'audit filtrable (associé) avec vérification de la chaîne SHA-256.
class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});

  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab> {
  String _action = '';
  late Future<List<AuditEvent>> _future = _load();

  Future<List<AuditEvent>> _load() => ref.read(adminRepositoryProvider).auditLog(action: _action.isEmpty ? null : _action);

  @override
  Widget build(BuildContext context) {
    final cabinet = ref.watch(currentCabinetProvider).value;
    final t = context.ak;
    final pad = akPageMargin(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, AkSpace.s3, pad, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 220,
                child: AkDropdown<String>(
                  value: _action,
                  label: 'Action',
                  items: const [
                    AkOption('', 'Toutes'),
                    AkOption('login', 'Connexions'),
                    AkOption('validate', 'Validations'),
                    AkOption('review', 'Revues'),
                    AkOption('export', 'Exports'),
                    AkOption('update', 'Modifications'),
                    AkOption('delete', 'Suppressions'),
                    AkOption('import_apply', 'Imports'),
                  ],
                  onChanged: (v) => setState(() {
                    _action = v ?? '';
                    _future = _load();
                  }),
                ),
              ),
              const Spacer(),
              AkButton.secondary(
                'Vérifier la chaîne',
                icon: Icons.verified_outlined,
                onPressed: cabinet == null
                    ? null
                    : () async {
                        final broken = await ref.read(adminRepositoryProvider).verifyChain(cabinet.id);
                        if (!context.mounted) return;
                        showAkToast(
                          context,
                          broken == null ? 'Chaîne SHA-256 intègre.' : 'Rupture détectée à l\'événement n° $broken !',
                          kind: broken == null ? AkToastKind.success : AkToastKind.danger,
                        );
                      },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AuditEvent>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const AkLoading();
              if (snap.hasError) return AkErrorMessage('Erreur : ${snap.error}', onRetry: () => setState(() => _future = _load()));
              final events = snap.data ?? const [];
              return AkPage(
                children: [
                  AkCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (var i = 0; i < events.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: t.border),
                            AkListRow(
                              leading: Text('${events[i].id}', style: AkText.code.copyWith(color: t.textMuted)),
                              title: Text(
                                '${events[i].action}${events[i].tableName != null ? ' · ${events[i].tableName}' : ''}',
                                style: AkText.bodyStrong.copyWith(color: t.text),
                              ),
                              subtitle: Text(
                                '${Fmt.date(events[i].occurredAt)} ${events[i].occurredAt.hour.toString().padLeft(2, '0')}:${events[i].occurredAt.minute.toString().padLeft(2, '0')} · ${events[i].actorName ?? 'système'} · ${events[i].hash.substring(0, 12)}…',
                                style: AkText.caption.copyWith(color: t.textMuted),
                              ),
                              onTap: () => showDialog(
                                context: context,
                                builder: (ctx) => AkDialog(
                                  title: 'Événement ${events[i].id}',
                                  content: SelectableText(events[i].payload.toString(), style: AkText.code),
                                  actions: [AkButton.primary('Fermer', onPressed: () => Navigator.pop(ctx))],
                                ),
                              ),
                            ),
                          ],
                          if (events.isEmpty) const AkEmptyState('Aucun événement.'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
