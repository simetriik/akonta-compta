import 'dart:typed_data';
import 'package:crypto/crypto.dart';
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
