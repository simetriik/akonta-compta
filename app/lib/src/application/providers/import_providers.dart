import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/import_models.dart';
import 'services.dart';

final importBatchesProvider = FutureProvider.family<List<ImportBatch>, String>((ref, entityId) => ref.watch(importServiceProvider).batches(entityId));

final importMappingsProvider = FutureProvider.family<List<AccountMapping>, (String, String)>(
  (ref, key) => ref.watch(importServiceProvider).mappings(key.$1, key.$2),
);
