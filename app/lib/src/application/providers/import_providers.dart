import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/import_models.dart';
import 'repositories.dart';

final importBatchesProvider = FutureProvider.family<List<ImportBatch>, String>((ref, entityId) => ref.watch(importRepositoryProvider).batches(entityId));

final importMappingsProvider = FutureProvider.family<List<AccountMapping>, (String, String)>((ref, key) => ref.watch(importRepositoryProvider).mappings(key.$1, key.$2));
