import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'supabase_providers.dart';

/// Rôle d'un cabinet avec ses permissions (ajustables par l'associé).
class RoleDef {
  const RoleDef({required this.id, required this.code, required this.name, required this.isSystem, required this.permissions});

  final String id;
  final String code;
  final String name;
  final bool isSystem;
  final Set<String> permissions;
}

class PermissionDef {
  const PermissionDef({required this.code, required this.label, required this.category});

  final String code;
  final String label;
  final String category;
}

class Assignment {
  const Assignment({required this.id, required this.userId, required this.userName, required this.roleId, required this.roleName, required this.roleCode, this.entityId, this.entityName});

  final String id;
  final String userId;
  final String userName;
  final String roleId;
  final String roleName;
  final String roleCode;
  final String? entityId;
  final String? entityName;
}

class AuditEvent {
  const AuditEvent({required this.id, required this.occurredAt, required this.action, this.actorName, this.tableName, this.recordId, this.entityId, required this.payload, required this.hash});

  final int id;
  final DateTime occurredAt;
  final String action;
  final String? actorName;
  final String? tableName;
  final String? recordId;
  final String? entityId;
  final Map<String, dynamic> payload;
  final String hash;
}

class InviteResult {
  const InviteResult({required this.invited, required this.failed, required this.parseErrors});

  final List<String> invited;
  final List<String> failed;
  final List<String> parseErrors;
}

