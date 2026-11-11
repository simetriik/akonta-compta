import 'package:akonta/src/application/offline/outbox_codec.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/infrastructure/supabase/mappers/entry_models_mappers.dart';
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

    test('une contrepartie sur une ligne sans compte équilibre mais bloque la validation', () {
      final d = EntryDraft(journalId: 'j', label: 'Achat', lines: [
        DraftLine(accountId: 'a1', accountCode: '6011000', debit: 5000),
        DraftLine(),
      ]);
      d.autoBalance();
      expect(d.balance, 0);
      expect(d.hasLineWithoutAccount, isTrue);
      expect(d.validationErrors(), contains('Ligne 2 : Compte requis'));
      d.lines[1].accountId = 'a2';
      expect(d.hasLineWithoutAccount, isFalse);
      expect(d.validationErrors(), isEmpty);
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

  group('réouverture d\'un brouillard (tiers oublié)', () {
    // Ligne d'une écriture lue sur le serveur : le compte collectif porte `is_collective`.
    Map<String, dynamic> serverLine({required bool collective}) => {
          'id': 'l1',
          'line_no': 1,
          'account_id': 'a1',
          'accounts': {'code': '4111000', 'label': 'Clients', 'is_collective': collective},
          'third_party_id': null,
          'third_parties': null,
          'label': null,
          'debit': 1000,
          'credit': 0,
        };

    EntryModel entryWith(List<EntryLineModel> lines) => EntryModel(
          id: 'e1',
          entityId: 'ent',
          journalId: 'j',
          journalCode: 'VT',
          entryDate: DateTime(2026, 11, 3),
          label: 'Facture',
          status: 'draft',
          reviewStatus: 'not_reviewed',
          isGenerated: false,
          lines: lines,
        );

    test('la lecture serveur reprend l\'indicateur collectif du compte', () {
      expect(entryLineModelFromJson(serverLine(collective: true)).isCollective, isTrue);
      expect(entryLineModelFromJson(serverLine(collective: false)).isCollective, isFalse);
    });

    test('rouvert, le brouillard garde le champ Tiers et signale le tiers manquant par sa ligne', () {
      final entry = entryWith([entryLineModelFromJson(serverLine(collective: true))]);
      final draft = EntryDraft.fromEntry(entry);
      expect(draft.lines.single.isCollective, isTrue);
      expect(draft.validationErrors(), contains('Ligne 1 : Tiers requis sur un compte collectif'));
      draft.lines.single
        ..thirdPartyId = 't1'
        ..thirdPartyCode = 'CHU';
      expect(draft.validationErrors().where((e) => e.contains('Tiers')), isEmpty);
    });

    test('un brouillard conservé hors connexion garde aussi l\'indicateur collectif', () {
      final draft = EntryDraft(journalId: 'j', label: 'Facture', lines: [
        DraftLine(accountId: 'a1', accountCode: '4111000', isCollective: true, debit: 1000),
        DraftLine(accountId: 'a2', accountCode: '7011000', credit: 1000),
      ]);
      final payload = encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft);
      final read = localDraftAsEntry(1, payload);
      expect(read.lines.map((l) => l.isCollective), [true, false]);
      expect(EntryDraft.fromEntry(read).lines.first.isCollective, isTrue);
    });

    test('journal de banque : la contrepartie automatique propose le compte de trésorerie du journal (AN-10)', () {
      final d = EntryDraft(journalId: 'bq', label: 'Loyer', lines: [DraftLine(accountId: 'a62', accountCode: '6221000', debit: 250000), DraftLine()]);
      d.treasuryAccount = (id: 'a52', code: '5210000');
      d.autoBalance();
      expect((d.lines[1].accountCode, d.lines[1].credit, d.isBalanced), ('5210000', 250000, true));
    });

    test('sans journal de trésorerie, la contrepartie ne choisit pas de compte', () {
      final d = EntryDraft(journalId: 'od', label: 'OD', lines: [DraftLine(accountId: 'a62', accountCode: '6221000', debit: 100), DraftLine()]);
      d.autoBalance();
      expect((d.lines[1].accountId, d.lines[1].credit), (null, 100));
    });
  });
}
