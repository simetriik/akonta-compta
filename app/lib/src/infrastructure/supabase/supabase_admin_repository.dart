import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/admin_models.dart';
import '../../domain/models.dart';
import 'mappers/models_mappers.dart';
import '../../domain/repositories/admin_repository.dart';

/// Administration : utilisateurs, invitations, rôles, affectations, piste d'audit (module 1).
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Profile>> profiles() async {
    final rows = await _client.from('profiles').select().order('full_name', ascending: true);
    return rows.map(profileFromJson).toList();
  }

  @override
  Future<void> setActive(String userId, bool active) => _client.from('profiles').update({'is_active': active}).eq('id', userId);

  @override
  Future<void> updateProfile(String userId, {required String fullName, String? jobTitle}) =>
      _client.from('profiles').update({'full_name': fullName, 'job_title': jobTitle}).eq('id', userId);

  @override
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

  @override
  Future<List<PermissionDef>> permissions() async {
    final rows = await _client.from('permissions').select().order('sort_order', ascending: true);
    return [for (final r in rows) PermissionDef(code: r['code'] as String, label: r['label'] as String, category: r['category'] as String)];
  }

  @override
  Future<List<RoleDef>> roles() async {
    final rows = await _client.from('roles').select('id, code, name, is_system, role_permissions(permission_code)').order('code', ascending: true);
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

  @override
  Future<void> setRolePermission(String roleId, String code, bool granted) async {
    if (granted) {
      await _client.from('role_permissions').upsert({'role_id': roleId, 'permission_code': code});
    } else {
      await _client.from('role_permissions').delete().eq('role_id', roleId).eq('permission_code', code);
    }
  }

  @override
  Future<List<Assignment>> assignments() async {
    final rows = await _client
        .from('assignments')
        .select('id, user_id, entity_id, role_id, profiles!assignments_user_id_fkey(full_name, email), roles(name, code), entities(name)')
        .order('created_at', ascending: true);
    return [
      // Une ligne dont le profil n'est pas lisible (masqué par la RLS) est ignorée plutôt que de faire échouer la liste.
      for (final r in rows)
        if (r['profiles'] is Map)
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

  @override
  Future<List<({String id, String name})>> entities() async {
    final rows = await _client.from('entities').select('id, name').eq('is_active', true).order('name', ascending: true);
    return [for (final r in rows) (id: r['id'] as String, name: r['name'] as String)];
  }

  @override
  Future<void> addAssignment({required String cabinetId, required String userId, required String roleId, String? entityId}) =>
      _client.from('assignments').insert({'cabinet_id': cabinetId, 'user_id': userId, 'role_id': roleId, 'entity_id': entityId});

  @override
  Future<void> removeAssignment(String id) => _client.from('assignments').delete().eq('id', id);

  /// Réaffectation en masse : tous les dossiers d'un collaborateur passent à un autre (même rôle).
  @override
  Future<int> reassignAll({required String cabinetId, required String fromUserId, required String toUserId}) async {
    final current = (await assignments()).where((a) => a.userId == fromUserId && a.entityId != null).toList();
    for (final a in current) {
      await _client.from('assignments').upsert({'cabinet_id': cabinetId, 'user_id': toUserId, 'role_id': a.roleId, 'entity_id': a.entityId},
          onConflict: 'user_id,role_id,entity_id', ignoreDuplicates: true);
      await removeAssignment(a.id);
    }
    return current.length;
  }

  @override
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
      // Libellés fournis par la base : un administrateur technique y apparaît sous un nom générique (D-017).
      final labels = await _client.rpc('actor_labels', params: {'p_ids': actorIds.toList()}) as List;
      for (final l in labels) {
        names[l['id'] as String] = l['label'] as String;
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
  @override
  Future<int?> verifyChain(String cabinetId) async {
    final r = await _client.rpc('audit_chain_verify', params: {'p_cabinet': cabinetId});
    return r == null ? null : (r as num).toInt();
  }

  @override
  Future<void> updateCabinet(String id, Map<String, dynamic> values) => _client.from('cabinets').update(values).eq('id', id);
}
