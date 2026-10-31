import '../suggestion_models.dart';

abstract interface class SuggestionsRepository {
  Future<List<EntrySuggestion>> entries(String entityId, String label, {int limit = 3});

  Future<List<AccountSuggestion>> accounts(String entityId, String label, {String? thirdPartyId, int limit = 3});

  Future<List<TemplateSuggestion>> templates(String entityId, String label, {int limit = 2});

  Future<List<DuplicateEntry>> duplicates( String entityId, { required String reference, required int amount, String? thirdPartyId, String? excludeEntryId, });
}
