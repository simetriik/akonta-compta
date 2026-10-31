import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entry_models.dart';
import 'repositories.dart';

final entryFilterProvider = NotifierProvider<EntryFilterNotifier, EntryFilter>(EntryFilterNotifier.new);

final entriesListProvider = FutureProvider.family<List<EntryModel>, String>((ref, entityId) {
  final filter = ref.watch(entryFilterProvider);
  final current = ref.watch(currentEntityProvider);
  final fiscalYearId = current?.id == entityId ? current?.fiscalYearId : null;
  return ref.watch(entriesRepositoryProvider).list(entityId, filter, fiscalYearId: fiscalYearId);
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(entriesRepositoryProvider).notifications();
});

class EntryFilterNotifier extends Notifier<EntryFilter> {
  @override
  EntryFilter build() => EntryFilter(month: DateTime(DateTime.now().year, DateTime.now().month, 1));

  void set(EntryFilter f) => state = f;
}
