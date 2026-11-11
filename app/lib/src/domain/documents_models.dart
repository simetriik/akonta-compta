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

  bool get isInInbox => entryIds.isEmpty;
  bool get isImage => mimeType.startsWith('image/');
}

/// Résultat de la lecture d'une pièce : brouillard proposé (ou déjà existant) et points à vérifier par le comptable.
class ScanProposal {
  const ScanProposal({required this.entryId, required this.existing, this.warnings = const []});

  final String entryId;

  /// Vrai quand la pièce avait déjà un brouillard : il est rouvert tel quel, sans être réécrit.
  final bool existing;
  final List<String> warnings;
}
