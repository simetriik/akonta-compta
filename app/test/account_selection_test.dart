import 'package:akonta/src/application/rules/account_selection.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

Account acc(String code, {bool posting = true, bool active = true, bool collective = false, String label = 'Compte'}) => Account(
  id: 'id$code',
  code: code,
  label: label,
  classNo: int.parse(code[0]),
  normalSide: 'debit',
  isCollective: collective,
  isLetterable: collective,
  allowPosting: posting,
  isActive: active,
);

List<String> codes(List<Account> l) => l.map((a) => a.code).toList();

void main() {
  final plan = [
    acc('2441000'), acc('2841000'), acc('2941000'), acc('2400000', posting: false), acc('2450000', active: false),
    acc('3110000'), acc('3910000'), acc('6031000'), acc('7340000'), acc('6050000'),
    acc('4852000'), acc('4111000', collective: true), acc('4011000', collective: true), acc('4081000'), acc('4760000'),
    acc('5211000'), acc('5710000'), acc('5310000', active: false), acc('6011000'), acc('7011000'),
  ];

  test('immobilisations : classe 2 imputable et active, sans amortissements ni dépréciations', () {
    expect(codes(AccountSelection.fixedAssets(plan)), ['2441000']);
  });

  test('stocks : classe 3 sans dépréciations ; variation : 603 et 73', () {
    expect(codes(AccountSelection.stocks(plan)), ['3110000']);
    expect(codes(AccountSelection.stockVariation(plan)), ['6031000', '7340000']);
  });

  test('contrepartie de cession : 485, trésorerie, clients', () {
    expect(codes(AccountSelection.disposalCounterparts(plan)), ['4852000', '4111000', '5211000', '5710000']);
  });

  test('trésorerie et comptes collectifs', () {
    expect(codes(AccountSelection.treasury(plan)), ['5211000', '5710000']);
    expect(codes(AccountSelection.collectives(plan)), ['4111000', '4011000']);
  });

  test('contreparties d\'un relevé : tout sauf la trésorerie', () {
    final result = AccountSelection.statementCounterparts(plan);
    expect(result.any((a) => a.classNo == 5), isFalse);
    expect(result.any((a) => !a.allowPosting || !a.isActive), isFalse);
  });

  test('régularisations : charges et produits, comptes de classe 4, préfixes par défaut', () {
    expect(codes(AccountSelection.accrualResults(plan)), ['6031000', '7340000', '6050000', '6011000', '7011000']);
    expect(codes(AccountSelection.accrualCounterparts(plan)), ['4852000', '4111000', '4011000', '4081000', '4760000']);
    expect([for (final k in ['cap', 'par', 'cca', 'autre']) AccountSelection.accrualDefaultPrefix(k)], ['408', '418', '476', '477']);
  });

  test('plan de comptes : filtre par classe, par début de numéro ou par intitulé', () {
    final p = [acc('4111000', label: 'Clients'), acc('4011000', label: 'Fournisseurs'), acc('5211000', label: 'Banque clients')];
    expect(codes(AccountSelection.filterPlan(p, classNo: 4)), ['4111000', '4011000']);
    expect(codes(AccountSelection.filterPlan(p, search: '41')), ['4111000']);
    expect(codes(AccountSelection.filterPlan(p, search: 'clients')), ['4111000', '5211000']);
    expect(codes(AccountSelection.filterPlan(p, search: 'clients', classNo: 5)), ['5211000']);
    expect(AccountSelection.filterPlan(p), hasLength(3));
  });
}
