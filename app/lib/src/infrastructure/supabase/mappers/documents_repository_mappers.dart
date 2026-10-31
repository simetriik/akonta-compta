import '../../../domain/documents_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

DocumentModel documentModelFromJson(Map<String, dynamic> j) => DocumentModel(
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
