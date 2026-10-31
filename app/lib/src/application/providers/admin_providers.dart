import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/admin_models.dart';
import 'services.dart';

final profilesProvider = FutureProvider<List<Profile>>((ref) => ref.watch(adminServiceProvider).profiles());

final rolesProvider = FutureProvider<List<RoleDef>>((ref) => ref.watch(adminServiceProvider).roles());

final permissionDefsProvider = FutureProvider<List<PermissionDef>>((ref) => ref.watch(adminServiceProvider).permissions());

final assignmentsProvider = FutureProvider<List<Assignment>>((ref) => ref.watch(adminServiceProvider).assignments());

final adminEntitiesProvider = FutureProvider<List<({String id, String name})>>((ref) => ref.watch(adminServiceProvider).entities());
