import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/admin_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';

/// Espace de l'associé : paramètres du cabinet, rôles et permissions, affectations, piste d'audit.
class CabinetScreen extends StatelessWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(padding: EdgeInsets.fromLTRB(pad, pad, pad, AkSpace.s2), child: const Align(alignment: Alignment.centerLeft, child: AkPageHead(title: 'Cabinet', subtitle: 'Paramètres, rôles, affectations et piste d\'audit'))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: const Align(alignment: Alignment.centerLeft, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Paramètres'), Tab(text: 'Rôles'), Tab(text: 'Affectations'), Tab(text: 'Piste d\'audit')])),
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
        if (c == null) return const Center(child: Text('Aucun cabinet.'));
        if (!_loaded) {
          _name.text = c.name;
          _length.text = '${c.defaultAccountLength}';
          _inactivity.text = '${c.inactivityMinutes}';
          _loaded = true;
        }
        return ListView(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0),
          children: [
            AkCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Identité et sécurité', style: AkText.heading.copyWith(color: context.ak.text)),
                    const SizedBox(height: 12),
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Raison sociale')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _length, decoration: const InputDecoration(labelText: 'Longueur des comptes par défaut (6 à 12)'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _inactivity, decoration: const InputDecoration(labelText: 'Déconnexion après inactivité (minutes)'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final len = int.tryParse(_length.text);
                        final min = int.tryParse(_inactivity.text);
                        if (len == null || len < 6 || len > 12 || min == null || min < 5 || min > 480) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Longueur 6-12, inactivité 5-480 minutes.')));
                          return;
                        }
                        await ref.read(adminRepositoryProvider).updateCabinet(c.id, {'name': _name.text.trim(), 'default_account_length': len, 'inactivity_minutes': min});
                        ref.invalidate(currentCabinetProvider);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paramètres enregistrés.')));
                      },
                      child: const Text('Enregistrer'),
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
          final t = context.ak;
          return SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0),
            child: AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
                  child: Text('Rôles et permissions', style: AkText.heading.copyWith(color: t.text)),
                ),
                Divider(height: 1, color: t.border),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [const DataColumn(label: Text('Permission')), for (final r in visibleRoles) DataColumn(label: Text(r.name))],
                    rows: [
                      for (final p in permList)
                        DataRow(cells: [
                          DataCell(Text(p.label)),
                          for (final r in visibleRoles)
                            DataCell(Checkbox(
                              value: r.permissions.contains(p.code),
                              onChanged: (v) async {
                                await ref.read(adminRepositoryProvider).setRolePermission(r.id, p.code, v ?? false);
                                ref.invalidate(rolesProvider);
                                ref.invalidate(permissionsProvider);
                              },
                            )),
                        ]),
                    ],
                  ),
                ),
              ]),
            ),
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
        return ListView(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0),
          children: [
            Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, alignment: WrapAlignment.end, children: [
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const ReassignDialog()),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Réaffecter en masse'),
              ),
              FilledButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const AssignmentDialog()),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Affecter'),
              ),
            ]),
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
                      Padding(padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s1), child: Text(e.key, style: AkText.heading.copyWith(color: t.text))),
                      for (final a in e.value)
                        ListTile(
                          dense: true,
                          title: Text(a.userName, style: AkText.body.copyWith(color: t.text)),
                          subtitle: Text(a.roleName, style: AkText.caption.copyWith(color: t.textMuted)),
                          trailing: IconButton(
                            tooltip: 'Retirer l\'affectation',
                            icon: const Icon(Icons.delete_outline),
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
            if (list.isEmpty) const Text('Aucune affectation.'),
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
    return AlertDialog(
      title: const Text('Affecter un collaborateur'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _user,
              decoration: const InputDecoration(labelText: 'Collaborateur'),
              items: [for (final p in profiles.where((p) => p.isActive)) DropdownMenuItem(value: p.id, child: Text(p.fullName.isEmpty ? p.email : p.fullName))],
              onChanged: (v) => setState(() => _user = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: [for (final r in roles) DropdownMenuItem(value: r.id, child: Text(r.name))],
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 10),
            if (!cabinetScope)
              DropdownButtonFormField<String>(
                initialValue: _entity,
                decoration: const InputDecoration(labelText: 'Dossier'),
                items: [for (final e in entities) DropdownMenuItem(value: e.id, child: Text(e.name))],
                onChanged: (v) => setState(() => _entity = v),
              ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: AkText.body.copyWith(color: context.ak.danger))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            if (_user == null || _role == null || (!cabinetScope && _entity == null) || cabinet == null) {
              setState(() => _error = 'Renseignez le collaborateur, le rôle et le dossier.');
              return;
            }
            try {
              await ref.read(adminRepositoryProvider).addAssignment(cabinetId: cabinet.id, userId: _user!, roleId: _role!, entityId: cabinetScope ? null : _entity);
              ref.invalidate(assignmentsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = '$e');
            }
          },
          child: const Text('Affecter'),
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
    return AlertDialog(
      title: const Text('Réaffecter tous les dossiers'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _from,
              decoration: const InputDecoration(labelText: 'De'),
              items: [for (final p in profiles) DropdownMenuItem(value: p.id, child: Text(p.fullName.isEmpty ? p.email : p.fullName))],
              onChanged: (v) => setState(() => _from = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Vers'),
              items: [for (final p in profiles.where((p) => p.isActive)) DropdownMenuItem(value: p.id, child: Text(p.fullName.isEmpty ? p.email : p.fullName))],
              onChanged: (v) => setState(() => _to = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _from == null || _to == null || _from == _to || cabinet == null
              ? null
              : () async {
                  final n = await ref.read(adminRepositoryProvider).reassignAll(cabinetId: cabinet.id, fromUserId: _from!, toUserId: _to!);
                  ref.invalidate(assignmentsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n affectation(s) transférée(s).')));
                  }
                },
          child: const Text('Transférer'),
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
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, AkSpace.s3, pad, 0),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Toutes')),
                    DropdownMenuItem(value: 'login', child: Text('Connexions')),
                    DropdownMenuItem(value: 'validate', child: Text('Validations')),
                    DropdownMenuItem(value: 'review', child: Text('Revues')),
                    DropdownMenuItem(value: 'export', child: Text('Exports')),
                    DropdownMenuItem(value: 'update', child: Text('Modifications')),
                    DropdownMenuItem(value: 'delete', child: Text('Suppressions')),
                    DropdownMenuItem(value: 'import_apply', child: Text('Imports')),
                  ],
                  onChanged: (v) => setState(() {
                    _action = v ?? '';
                    _future = _load();
                  }),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Vérifier la chaîne'),
                onPressed: cabinet == null
                    ? null
                    : () async {
                        final broken = await ref.read(adminRepositoryProvider).verifyChain(cabinet.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(broken == null ? 'Chaîne SHA-256 intègre.' : 'Rupture détectée à l\'événement n° $broken !'),
                          backgroundColor: broken == null ? t.success : t.danger,
                        ));
                      },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AuditEvent>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
              final events = snap.data ?? const [];
              return ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  AkCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(children: [
                      for (var i = 0; i < events.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: t.border),
                        ListTile(
                          dense: true,
                          leading: Text('${events[i].id}', style: AkText.code.copyWith(color: t.textMuted)),
                          title: Text('${events[i].action}${events[i].tableName != null ? ' · ${events[i].tableName}' : ''}', style: AkText.bodyStrong.copyWith(color: t.text)),
                          subtitle: Text(
                            '${Fmt.date(events[i].occurredAt)} ${events[i].occurredAt.hour.toString().padLeft(2, '0')}:${events[i].occurredAt.minute.toString().padLeft(2, '0')} · ${events[i].actorName ?? 'système'} · ${events[i].hash.substring(0, 12)}…',
                            style: AkText.caption.copyWith(color: t.textMuted),
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(title: Text('Événement ${events[i].id}'), content: SingleChildScrollView(child: SelectableText(events[i].payload.toString(), style: AkText.code))),
                          ),
                        ),
                      ],
                      if (events.isEmpty) const Padding(padding: EdgeInsets.all(AkSpace.s4), child: Text('Aucun événement.')),
                    ]),
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
