import 'package:akonta/src/application/rules/closing_check_text.dart';
import 'package:akonta/src/core/formatting.dart';
import 'package:akonta/src/domain/closing_models.dart';
import 'package:flutter_test/flutter_test.dart';

ClosingCheck _check(String code, {String severity = 'blocking', String status = 'failed', Map<String, dynamic> details = const {}}) =>
    ClosingCheck(code: code, label: code, severity: severity, status: status, details: details);

void main() {
  group('phrase de résultat', () {
    test('un nombre d\'écritures prend le singulier ou le pluriel', () {
      expect(ClosingCheckText.summary(_check('drafts_pending', details: {'count': 1})), '1 écriture en brouillard');
      expect(ClosingCheckText.summary(_check('drafts_pending', details: {'count': 28})), '28 écritures en brouillard');
      expect(ClosingCheckText.summary(_check('to_correct', severity: 'warning', details: {'count': 2})), '2 écritures à corriger');
    });

    test('l\'équilibre du grand livre affiche des montants formatés et l\'écart', () {
      final text = ClosingCheckText.summary(_check('unbalanced', details: {'debit': 245737000, 'credit': 245000000}))!;
      expect(text, contains(Fmt.fcfa(245737000)));
      expect(text, contains('écart ${Fmt.fcfa(737000)}'));
      expect(text, isNot(contains('debit')));
    });

    test('les listes de comptes ou de journaux sont nommées, sans crochets', () {
      expect(ClosingCheckText.summary(_check('reconciliations', severity: 'warning', details: {'journals': ['BQ']})), 'Journal sans état figé : BQ');
      expect(ClosingCheckText.summary(_check('inactive_accounts', details: {'accounts': ['6011000', '6012000']})), 'Comptes désactivés mouvementés : 6011000, 6012000');
    });

    test('aucune clé technique n\'apparaît dans la ligne affichée', () {
      for (final c in [
        _check('drafts_pending', details: {'count': 28}),
        _check('suspense_471', details: {'balance': 0}),
        _check('inactive_accounts', status: 'passed', details: {'accounts': []}),
        _check('unbalanced', status: 'passed', details: {'debit': 10, 'credit': 10}),
      ]) {
        final line = ClosingCheckText.subtitle(c);
        expect(line, isNot(matches(RegExp(r'count|accounts|balance|debit|credit|journals|\[\]'))), reason: line);
      }
    });

    test('un contrôle conforme n\'ajoute aucun détail', () {
      expect(ClosingCheckText.summary(_check('drafts_pending', status: 'passed', details: {'count': 0})), isNull);
    });

    test('le solde restant du compte d\'attente est signé D ou C', () {
      expect(ClosingCheckText.summary(_check('suspense_471', details: {'balance': 150000})), 'Solde restant : ${Fmt.balance(150000)}');
      expect(ClosingCheckText.summary(_check('suspense_471', details: {'balance': -150000})), 'Solde restant : ${Fmt.balance(-150000)}');
    });
  });

  group('état en phrase', () {
    test('bloquant en échec', () => expect(ClosingCheckText.state(_check('x')), 'À corriger avant la clôture'));
    test('alerte en échec', () => expect(ClosingCheckText.state(_check('x', severity: 'warning')), startsWith('Alerte')));
    test('alerte levée', () => expect(ClosingCheckText.state(_check('x', severity: 'warning', status: 'waived')), contains('levée')));
  });

  group('lien vers la correction', () {
    test('chaque contrôle corrigeable a une destination', () {
      expect(ClosingCheckText.action(_check('drafts_pending'))?.target, ClosingCheckTarget.draftEntries);
      expect(ClosingCheckText.action(_check('to_correct', severity: 'warning'))?.target, ClosingCheckTarget.entriesToCorrect);
      expect(ClosingCheckText.action(_check('unreviewed', severity: 'warning'))?.target, ClosingCheckTarget.entriesToReview);
      expect(ClosingCheckText.action(_check('unlocked_periods', severity: 'warning'))?.target, ClosingCheckTarget.periods);
      expect(ClosingCheckText.action(_check('reconciliations', severity: 'warning'))?.target, ClosingCheckTarget.reconciliation);
      expect(ClosingCheckText.action(_check('depreciation', severity: 'warning'))?.target, ClosingCheckTarget.inventory);
    });

    test('pas de lien quand le contrôle est conforme, levé ou sans destination', () {
      expect(ClosingCheckText.action(_check('drafts_pending', status: 'passed')), isNull);
      expect(ClosingCheckText.action(_check('to_correct', severity: 'warning', status: 'waived')), isNull);
      expect(ClosingCheckText.action(_check('unbalanced')), isNull);
    });
  });
}
