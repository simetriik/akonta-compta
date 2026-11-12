import 'package:akonta/src/application/entries/entry_editor_logic.dart';
import 'package:akonta/src/application/rules/template_builder.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('« Enregistrer comme modèle »', () {
    final draft = EntryDraft(
      label: 'Facture CHU',
      lines: [
        DraftLine(accountId: 'a1', accountCode: '4111000', accountLabel: 'Clients', isCollective: true, thirdPartyId: 't1', thirdPartyCode: 'CHU', label: 'Client TTC', debit: 1180),
        DraftLine(accountId: 'a2', accountCode: '7011000', accountLabel: 'Ventes', label: 'Vente HT', credit: 1000),
        DraftLine(accountId: 'a3', accountCode: '4431000', accountLabel: 'TVA facturée', credit: 180),
        DraftLine(),
      ],
    );

    test('les comptes deviennent génériques, le tiers devient une marque « tiers à choisir »', () {
      final lines = EntryEditorLogic.templateLinesFrom(draft);
      expect(lines.map((l) => l.accountCode), ['4111', '7011', '4431']);
      expect(lines.map((l) => l.usesThirdParty), [true, false, false]);
      expect(lines.map((l) => l.side), ['debit', 'credit', 'credit']);
      expect(lines.map((l) => l.lineNo), [1, 2, 3]);
      expect(lines.first.label, 'Client TTC');
    });

    test('le modèle enregistré recalcule l\'écriture sur un autre montant (montant libre)', () {
      final lines = EntryEditorLogic.templateLinesFrom(draft);
      final template = EntryTemplate(id: 'x', code: 'X', label: 'Facture CHU', isCabinetLevel: false, lines: lines);
      final result = applyTemplate(template, baseAmount: 500, rateOf: (_) => null, resolveAccount: (_) => null);
      expect(result.map((l) => l.debit + l.credit), [500, 500, 500]);
    });

    test('code proposé : valide, majuscules, unique', () {
      expect(TemplateBuilder.suggestCode('Facture CHU – vente', const []), 'FACTURE_CHU_VENTE');
      expect(TemplateBuilder.suggestCode('Facture CHU – vente', const ['FACTURE_CHU_VENTE']), 'FACTURE_CHU_VENTE2');
      expect(TemplateBuilder.suggestCode('é', const []), 'MODELE');
      expect(RegExp(r'^[A-Z0-9_]{2,20}$').hasMatch(TemplateBuilder.suggestCode('Une désignation très très longue pour un modèle', const [])), isTrue);
    });
  });

  group('compte générique résolu à l\'appel', () {
    test('le tiers choisi à l\'appel se place sur les lignes marquées « tiers »', () {
      const template = EntryTemplate(
        id: 't',
        code: 'VENTE',
        label: 'Vente',
        isCabinetLevel: true,
        lines: [
          TemplateLine(lineNo: 1, accountCode: '7011', usesThirdParty: false, side: 'credit', formula: 'input'),
          TemplateLine(lineNo: 2, accountCode: '4111', usesThirdParty: true, side: 'debit', formula: 'balance'),
        ],
      );
      const customers = Account(id: 'a411', code: '4111000', label: 'Clients', classNo: 4, normalSide: 'debit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true);
      final lines = applyTemplate(
        template,
        baseAmount: 1000,
        rateOf: (_) => null,
        resolveAccount: (c) => c == '4111' ? customers : null,
        thirdParty: const ThirdParty(id: 't-chu', code: 'CHU', name: 'CHU Cotonou', type: 'customer', isActive: true),
      );
      expect(lines[1].thirdPartyId, 't-chu');
      expect(lines[1].thirdPartyCode, 'CHU');
      expect(lines[0].thirdPartyId, isNull, reason: 'seule une ligne marquée « tiers » reçoit le tiers');
    });
  });

  group('droits', () {
    test('« senior » se lit sur au moins une affectation', () {
      const manager = PermissionSet(byEntity: {'e1': {'templates.manage_common'}}, cabinetWide: {}, roles: []);
      expect(manager.hasAnywhere('templates.manage_common'), isTrue);
      expect(manager.hasAnywhere('templates.manage_entity'), isFalse);
      expect(PermissionSet.empty.hasAnywhere('templates.manage_common'), isFalse);
      const partner = PermissionSet(byEntity: {}, cabinetWide: {'templates.manage_common'}, roles: []);
      expect(partner.hasAnywhere('templates.manage_common'), isTrue);
    });
  });
}
