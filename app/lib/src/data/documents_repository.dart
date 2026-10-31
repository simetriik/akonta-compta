import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';
import '../core/errors/errors.dart';

class DocumentModel {
  const DocumentModel({required this.id, required this.entityId, required this.storagePath, required this.fileName, required this.mimeType, required this.sizeBytes, required this.sha256, required this.capturedVia, required this.capturedAt, this.note, this.entryIds = const []});

  final String id;
  final String entityId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String capturedVia;
  final DateTime capturedAt;
  final String? note;
  final List<String> entryIds;

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
        id: j['id'] as String,
        entityId: j['entity_id'] as String,
        storagePath: j['storage_path'] as String,
        fileName: j['file_name'] as String,
        mimeType: j['mime_type'] as String,
        sizeBytes: (j['size_bytes'] as num).toInt(),
        sha256: j['sha256'] as String,
        capturedVia: j['captured_via'] as String,
        capturedAt: DateTime.parse(j['captured_at'] as String).toLocal(),
        note: j['note'] as String?,
        entryIds: [for (final l in (j['entry_documents'] as List? ?? const [])) l['entry_id'] as String],
      );

  bool get isInInbox => entryIds.isEmpty;
  bool get isImage => mimeType.startsWith('image/');
}

/// Types admis (conception §10.5) déduits de l'extension.
String? mimeTypeFor(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => null,
  };
}

const maxDocumentBytes = 20 * 1024 * 1024;

/// Empreinte SHA-256 hexadécimale d'un fichier.
String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

/// Module 5 : dépôt dans le Storage privé, enregistrement avec empreinte, boîte de réception, rattachement, visionneuse.
class DocumentsRepository {
  DocumentsRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'documents';

  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false}) async {
    final rows = await _client.from('documents').select('*, entry_documents(entry_id)').eq('entity_id', entityId).order('captured_at', ascending: false).limit(500);
    final docs = rows.map(DocumentModel.fromJson).toList();
    return inboxOnly ? docs.where((d) => d.isInInbox).toList() : docs;
  }

  Future<List<DocumentModel>> forEntry(String entryId) async {
    final rows = await _client.from('entry_documents').select('documents(*, entry_documents(entry_id))').eq('entry_id', entryId);
    return [for (final r in rows) DocumentModel.fromJson(r['documents'] as Map<String, dynamic>)];
  }

  /// Dépose un fichier : contrôle du type et de la taille, envoi au Storage sous `cabinet/entité/uuid.ext`, enregistrement.
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
      return DocumentModel.fromJson(row);
    } catch (e) {
      await _client.storage.from(bucket).remove([path]);
      rethrow;
    }
  }

  Future<void> attach(String entryId, String documentId) => _client.from('entry_documents').insert({'entry_id': entryId, 'document_id': documentId});

  Future<void> detach(String entryId, String documentId) => _client.from('entry_documents').delete().eq('entry_id', entryId).eq('document_id', documentId);

  Future<void> delete(DocumentModel d) async {
    await _client.from('documents').delete().eq('id', d.id);
    await _client.storage.from(bucket).remove([d.storagePath]);
  }

  /// URL signée (compartiment privé), valable 10 minutes.
  Future<String> signedUrl(DocumentModel d) => _client.storage.from(bucket).createSignedUrl(d.storagePath, 600);

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

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) => DocumentsRepository(ref.watch(supabaseClientProvider)));
final documentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entityId) => ref.watch(documentsRepositoryProvider).list(entityId));
final entryDocumentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entryId) => ref.watch(documentsRepositoryProvider).forEntry(entryId));
