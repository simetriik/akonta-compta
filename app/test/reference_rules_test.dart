import 'package:akonta/src/domain/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complément du numéro de compte à la longueur fixe', () {
    expect(padAccountCode('4011', 7), '4011000');
    expect(padAccountCode('40111', 7), '4011100');
    expect(padAccountCode('4011000', 7), '4011000');
    expect(padAccountCode('40110001', 7), isNull, reason: 'trop long');
    expect(padAccountCode('0401', 7), isNull, reason: 'commence par zéro');
    expect(padAccountCode('40A1', 7), isNull, reason: 'non numérique');
  });

  test('codes de tiers et de journaux', () {
    expect(validateThirdPartyCode('CHU'), isNull);
    expect(validateThirdPartyCode('chu'), isNull, reason: 'mis en majuscules');
    expect(validateThirdPartyCode('C'), isNotNull);
    expect(validateThirdPartyCode('CHU-PARAKOU'), isNotNull);
    expect(validateJournalCode('BQ'), isNull);
    expect(validateJournalCode('BANQUE1'), isNotNull);
  });

  test('libellé de formule d\'un modèle', () {
    expect(const TemplateLine(lineNo: 2, accountCode: '4452', usesThirdParty: false, side: 'debit', formula: 'percent_of', refLineNo: 1, taxRateCode: 'TVA').formulaLabel, 'TVA de la ligne 1');
    expect(const TemplateLine(lineNo: 2, accountCode: '4452', usesThirdParty: false, side: 'debit', formula: 'percent_of', refLineNo: 1, percent: 0.05).formulaLabel, '5.00 % de la ligne 1');
    expect(const TemplateLine(lineNo: 3, accountCode: '4011', usesThirdParty: true, side: 'credit', formula: 'balance').formulaLabel, 'solde');
  });
}
