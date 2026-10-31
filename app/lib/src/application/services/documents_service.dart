import 'dart:typed_data';
import '../connectivity/connectivity.dart';
import '../../domain/repositories/documents_repository.dart';
import '../../domain/documents_models.dart';

/// Cas d'usage documents : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class DocumentsService {
  DocumentsService(this._repository, this._online);

  final DocumentsRepository _repository;
  final OnlinePolicy _online;

  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false}) async {
    _online.require('La gestion des pièces');
    return _repository.list(entityId, inboxOnly: inboxOnly);
  }

  Future<List<DocumentModel>> forEntry(String entryId) async {
    _online.require('La gestion des pièces');
    return _repository.forEntry(entryId);
  }

/// Dépose un fichier : contrôle du type et de la taille, envoi au Storage sous `cabinet/entité/uuid.ext`, enregistrement.
  Future<DocumentModel> upload({required String cabinetId, required String entityId, required String fileName, required Uint8List bytes, required String capturedVia, String? note}) async {
    return _repository.upload(cabinetId: cabinetId, entityId: entityId, fileName: fileName, bytes: bytes, capturedVia: capturedVia, note: note);
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
}
