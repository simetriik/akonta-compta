import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// Client Supabase partagé (initialisé dans main.dart).
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Session courante, rafraîchie à chaque événement d'authentification.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// Identifiant de l'utilisateur connecté : ne change qu'à la connexion / déconnexion, pas à chaque
/// rafraîchissement de jeton (évite de recharger profil et permissions en boucle).
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);

/// Profil du collaborateur connecté (table profiles, RLS : son cabinet).
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final row = await ref.watch(supabaseClientProvider).from('profiles').select().eq('id', userId).maybeSingle();
  return row == null ? null : Profile.fromJson(row);
});

final currentCabinetProvider = FutureProvider<Cabinet?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  final row = await ref.watch(supabaseClientProvider).from('cabinets').select().eq('id', profile.cabinetId).maybeSingle();
  return row == null ? null : Cabinet.fromJson(row);
});

/// Permissions de l'utilisateur : affectations → rôles → permissions unitaires.
final permissionsProvider = FutureProvider<PermissionSet>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return PermissionSet.empty;
  final client = ref.watch(supabaseClientProvider);
  final assignments = await client
      .from('assignments')
      .select('role_id, entity_id, roles(code, name, requires_mfa, grants_all_entities, accounting_access)')
      .eq('user_id', userId);
  final roles = assignments.map((j) => AssignedRole.fromJson(j)).toList();
  if (roles.isEmpty) return PermissionSet.empty;
  final roleIds = roles.map((r) => r.roleId).toSet().toList();
  final perms = await client.from('role_permissions').select('role_id, permission_code').inFilter('role_id', roleIds);
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
});

/// Dossiers accessibles avec leurs indicateurs (fonction SQL entity_dashboard).
final entityDashboardProvider = FutureProvider<List<EntitySummary>>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await ref.watch(supabaseClientProvider).rpc('entity_dashboard') as List<dynamic>;
  return rows.map((j) => EntitySummary.fromJson(j as Map<String, dynamic>)).toList();
});

/// Dossier courant, toujours visible dans l'interface (conception §12.3).
class CurrentEntityNotifier extends Notifier<EntitySummary?> {
  @override
  EntitySummary? build() {
    ref.watch(currentUserIdProvider);   // changement d'utilisateur : le dossier courant est oublié
    return null;
  }

  void select(EntitySummary? entity) => state = entity;
}

final currentEntityProvider = NotifierProvider<CurrentEntityNotifier, EntitySummary?>(CurrentEntityNotifier.new);
