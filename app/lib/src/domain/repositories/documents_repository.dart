import 'dart:typed_data';
import '../documents_models.dart';

abstract interface class DocumentsRepository {
  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false});

  Future<List<DocumentModel>> forEntry(String entryId);

  /// Dépose un fichier : contrôle du type et de la taille, envoi au Storage sous `cabinet/entité/uuid.ext`, enregistrement.
  Future<DocumentModel> upload({required String cabinetId, required String entityId, required String fileName, required Uint8List bytes, required String capturedVia, String? note});

  Future<void> attach(String entryId, String documentId);

  Future<void> detach(String entryId, String documentId);

  Future<void> delete(DocumentModel d);

  /// URL signée (compartiment privé), valable 10 minutes.
  Future<String> signedUrl(DocumentModel d);

  Future<Uint8List> download(DocumentModel d);

  /// Lit la pièce (service local, sans modèle en ligne) et crée une écriture proposée en brouillard, liée à la pièce.
  Future<ScanProposal> proposeEntry(String documentId);
}
