import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entity_models.dart';
import 'repositories.dart';

final entitiesListProvider = FutureProvider<List<EntityDetail>>((ref) => ref.watch(entitiesRepositoryProvider).list());

final entityProvider = FutureProvider.family<EntityDetail, String>((ref, id) => ref.watch(entitiesRepositoryProvider).get(id));

final fiscalYearsProvider = FutureProvider.family<List<FiscalYear>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).fiscalYears(entityId));

final periodsProvider = FutureProvider.family<List<Period>, String>((ref, fyId) => ref.watch(entitiesRepositoryProvider).periods(fyId));

final directorsProvider = FutureProvider.family<List<Director>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).directors(entityId));

final entityHistoryProvider = FutureProvider.family<List<EntityHistoryItem>, String>((ref, entityId) => ref.watch(entitiesRepositoryProvider).history(entityId));

final journalTemplatesProvider = FutureProvider<List<JournalTemplate>>((ref) => ref.watch(entitiesRepositoryProvider).journalTemplates());
