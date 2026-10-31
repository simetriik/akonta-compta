import '../connectivity/connectivity.dart';
import '../../domain/repositories/suggestions_repository.dart';
import '../../domain/suggestion_models.dart';

/// Cas d'usage suggestions : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class SuggestionsService {
  SuggestionsService(this._repository, this._online);

  final SuggestionsRepository _repository;
  final OnlinePolicy _online;

  Future<List<EntrySuggestion>> entries(String entityId, String label, {int limit = 3}) async {
    _online.require('Les suggestions de saisie');
    return _repository.entries(entityId, label, limit: limit);
  }

  Future<List<AccountSuggestion>> accounts(String entityId, String label, {String? thirdPartyId, int limit = 3}) async {
    _online.require('Les suggestions de saisie');
    return _repository.accounts(entityId, label, thirdPartyId: thirdPartyId, limit: limit);
  }

  Future<List<TemplateSuggestion>> templates(String entityId, String label, {int limit = 2}) async {
    _online.require('Les suggestions de saisie');
    return _repository.templates(entityId, label, limit: limit);
  }

  Future<List<DuplicateEntry>> duplicates( String entityId, { required String reference, required int amount, String? thirdPartyId, String? excludeEntryId, }) async {
    _online.require('Les suggestions de saisie');
    return _repository.duplicates(entityId, reference: reference, amount: amount, thirdPartyId: thirdPartyId, excludeEntryId: excludeEntryId);
  }
}
