import '../lettering_models.dart';

abstract interface class LetteringRepository {
  Future<List<UnletteredLine>> unlettered(String entityId, String accountId, {String? thirdPartyId});

  Future<List<LetteringProposal>> proposals(String entityId, String accountId, {String? thirdPartyId});

  Future<String> letter(List<String> lineIds, {bool allowPartial = false});

  Future<void> unletter(String letteringId, String reason);

  Future<List<LetteringGroup>> groups(String entityId, String accountId, {String? thirdPartyId});

  Future<void> setLetterable(String accountId, bool value);
}
