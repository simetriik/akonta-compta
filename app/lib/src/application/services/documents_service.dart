import 'dart:typed_data';

import '../../core/errors/errors.dart';
import '../../domain/outbox_models.dart';
import '../../domain/repositories/documents_repository.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../connectivity/connectivity.dart';
import '../offline/outbox_codec.dart';
import '../../domain/documents_models.dart';

/// Cas d'usage documents : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class DocumentsService {
  DocumentsService(this._repository, this._online, this._outbox);

  final DocumentsRepository _repository;
  final OnlinePolicy _online;
  final OutboxRepository _outbox;

  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false}) async {
    return _repository.list(entityId, inboxOnly: inboxOnly);
  }

  Future<List<DocumentModel>> forEntry(String entryId) async {
    return _repository.forEntry(entryId);
  }

  /// Dépose un fichier : contrôle du type et de la taille, envoi au Storage sous `cabinet/entité/uuid.ext`, enregistrement.
  /// Dépose un fichier. Hors connexion, la pièce est conservée sur l'appareil et envoyée à la reconnexion : le résultat est alors null.
  Future<DocumentModel?> upload({
    required String cabinetId,
    required String entityId,
    required String fileName,
    required Uint8List bytes,
    required String capturedVia,
    String? note,
  }) async {
    if (_online.isOnline) {
      try {
        return await _repository.upload(cabinetId: cabinetId, entityId: entityId, fileName: fileName, bytes: bytes, capturedVia: capturedVia, note: note);
      } catch (e) {
        if (!isConnectivityFailure(e)) rethrow;
      }
    }
    await _outbox.enqueue(
      OutboxKind.documentUpload,
      encodeDocumentUpload(cabinetId: cabinetId, entityId: entityId, fileName: fileName, bytes: bytes, capturedVia: capturedVia, note: note),
    );
    return null;
  }

  Future<void> attach(String entryId, String documentId) async {
    _online.require('La gestion des pièces');
    return _repository.attach(entryId, documentId);
  }

  Future<void> detach(String entryId, String documentId) async {
    _online.require('La gestion des pièces');
    return _repository.detach(entryId, documentId);
  }

  Future<void> delete(DocumentModel d) async {
    _online.require('La gestion des pièces');
    return _repository.delete(d);
  }

  /// URL signée (compartiment privé), valable 10 minutes.
  Future<String> signedUrl(DocumentModel d) async {
    _online.require('La gestion des pièces');
    return _repository.signedUrl(d);
  }

  Future<Uint8List> download(DocumentModel d) async {
    _online.require('La gestion des pièces');
    return _repository.download(d);
  }

  Future<ScanProposal> proposeEntry(String documentId) async {
    _online.require('La lecture automatique des pièces');
    return _repository.proposeEntry(documentId);
  }
}
