import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/admin_models.dart';
import 'services.dart';

final profilesProvider = FutureProvider<List<Profile>>((ref) => ref.watch(adminServiceProvider).profiles());

/// Vrai si le cabinet a déjà un associé ; sinon l'invitation propose de donner ce rôle au premier (Q-016).
final cabinetHasPartnerProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(adminServiceProvider).cabinetHasPartner());

final rolesProvider = FutureProvider<List<RoleDef>>((ref) => ref.watch(adminServiceProvider).roles());

final permissionDefsProvider = FutureProvider<List<PermissionDef>>((ref) => ref.watch(adminServiceProvider).permissions());

final assignmentsProvider = FutureProvider<List<Assignment>>((ref) => ref.watch(adminServiceProvider).assignments());

final adminEntitiesProvider = FutureProvider<List<({String id, String name})>>((ref) => ref.watch(adminServiceProvider).entities());
