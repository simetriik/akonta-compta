import 'dart:typed_data';

import 'package:akonta/src/data/import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('décode un export Perfecto en Windows-1252 (accents, œ, euro)', () {
    final bytes = Uint8List.fromList([0x50, 0x69, 0xE8, 0x63, 0x65, 0x73, 0x20, 0x42, 0xE9, 0x6E, 0x69, 0x6E, 0x20, 0x9C, 0x20, 0x80]);
    expect(decodeWindows1252(bytes), 'Pièces Bénin œ €');
    expect(decodePerfectoText(bytes), 'Pièces Bénin œ €');
  });

  test('laisse passer un fichier déjà en UTF-8', () {
    final bytes = Uint8List.fromList('Pièces Bénin'.codeUnits.length == 12 ? utf8Bytes('Pièces Bénin') : []);
    expect(decodePerfectoText(bytes), 'Pièces Bénin');
  });
}

List<int> utf8Bytes(String s) => s.runes.expand((r) {
      if (r < 0x80) return [r];
      return [0xC0 | (r >> 6), 0x80 | (r & 0x3F)];
    }).toList();
