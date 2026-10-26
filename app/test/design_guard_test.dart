import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou du système de design : hors de `lib/design/`, aucun widget brut de saisie, de bouton, de liste
/// déroulante, de dialogue ou de tableau Material, aucune taille de texte inférieure à 14 px, aucune couleur codée en dur.
void main() {
  final files = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart') && !f.path.replaceAll('\\', '/').startsWith('lib/design/')) f,
  ];

  String code(File f) => f.readAsStringSync().split('\n').map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      }).join('\n');

  final rawWidgets = RegExp(
    r'\b(TextField|TextFormField|ElevatedButton|FilledButton|OutlinedButton|TextButton|IconButton|DropdownButton|DropdownButtonFormField|DropdownMenu|'
    r'AlertDialog|SimpleDialog|DataTable|Checkbox|CheckboxListTile|Switch|SwitchListTile|SegmentedButton|Autocomplete|RawAutocomplete|Card|showDatePicker)\b(?!\.)',
  );

  test('aucun widget brut Material hors de lib/design/', () {
    final offenders = <String>[];
    for (final f in files) {
      final lines = code(f).split('\n');
      for (var i = 0; i < lines.length; i++) {
        final m = rawWidgets.firstMatch(lines[i]);
        if (m != null) offenders.add('${f.path}:${i + 1} ${m[0]}');
      }
    }
    expect(offenders, isEmpty, reason: 'Utiliser les composants de lib/design/ :\n${offenders.join('\n')}');
  });

  test('aucune taille de texte inférieure à 14 px hors de lib/design/', () {
    final small = RegExp(r'fontSize:\s*(\d+(\.\d+)?)');
    final offenders = <String>[];
    for (final f in files) {
      final lines = code(f).split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final m in small.allMatches(lines[i])) {
          if (double.parse(m[1]!) < 14) offenders.add('${f.path}:${i + 1} fontSize ${m[1]}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('aucune couleur codée en dur hors de lib/design/', () {
    final raw = RegExp(r'\bColor\(0x|Colors\.(?!transparent\b|black\b|white\b)[a-z]');
    final offenders = <String>[];
    for (final f in files) {
      final lines = code(f).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (raw.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Utiliser context.ak :\n${offenders.join('\n')}');
  });
}
