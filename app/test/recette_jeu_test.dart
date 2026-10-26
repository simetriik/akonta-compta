import 'dart:convert';
import 'dart:io';

import 'package:akonta/src/data/import_repository.dart';
import 'package:akonta/src/domain/bank_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jeu de données de la recette interne (`recette/`, généré par `recette/generer-jeu.py`) : fichiers lisibles par l'application.
void main() {
  final root = Directory('../recette');

  test('export Perfecto simulé : cp1252, CRLF, tabulations, en-têtes et totaux du vrai format', () {
    final bytes = File('${root.path}/export-perfecto-simule.txt').readAsBytesSync();
    expect(() => utf8.decode(bytes), throwsA(isA<FormatException>()), reason: 'doit être en Windows-1252, pas en UTF-8');
    final text = decodePerfectoText(bytes);
    final lines = text.split('\r\n');
    expect(lines[0], startsWith('JOURNAL <AN> '));
    expect(lines[1], matches(RegExp(r'^Pièces du \d{2}/\d{2}/\d{4}  au \d{2}/\d{2}/\d{4}\t\t$')));
    expect(lines[3].split('\t'), ['Date', 'N° pièce', 'Compte', 'Intitulé', 'Débit', 'Crédit', 'Libellé']);
    final data = lines.where((l) => RegExp(r'^\d{2}/\d{2}/\d{4}\t').hasMatch(l)).map((l) => l.split('\t')).toList();
    expect(data, isNotEmpty);
    expect(data.every((c) => c.length == 7), isTrue);
    expect(data.any((c) => RegExp(r'^\d{4}[A-Z]+$').hasMatch(c[2])), isTrue, reason: 'comptes de tiers collés (ex. 4111CBM)');
    final debit = data.fold<int>(0, (s, c) => s + int.parse(c[4]));
    final credit = data.fold<int>(0, (s, c) => s + int.parse(c[5]));
    expect(debit, credit, reason: 'à-nouveaux équilibrés');
    expect(lines.any((l) => l.startsWith('Sous-total\t')), isTrue);
    expect(lines.any((l) => l.startsWith('Total\tJournal\t')), isTrue);
  });

  test('le test pgTAP embarque exactement le fichier courant (régénérer avec recette/generer-jeu.py sinon)', () {
    final sha = sha256.convert(File('${root.path}/export-perfecto-simule.txt').readAsBytesSync()).toString();
    final sql = File('../supabase/tests/150_recette_import.test.sql').readAsStringSync();
    expect(sql, contains('source-sha256: $sha'));
  });

  test('relevé Ecobank : lu sans erreur avec le gabarit documenté, équilibre avec le solde final', () {
    const t = StatementTemplate(
      bankName: 'Ecobank',
      label: 'Export CSV',
      dateColumn: 1,
      valueDateColumn: 2,
      labelColumn: 3,
      debitColumn: 4,
      creditColumn: 5,
      referenceColumn: 6,
    );
    final r = parseStatementCsv(File('${root.path}/releve-ecobank-janvier.csv').readAsStringSync(), t);
    expect(r.errors, isEmpty);
    expect(r.lines.length, 15);
    expect(r.lines.every((l) => l.debit == 0 || l.credit == 0), isTrue);
    expect(r.lines.where((l) => l.reference == '99812').single.credit, 120000);
  });

  test('pièces justificatives : PDF et JPEG valides', () {
    final files = Directory('${root.path}/pieces').listSync().whereType<File>().toList();
    expect(files.length, greaterThanOrEqualTo(10));
    for (final f in files) {
      final b = f.readAsBytesSync();
      if (f.path.endsWith('.pdf')) {
        expect(String.fromCharCodes(b.take(5)), '%PDF-');
      } else {
        expect(b.take(3).toList(), [0xFF, 0xD8, 0xFF]);
      }
    }
  });
}
