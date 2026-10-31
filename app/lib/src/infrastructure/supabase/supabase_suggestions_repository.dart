import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/suggestion_models.dart';
import 'mappers/suggestion_models_mappers.dart';
import '../../domain/repositories/suggestions_repository.dart';

/// Suggestions de saisie calculées par la base (fonctions `suggest_*` et `find_duplicate_entries`), sous les droits de l'utilisateur.
class SupabaseSuggestionsRepository implements SuggestionsRepository {
  SupabaseSuggestionsRepository(this._client);

  final SupabaseClient _client;

  List<Map<String, dynamic>> _rows(Object? r) => [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];

  @override
  Future<List<EntrySuggestion>> entries(String entityId, String label, {int limit = 3}) async =>
      _rows(await _client.rpc('suggest_entries', params: {'p_entity': entityId, 'p_label': label, 'p_limit': limit})).map(entrySuggestionFromJson).toList();

  @override
  Future<List<AccountSuggestion>> accounts(String entityId, String label, {String? thirdPartyId, int limit = 3}) async =>
      _rows(await _client.rpc('suggest_accounts', params: {'p_entity': entityId, 'p_label': label, 'p_third_party': thirdPartyId, 'p_limit': limit}))
          .map(accountSuggestionFromJson)
          .toList();

  @override
  Future<List<TemplateSuggestion>> templates(String entityId, String label, {int limit = 2}) async =>
      _rows(await _client.rpc('suggest_templates', params: {'p_entity': entityId, 'p_label': label, 'p_limit': limit}))
          .map(templateSuggestionFromJson)
          .toList();

  @override
  Future<List<DuplicateEntry>> duplicates(
    String entityId, {
    required String reference,
    required int amount,
    String? thirdPartyId,
    String? excludeEntryId,
  }) async => _rows(
    await _client.rpc(
      'find_duplicate_entries',
      params: {'p_entity': entityId, 'p_reference': reference, 'p_amount': amount, 'p_third_party': thirdPartyId, 'p_exclude': excludeEntryId},
    ),
  ).map(duplicateEntryFromJson).toList();
}
