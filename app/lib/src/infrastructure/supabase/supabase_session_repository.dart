import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models.dart';
import '../../domain/repositories/session_repository.dart';
import 'mappers/models_mappers.dart';

/// Contexte de l'utilisateur connecté lu dans Supabase (RLS : son cabinet, ses dossiers).
class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> profile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : profileFromJson(row);
  }

  @override
  Future<Cabinet?> cabinet(String cabinetId) async {
    final row = await _client.from('cabinets').select().eq('id', cabinetId).maybeSingle();
    return row == null ? null : cabinetFromJson(row);
  }

  @override
  Future<PermissionSet> permissions(String userId) async {
    final assignments = await _client
        .from('assignments')
        .select('role_id, entity_id, roles(code, name, requires_mfa, grants_all_entities, accounting_access, is_client)')
        .eq('user_id', userId);
    final roles = assignments.map((j) => assignedRoleFromJson(j)).toList();
    if (roles.isEmpty) return PermissionSet.empty;
    final roleIds = roles.map((r) => r.roleId).toSet().toList();
    final perms = await _client.from('role_permissions').select('role_id, permission_code').inFilter('role_id', roleIds);
    final byRole = <String, Set<String>>{};
    for (final p in perms) {
      byRole.putIfAbsent(p['role_id'] as String, () => <String>{}).add(p['permission_code'] as String);
    }
    final byEntity = <String, Set<String>>{};
    final cabinetWide = <String>{};
    for (final r in roles) {
      final codes = byRole[r.roleId] ?? const <String>{};
      if (r.entityId == null) {
        cabinetWide.addAll(codes);
      } else {
        byEntity.putIfAbsent(r.entityId!, () => <String>{}).addAll(codes);
      }
    }
    return PermissionSet(byEntity: byEntity, cabinetWide: cabinetWide, roles: roles);
  }

  @override
  Future<List<EntitySummary>> dashboard() async {
    final rows = await _client.rpc('entity_dashboard') as List<dynamic>;
    return rows.map((j) => entitySummaryFromJson(j as Map<String, dynamic>)).toList();
  }
}
