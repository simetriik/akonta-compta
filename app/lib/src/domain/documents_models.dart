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
