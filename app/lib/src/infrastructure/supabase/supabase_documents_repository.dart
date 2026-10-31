import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/documents_models.dart';
import '../../core/errors/app_error.dart';
import 'mappers/documents_repository_mappers.dart';
import '../../core/file_tools.dart';
import '../../domain/repositories/documents_repository.dart';

/// Module 5 : dépôt dans le Storage privé, enregistrement avec empreinte, boîte de réception, rattachement, visionneuse.
class SupabaseDocumentsRepository implements DocumentsRepository {
  SupabaseDocumentsRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'documents';

  @override
  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false}) async {
    final rows = await _client.from('documents').select('*, entry_documents(entry_id)').eq('entity_id', entityId).order('captured_at', ascending: false).limit(500);
    final docs = rows.map(documentModelFromJson).toList();
    return inboxOnly ? docs.where((d) => d.isInInbox).toList() : docs;
  }

  @override
  Future<List<DocumentModel>> forEntry(String entryId) async {
    final rows = await _client.from('entry_documents').select('documents(*, entry_documents(entry_id))').eq('entry_id', entryId);
    return [for (final r in rows) documentModelFromJson(r['documents'] as Map<String, dynamic>)];
  }

  /// Dépose un fichier : contrôle du type et de la taille, envoi au Storage sous `cabinet/entité/uuid.ext`, enregistrement.
  @override
  Future<DocumentModel> upload({required String cabinetId, required String entityId, required String fileName, required Uint8List bytes, required String capturedVia, String? note}) async {
    final mime = mimeTypeFor(fileName);
    if (mime == null) throw const AppError.business('Format non admis : PDF, JPEG, PNG ou HEIC uniquement.');
    if (bytes.length > maxDocumentBytes) throw const AppError.business('Fichier trop volumineux (20 Mo maximum).');
    if (bytes.isEmpty) throw const AppError.business('Le fichier est vide.');
    final id = _uuid();
    final ext = fileName.split('.').last.toLowerCase();
    final path = '$cabinetId/$entityId/$id.$ext';
    await _client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    try {
      final row = await _client.from('documents').insert({
        'id': id,
        'cabinet_id': cabinetId,
        'entity_id': entityId,
        'storage_path': path,
        'file_name': fileName,
        'mime_type': mime,
        'size_bytes': bytes.length,
        'sha256': sha256Hex(bytes),
        'captured_via': capturedVia,
        'note': note,
      }).select('*, entry_documents(entry_id)').single();
      return documentModelFromJson(row);
    } catch (e) {
      await _client.storage.from(bucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> attach(String entryId, String documentId) => _client.from('entry_documents').insert({'entry_id': entryId, 'document_id': documentId});

  @override
  Future<void> detach(String entryId, String documentId) => _client.from('entry_documents').delete().eq('entry_id', entryId).eq('document_id', documentId);

  @override
  Future<void> delete(DocumentModel d) async {
    await _client.from('documents').delete().eq('id', d.id);
    await _client.storage.from(bucket).remove([d.storagePath]);
  }

  /// URL signée (compartiment privé), valable 10 minutes.
  @override
  Future<String> signedUrl(DocumentModel d) => _client.storage.from(bucket).createSignedUrl(d.storagePath, 600);

  @override
  Future<Uint8List> download(DocumentModel d) => _client.storage.from(bucket).download(d.storagePath);

  static String _uuid() {
    final r = DateTime.now().microsecondsSinceEpoch;
    final rand = List.generate(16, (i) => (r >> (i * 3) ^ (i * 7919) ^ DateTime.now().millisecond) & 0xff);
    rand[6] = (rand[6] & 0x0f) | 0x40;
    rand[8] = (rand[8] & 0x3f) | 0x80;
    final h = rand.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
