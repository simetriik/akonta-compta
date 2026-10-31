import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Demande où enregistrer un export puis écrit le fichier. Sur ordinateur le sélecteur renvoie un chemin que l'on
/// complète si le fichier est absent ou vide ; sur mobile et le web, le sélecteur enregistre lui-même les octets.
/// Renvoie l'emplacement choisi, ou `null` si l'utilisateur a annulé.
Future<Uri?> saveExportedFile({required String dialogTitle, required String fileName, required Uint8List bytes}) async {
  final uri = await FilePicker.saveFile(dialogTitle: dialogTitle, fileName: fileName, bytes: bytes);
  if (uri != null && uri.scheme == 'file') {
    final f = File(uri.toFilePath());
    if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
  }
  return uri;
}
