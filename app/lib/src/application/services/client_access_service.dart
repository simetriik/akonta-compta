import '../../domain/repositories/client_access_repository.dart';
import '../connectivity/connectivity.dart';

/// Cas d'usage de l'accès des clients : exige une connexion, car la base décide et inscrit chaque changement.
class ClientAccessService {
  ClientAccessService(this._repository, this._online);

  final ClientAccessRepository _repository;
  final OnlinePolicy _online;

  Future<String> access(String entityId) => _repository.access(entityId);

  Future<void> setAccess(String entityId, String status, {String? reason}) async {
    _online.require('Le changement d\'accès des clients');
    return _repository.setAccess(entityId, status, reason: reason?.trim().isEmpty ?? true ? null : reason!.trim());
  }

  Future<void> returnDraft(String entryId, String comment) async {
    _online.require('Le renvoi d\'un brouillard');
    if (comment.trim().isEmpty) throw ArgumentError('Un motif est obligatoire');
    return _repository.returnDraft(entryId, comment.trim());
  }
}