/// Administration : utilisateurs, invitations, rôles, affectations, piste d'audit (module 1).
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> profiles() async {
    final rows = await _client.from('profiles').select().order('full_name');
    return rows.map(Profile.fromJson).toList();
  }

  Future<void> setActive(String userId, bool active) => _client.from('profiles').update({'is_active': active}).eq('id', userId);

  Future<void> updateProfile(String userId, {required String fullName, String? jobTitle}) =>
      _client.from('profiles').update({'full_name': fullName, 'job_title': jobTitle}).eq('id', userId);

  Future<InviteResult> invite({String? email, String? fullName, String? jobTitle, String? csv}) async {
    final res = await _client.functions.invoke('invite-user', body: {
      'email': ?email,
      'full_name': ?fullName,
      'job_title': ?jobTitle,
      'csv': ?csv,
    });
    final data = res.data as Map<String, dynamic>;
    return InviteResult(
      invited: [for (final i in (data['invited'] as List? ?? [])) i['email'] as String],
      failed: [for (final f in (data['failed'] as List? ?? [])) '${f['email']} : ${f['error']}'],
      parseErrors: [for (final e in (data['parse_errors'] as List? ?? [])) 'ligne ${e['line']} : ${e['error']}'],
    );
  }

  Future<List<PermissionDef>> permissions() async {
    final rows = await _client.from('permissions').select().order('sort_order');
    return [for (final r in rows) PermissionDef(code: r['code'] as String, label: r['label'] as String, category: r['category'] as String)];
  }

  Future<List<RoleDef>> roles() async {
    final rows = await _client.from('roles').select('id, code, name, is_system, role_permissions(permission_code)').order('code');
    return [
      for (final r in rows)
        RoleDef(
          id: r['id'] as String,
          code: r['code'] as String,
          name: r['name'] as String,
          isSystem: r['is_system'] as bool,
          permissions: {for (final p in (r['role_permissions'] as List)) p['permission_code'] as String},
        ),
    ];
  }

  Future<void> setRolePermission(String roleId, String code, bool granted) async {
    if (granted) {
      await _client.from('role_permissions').upsert({'role_id': roleId, 'permission_code': code});
    } else {
      await _client.from('role_permissions').delete().eq('role_id', roleId).eq('permission_code', code);
    }
  }

  Future<List<Assignment>> assignments() async {
    final rows = await _client
        .from('assignments')
        .select('id, user_id, entity_id, role_id, profiles!assignments_user_id_fkey(full_name, email), roles(name, code), entities(name)')
        .order('created_at');
    return [
      for (final r in rows)
        Assignment(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          userName: ((r['profiles'] as Map)['full_name'] as String?)?.isNotEmpty == true ? (r['profiles'] as Map)['full_name'] as String : (r['profiles'] as Map)['email'] as String,
          roleId: r['role_id'] as String,
          roleName: (r['roles'] as Map)['name'] as String,
          roleCode: (r['roles'] as Map)['code'] as String,
          entityId: r['entity_id'] as String?,
          entityName: (r['entities'] as Map?)?['name'] as String?,
        ),
    ];
  }

  Future<List<({String id, String name})>> entities() async {
    final rows = await _client.from('entities').select('id, name').eq('is_active', true).order('name');
    return [for (final r in rows) (id: r['id'] as String, name: r['name'] as String)];
  }

  Future<void> addAssignment({required String cabinetId, required String userId, required String roleId, String? entityId}) =>
      _client.from('assignments').insert({'cabinet_id': cabinetId, 'user_id': userId, 'role_id': roleId, 'entity_id': entityId});

  Future<void> removeAssignment(String id) => _client.from('assignments').delete().eq('id', id);

  /// Réaffectation en masse : tous les dossiers d'un collaborateur passent à un autre (même rôle).
  Future<int> reassignAll({required String cabinetId, required String fromUserId, required String toUserId}) async {
    final current = (await assignments()).where((a) => a.userId == fromUserId && a.entityId != null).toList();
    for (final a in current) {
      await _client.from('assignments').upsert({'cabinet_id': cabinetId, 'user_id': toUserId, 'role_id': a.roleId, 'entity_id': a.entityId},
          onConflict: 'user_id,role_id,entity_id', ignoreDuplicates: true);
      await removeAssignment(a.id);
    }
    return current.length;
  }

  Future<List<AuditEvent>> auditLog({String? action, String? entityId, DateTime? from, DateTime? to, int limit = 200}) async {
    var q = _client.from('audit_log').select('id, occurred_at, action, table_name, record_id, entity_id, payload, hash, actor_id');
    if (action != null && action.isNotEmpty) q = q.eq('action', action);
    if (entityId != null) q = q.eq('entity_id', entityId);
    if (from != null) q = q.gte('occurred_at', from.toIso8601String());
    if (to != null) q = q.lt('occurred_at', to.add(const Duration(days: 1)).toIso8601String());
    final rows = await q.order('id', ascending: false).limit(limit);
    final actorIds = {for (final r in rows) if (r['actor_id'] != null) r['actor_id'] as String};
    final names = <String, String>{};
    if (actorIds.isNotEmpty) {
      final profiles = await _client.from('profiles').select('id, full_name, email').inFilter('id', actorIds.toList());
      for (final p in profiles) {
        names[p['id'] as String] = (p['full_name'] as String?)?.isNotEmpty == true ? p['full_name'] as String : p['email'] as String;
      }
    }
    return [
      for (final r in rows)
        AuditEvent(
          id: (r['id'] as num).toInt(),
          occurredAt: DateTime.parse(r['occurred_at'] as String).toLocal(),
          action: r['action'] as String,
          actorName: names[r['actor_id']],
          tableName: r['table_name'] as String?,
          recordId: r['record_id'] as String?,
          entityId: r['entity_id'] as String?,
          payload: (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
          hash: r['hash'] as String,
        ),
    ];
  }

  /// Renvoie null si la chaîne est intègre, sinon l'identifiant du premier maillon rompu.
  Future<int?> verifyChain(String cabinetId) async {
    final r = await _client.rpc('audit_chain_verify', params: {'p_cabinet': cabinetId});
    return r == null ? null : (r as num).toInt();
  }

  Future<void> updateCabinet(String id, Map<String, dynamic> values) => _client.from('cabinets').update(values).eq('id', id);
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository(ref.watch(supabaseClientProvider)));
final profilesProvider = FutureProvider<List<Profile>>((ref) => ref.watch(adminRepositoryProvider).profiles());
final rolesProvider = FutureProvider<List<RoleDef>>((ref) => ref.watch(adminRepositoryProvider).roles());
final permissionDefsProvider = FutureProvider<List<PermissionDef>>((ref) => ref.watch(adminRepositoryProvider).permissions());
final assignmentsProvider = FutureProvider<List<Assignment>>((ref) => ref.watch(adminRepositoryProvider).assignments());
final adminEntitiesProvider = FutureProvider<List<({String id, String name})>>((ref) => ref.watch(adminRepositoryProvider).entities());
