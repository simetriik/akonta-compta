import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou de la gestion des erreurs : un écran n'affiche jamais une exception telle quelle (elle contiendrait le vocabulaire de
/// la base de données). Tout passe par `errorText`, `showError` ou `humanizeError` (lib/src/core/errors).
void main() {
  final files = [
    for (final f in Directory('lib/src').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart') && !f.path.replaceAll('\\', '/').startsWith('lib/src/core/errors/')) f,
  ];

  String code(File f) => f.readAsStringSync().split('\n').map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      }).join('\n');

  List<String> scan(RegExp pattern, {bool presentationOnly = false}) {
    final offenders = <String>[];
    for (final f in files) {
      if (presentationOnly && !f.path.replaceAll('\\', '/').startsWith('lib/src/presentation/')) continue;
      final lines = code(f).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
    return offenders;
  }

  test('aucune exception n\'est interpolée dans un texte d\'écran', () {
    final interpolation = RegExp(r'\$(e|err|ex|error|exception)(?![A-Za-z0-9_.])|\$\{(e|err|ex|error|exception)\}');
    expect(scan(interpolation, presentationOnly: true), isEmpty, reason: 'Utiliser errorText(e) ou showError(context, e) (lib/src/core/errors) :');
  });

  test('aucun affichage direct du texte d\'une exception', () {
    final direct = RegExp(r'\b(e|err|ex|error|exception)\.(toString\(\)|message)\b');
    expect(scan(direct, presentationOnly: true), isEmpty, reason: 'Utiliser errorText(e) ou showError(context, e) :');
  });

  test('les anciens traducteurs d\'erreurs ont disparu', () {
    final old = RegExp(r"frenchRpcError|frenchEntryError|_frenchDbError|_frenchAuthError|RegExp\(r'message: ");
    expect(scan(old), isEmpty, reason: 'Un seul traducteur : humanizeError / errorText.');
  });
}
