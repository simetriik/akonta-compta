import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models.dart';
import '../../domain/admin_models.dart';
import 'repositories.dart';

final profilesProvider = FutureProvider<List<Profile>>((ref) => ref.watch(adminRepositoryProvider).profiles());

final rolesProvider = FutureProvider<List<RoleDef>>((ref) => ref.watch(adminRepositoryProvider).roles());

final permissionDefsProvider = FutureProvider<List<PermissionDef>>((ref) => ref.watch(adminRepositoryProvider).permissions());

final assignmentsProvider = FutureProvider<List<Assignment>>((ref) => ref.watch(adminRepositoryProvider).assignments());

final adminEntitiesProvider = FutureProvider<List<({String id, String name})>>((ref) => ref.watch(adminRepositoryProvider).entities());
