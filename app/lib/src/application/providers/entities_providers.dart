import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entity_models.dart';
import 'services.dart';

final entitiesListProvider = FutureProvider<List<EntityDetail>>((ref) => ref.watch(entitiesServiceProvider).list());

final entityProvider = FutureProvider.family<EntityDetail, String>((ref, id) => ref.watch(entitiesServiceProvider).get(id));

final fiscalYearsProvider = FutureProvider.family<List<FiscalYear>, String>((ref, entityId) => ref.watch(entitiesServiceProvider).fiscalYears(entityId));

final periodsProvider = FutureProvider.family<List<Period>, String>((ref, fyId) => ref.watch(entitiesServiceProvider).periods(fyId));

final directorsProvider = FutureProvider.family<List<Director>, String>((ref, entityId) => ref.watch(entitiesServiceProvider).directors(entityId));

final entityHistoryProvider = FutureProvider.family<List<EntityHistoryItem>, String>((ref, entityId) => ref.watch(entitiesServiceProvider).history(entityId));

final journalTemplatesProvider = FutureProvider<List<JournalTemplate>>((ref) => ref.watch(entitiesServiceProvider).journalTemplates());
