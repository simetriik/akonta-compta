import '../connectivity/connectivity.dart';
import '../../domain/repositories/lettering_repository.dart';
import '../../domain/lettering_models.dart';

/// Cas d'usage lettering : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class LetteringService {
  LetteringService(this._repository, this._online);

  final LetteringRepository _repository;
  final OnlinePolicy _online;

  Future<List<UnletteredLine>> unlettered(String entityId, String accountId, {String? thirdPartyId}) async {
    _online.require('Le lettrage');
    return _repository.unlettered(entityId, accountId, thirdPartyId: thirdPartyId);
  }

  Future<List<LetteringProposal>> proposals(String entityId, String accountId, {String? thirdPartyId}) async {
    _online.require('Le lettrage');
    return _repository.proposals(entityId, accountId, thirdPartyId: thirdPartyId);
  }

  Future<String> letter(List<String> lineIds, {bool allowPartial = false}) async {
    _online.require('Le lettrage');
    return _repository.letter(lineIds, allowPartial: allowPartial);
  }

  Future<void> unletter(String letteringId, String reason) async {
    _online.require('Le lettrage');
    return _repository.unletter(letteringId, reason);
  }

  Future<List<LetteringGroup>> groups(String entityId, String accountId, {String? thirdPartyId}) async {
    _online.require('Le lettrage');
    return _repository.groups(entityId, accountId, thirdPartyId: thirdPartyId);
  }

  Future<void> setLetterable(String accountId, bool value) async {
    _online.require('Le lettrage');
    return _repository.setLetterable(accountId, value);
  }
}
