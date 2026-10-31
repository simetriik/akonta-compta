import 'package:akonta/src/application/entries/entry_editor_logic.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/domain/suggestion_models.dart';
import 'package:flutter_test/flutter_test.dart';

Account account(String id, String code, {bool collective = false}) =>
    Account(id: id, code: code, label: 'Compte $code', classNo: int.parse(code[0]), normalSide: 'debit', isCollective: collective, isLetterable: collective, allowPosting: true, isActive: true);

void main() {
  group('contrôles avant enregistrement', () {
    test('un brouillard exige journal, libellé et un compte sur chaque ligne saisie', () {
      final d = EntryDraft(lines: [DraftLine(debit: 10), DraftLine()]);
      expect(EntryEditorLogic.errors(d, validate: false), ['Journal requis', 'Libellé requis', 'Chaque ligne saisie doit avoir un compte']);
      d
        ..journalId = 'j'
        ..label = 'Loyer'
        ..lines.first.accountId = 'a';
      expect(EntryEditorLogic.errors(d, validate: false), isEmpty);
    });

    test('la validation applique tous les contrôles de l\'écriture', () {
      final d = EntryDraft(journalId: 'j', label: 'Loyer', lines: [DraftLine(accountId: 'a', debit: 10)]);
      expect(EntryEditorLogic.errors(d, validate: true), contains('Au moins deux lignes'));
    });

    test('hasContent : une grille vide ne demande pas de confirmation', () {
      expect(EntryEditorLogic.hasContent(EntryDraft(lines: [DraftLine(), DraftLine()])), isFalse);
      expect(EntryEditorLogic.hasContent(EntryDraft(lines: [DraftLine(credit: 5)])), isTrue);
      expect(EntryEditorLogic.hasContent(EntryDraft(lines: [DraftLine(accountId: 'a')])), isTrue);
    });
  });

  group('taux en vigueur', () {
    final rates = [
      TaxRate(id: '1', code: 'TVA', label: 'TVA', rate: 0.18, validFrom: DateTime(2020), validTo: DateTime(2023, 12, 31)),
      TaxRate(id: '2', code: 'TVA', label: 'TVA', rate: 0.19, validFrom: DateTime(2024)),
    ];

    test('choisit le taux dont la période couvre la date, bornes comprises', () {
      expect(EntryEditorLogic.rateOn(rates, 'TVA', DateTime(2023, 12, 31)), 0.18);
      expect(EntryEditorLogic.rateOn(rates, 'TVA', DateTime(2024)), 0.19);
      expect(EntryEditorLogic.rateOn(rates, 'TVA', DateTime(2019)), isNull);
      expect(EntryEditorLogic.rateOn(rates, 'AIB', DateTime(2024)), isNull);
    });
  });

  group('application d\'un modèle', () {
    final accounts = [account('a6', '6011000'), account('a4', '4011000', collective: true), account('a5', '5211000')];
    const template = EntryTemplate(
      id: 't',
      code: 'ACHAT',
      label: 'Achat de marchandises',
      isCabinetLevel: true,
      lines: [
        TemplateLine(lineNo: 1, accountCode: '6011', usesThirdParty: false, side: 'debit', formula: 'input'),
        TemplateLine(lineNo: 2, accountCode: '4011', usesThirdParty: true, side: 'credit', formula: 'balance'),
      ],
    );

    test('remplace les lignes, complète le numéro de compte et termine par une ligne vide', () {
      final d = EntryDraft(lines: [DraftLine(accountId: 'x', debit: 99)]);
      EntryEditorLogic.applyTemplateTo(d, template, baseAmount: 1000, accounts: accounts, rates: const [], today: DateTime(2026, 5, 1));
      expect(d.lines.length, 3);
      expect(d.lines[0].accountId, 'a6');
      expect(d.lines[0].debit, 1000);
      expect(d.lines[1].accountId, 'a4');
      expect(d.lines[1].credit, 1000);
      expect(d.lines[2].accountId, isNull);
    });
  });

  group('suggestions', () {
    final accounts = [account('a6', '6011000'), account('a4', '4011000', collective: true)];

    test('la reprise d\'une écriture passée copie comptes et tiers sans montants', () {
      final d = EntryDraft(lines: [DraftLine(accountId: 'old', debit: 5)]);
      final s = EntrySuggestion(
        entryId: 'e',
        entryDate: DateTime(2026, 1, 5),
        journalCode: 'AC',
        label: 'Achat',
        similarity: 0.8,
        lines: const [
          SuggestedLine(accountId: 'a6', accountCode: '6011000', accountLabel: 'Achats', side: 'debit', label: 'Achat'),
          SuggestedLine(accountId: 'a4', accountCode: '4011000', accountLabel: 'Fournisseurs', side: 'credit', thirdPartyId: 't1', thirdPartyCode: 'FOU1'),
        ],
      );
      EntryEditorLogic.useSuggestedEntry(d, s, accounts);
      expect(d.lines.length, 3);
      expect(d.lines[0].debit, 0);
      expect(d.lines[0].label, 'Achat');
      expect(d.lines[1].isCollective, isTrue);
      expect(d.lines[1].thirdPartyCode, 'FOU1');
    });

    test('le compte proposé va sur la première ligne sans compte, sinon sur une nouvelle ligne', () {
      const s = AccountSuggestion(accountId: 'a6', accountCode: '6011000', accountLabel: 'Achats', source: 'history', uses: 3);
      final d = EntryDraft(lines: [DraftLine(accountId: 'a4'), DraftLine()]);
      EntryEditorLogic.useSuggestedAccount(d, s, accounts);
      expect(d.lines[1].accountId, 'a6');
      expect(d.lines.length, 2);

      final full = EntryDraft(lines: [DraftLine(accountId: 'a4'), DraftLine(accountId: 'a4')]);
      EntryEditorLogic.useSuggestedAccount(full, s, accounts);
      expect(full.lines.length, 3);
      expect(full.lines.last.accountId, 'a6');
    });
  });

  test('une nouvelle ligne propose la contrepartie du déséquilibre', () {
    final d = EntryDraft(lines: [DraftLine(accountId: 'a', debit: 300), DraftLine(accountId: 'b', credit: 100)]);
    final line = EntryEditorLogic.appendLine(d);
    expect((line.debit, line.credit), (0, 200));
    expect(d.lines.length, 3);
    final e = EntryDraft(lines: [DraftLine(accountId: 'a', credit: 50)]);
    expect(EntryEditorLogic.appendLine(e).debit, 50);
  });
}
