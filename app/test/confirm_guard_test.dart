import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou « messages » (cadrage, famille 6) : une suppression ou un retrait lancé depuis un écran est toujours
/// précédé d'une confirmation (`showAkConfirm`) dans les 40 lignes qui le précèdent.
void main() {
  test('aucune suppression ni retrait sans confirmation préalable', () {
    final call = RegExp(r'ref\.read\(\w+Provider\)\.(delete|remove)\w*\(');
    final offenders = <String>[];
    for (final f in Directory('lib/src/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!call.hasMatch(lines[i])) continue;
        final from = i < 40 ? 0 : i - 40;
        if (!lines.sublist(from, i).any((l) => l.contains('showAkConfirm'))) offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'Demander confirmation (showAkConfirm) avant toute suppression :');
  });
}
