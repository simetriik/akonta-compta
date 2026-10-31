import 'package:akonta/src/application/rules/template_builder.dart';
import 'package:flutter_test/flutter_test.dart';

TemplateLineInput line({String account = '6011', String side = 'debit', String formula = 'input', String refLine = '1', String percent = '', String? rateCode, bool thirdParty = false, String label = ''}) =>
    TemplateLineInput(account: account, thirdParty: thirdParty, side: side, formula: formula, refLine: refLine, percent: percent, rateCode: rateCode, label: label);

void main() {
  test('code et libellé sont obligatoires', () {
    expect(TemplateBuilder.build(code: ' ', label: 'x', inputs: [line()]).error, 'Code et libellé requis');
    expect(TemplateBuilder.build(code: 'X', label: '', inputs: [line()]).error, 'Code et libellé requis');
  });

  test('un compte non numérique est refusé en indiquant la ligne', () {
    final r = TemplateBuilder.build(code: 'X', label: 'x', inputs: [line(), line(account: '60A1')]);
    expect(r.error, 'Ligne 2 : compte numérique requis');
    expect(TemplateBuilder.build(code: 'X', label: 'x', inputs: [line(account: '0123')]).error, isNotNull);
  });

  test('les lignes sont numérotées et les champs de pourcentage ne comptent que pour percent_of', () {
    final r = TemplateBuilder.build(
      code: 'ACHAT',
      label: 'Achat',
      inputs: [
        line(account: ' 6011 ', percent: '18', rateCode: 'TVA', label: ' Achat '),
        line(account: '4452', formula: 'percent_of', refLine: '1', rateCode: 'TVA', percent: '18'),
        line(account: '4081', side: 'credit', formula: 'percent_of', refLine: '1', percent: '2,5'),
        line(account: '4011', side: 'credit', formula: 'balance', thirdParty: true),
      ],
    );
    final l = r.lines!;
    expect(l.map((e) => e.lineNo), [1, 2, 3, 4]);
    expect(l[0].accountCode, '6011');
    expect((l[0].percent, l[0].taxRateCode, l[0].refLineNo, l[0].label), (null, null, null, 'Achat'));
    expect((l[1].taxRateCode, l[1].percent, l[1].refLineNo), ('TVA', null, 1));
    expect((l[2].percent, l[2].taxRateCode), (0.025, null));
    expect(l[3].usesThirdParty, isTrue);
  });
}
