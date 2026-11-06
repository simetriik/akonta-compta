import 'package:akonta/design/design.dart';
import 'package:akonta/src/domain/consultation_models.dart';
import 'package:akonta/src/infrastructure/supabase/mappers/consultation_repository_mappers.dart';
import 'package:akonta/src/presentation/consultation/ledger_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

LedgerLine _line({List<Counterpart> cp = const [], String? name, String? code}) => LedgerLine(
  accountCode: '4011000',
  accountLabel: 'Fournisseurs',
  entryId: 'x',
  entryDate: DateTime(2026, 3, 10),
  journalCode: 'OD',
  number: 1,
  label: 'OD 1',
  thirdPartyCode: code,
  thirdPartyName: name,
  debit: 0,
  credit: 1180,
  runningBalance: -1180,
  counterparts: cp,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  const achats = Counterpart(code: '6011000', label: 'Achats', amount: 1000);
  const tva = Counterpart(code: '4452000', label: 'TVA récupérable', amount: 180);

  test('contrepartie : principale seule, ou principale suivie de « + n »', () {
    expect(_line().counterpartText, '');
    expect(_line(cp: [achats]).counterpartText, '6011000');
    expect(_line(cp: [achats, tva]).counterpartText, '6011000 + 1');
    expect(_line(cp: [achats, tva]).counterpartDetail, '6011000 Achats\n4452000 TVA récupérable');
  });

  test('tiers : le nom d\'abord, jamais un numéro de compte', () {
    expect(_line(name: 'NSIA Assurances', code: 'NSIA').thirdPartyText, 'NSIA Assurances');
    expect(_line(code: 'NSIA').thirdPartyText, 'NSIA');
    expect(_line().thirdPartyText, '');
  });

  test('la réponse de la base est lue, liste complète comprise', () {
    final line = ledgerLineFromJson({
      'account_code': '4011000',
      'account_label': 'Fournisseurs',
      'entry_id': 'x',
      'entry_date': '2026-03-10',
      'journal_code': 'OD',
      'number': 1,
      'label': 'OD 1',
      'third_party_code': 'NSIA',
      'third_party_name': 'NSIA Assurances',
      'debit': 0,
      'credit': 1180,
      'running_balance': -1180,
      'counterparts': [
        {'code': '6011000', 'label': 'Achats', 'amount': 1000},
        {'code': '4452000', 'label': 'TVA récupérable', 'amount': 180},
      ],
    });
    expect(line.counterpartText, '6011000 + 1');
    expect(line.thirdPartyText, 'NSIA Assurances');
  });

  testWidgets('le grand livre affiche les colonnes Tiers (nom) et Contrepartie', (tester) async {
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkontaTheme(),
        home: Scaffold(
          body: SizedBox(height: 600, child: LedgerGrid(items: [LedgerRowLine(_line(name: 'NSIA Assurances', code: 'NSIA', cp: [achats, tva]))])),
        ),
      ),
    );
    expect(find.text('Contrepartie'), findsOneWidget);
    expect(find.text('6011000 + 1'), findsOneWidget);
    expect(find.text('NSIA Assurances'), findsOneWidget);
  });
}
