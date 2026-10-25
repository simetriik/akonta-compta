import 'dart:typed_data';

import 'package:akonta/src/data/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('types admis déduits de l\'extension', () {
    expect(mimeTypeFor('facture.PDF'), 'application/pdf');
    expect(mimeTypeFor('photo.jpeg'), 'image/jpeg');
    expect(mimeTypeFor('scan.heic'), 'image/heic');
    expect(mimeTypeFor('contrat.docx'), isNull);
  });

  test('empreinte SHA-256 hexadécimale', () {
    expect(sha256Hex(Uint8List.fromList('abc'.codeUnits)), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(maxDocumentBytes, 20 * 1024 * 1024);
  });
}
