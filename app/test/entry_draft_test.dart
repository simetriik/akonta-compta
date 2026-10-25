import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntryDraft', () {
    test('équilibre, contrepartie automatique et contrôles de ligne', () {
      final d = EntryDraft(journalId: 'j', label: 'Facture', lines: [
        DraftLine(accountId: 'a1', accountCode: '4111000', isCollective: true, thirdPartyId: 't', debit: 1180000),
        DraftLine(accountId: 'a2', accountCode: '7011000', credit: 1000000),
        DraftLine(),
      ]);
      expect(d.isBalanced, isFalse);
      expect(d.balance, 180000);
      d.autoBalance();
      expect(d.lines[2].credit, 180000);
      expect(d.balance, 0);
      d.lines[2].accountId = 'a3';
      expect(d.validationErrors(), isEmpty);
    });

    test('refuse un montant négatif, débit et crédit simultanés, tiers manquant', () {
      expect(DraftLine(accountId: 'a', debit: -5).validate(), contains('négatif'));
      expect(DraftLine(accountId: 'a', debit: 5, credit: 5).validate(), contains('pas les deux'));
      expect(DraftLine(accountId: 'a').validate(), contains('positif'));
      expect(DraftLine(accountId: 'a', isCollective: true, debit: 5).validate(), contains('Tiers'));
      expect(DraftLine().validate(), 'Compte requis');
    });

    test('exige deux lignes et un libellé', () {
      final d = EntryDraft(journalId: 'j', lines: [DraftLine(accountId: 'a', debit: 10)]);
      final errors = d.validationErrors();
      expect(errors, contains('Libellé requis'));
      expect(errors, contains('Au moins deux lignes'));
    });
  });

  group('applyTemplate', () {
    final accounts = {
      '6011': const Account(id: 'a6011', code: '6011000', label: 'Achats', classNo: 6, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true),
      '4452': const Account(id: 'a4452', code: '4452000', label: 'TVA récupérable', classNo: 4, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true),
      '4011': const Account(id: 'a4011', code: '4011000', label: 'Fournisseurs', classNo: 4, normalSide: 'credit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true),
    };
    const template = EntryTemplate(id: 't', code: 'ACHAT_TVA', label: 'Achat avec TVA', isCabinetLevel: true, lines: [
      TemplateLine(lineNo: 1, accountCode: '6011', usesThirdParty: false, side: 'debit', formula: 'input', label: 'Achat HT'),
      TemplateLine(lineNo: 2, accountCode: '4452', usesThirdParty: false, side: 'debit', formula: 'percent_of', refLineNo: 1, taxRateCode: 'TVA'),
      TemplateLine(lineNo: 3, accountCode: '4011', usesThirdParty: true, side: 'credit', formula: 'balance'),
    ]);

    test('achat avec TVA 18 % : HT, TVA, fournisseur TTC', () {
      final lines = applyTemplate(template, baseAmount: 1000000, rateOf: (c) => c == 'TVA' ? 0.18 : null, resolveAccount: (c) => accounts[c]);
      expect(lines.map((l) => l.debit).toList(), [1000000, 180000, 0]);
      expect(lines[2].credit, 1180000);
      expect(lines[2].isCollective, isTrue);
      expect(lines[2].accountCode, '4011000');
      final d = EntryDraft(journalId: 'j', label: 'x', lines: lines);
      expect(d.balance, 0);
    });

    test('arrondi à l\'unité du pourcentage', () {
      final lines = applyTemplate(template, baseAmount: 58475, rateOf: (_) => 0.18, resolveAccount: (c) => accounts[c]);
      expect(lines[1].debit, 10526); // 10525.5 → 10526
      expect(lines[2].credit, 69001);
    });
  });
}
