import 'package:akonta/src/application/rules/asset_form.dart';
import 'package:flutter_test/flutter_test.dart';

AssetInput input({bool isNew = true, String? accountId = 'a2', String gross = '1 200 000', String months = '60', String method = 'linear', String coef = '', String acq = '15/03/2026'}) => AssetInput(
  code: 'VEH-01',
  designation: ' Camion ',
  accountId: accountId,
  acquisition: acq,
  service: '01/04/2026',
  gross: gross,
  salvage: '',
  months: months,
  method: method,
  coefficient: coef,
  prior: '',
  isNew: isNew,
);

void main() {
  test('une fiche complète donne les champs du serveur, dates au format ISO', () {
    final r = AssetForm.build(input());
    final f = r.fields!;
    expect(f['code'], 'VEH-01');
    expect(f['designation'], 'Camion');
    expect(f['asset_account_id'], 'a2');
    expect(f['acquisition_date'], '2026-03-15');
    expect(f['service_date'], '2026-04-01');
    expect(f['gross_value'], 1200000);
    expect((f['salvage_value'], f['prior_depreciation'], f['duration_months']), (0, 0, 60));
    expect(f['declining_coefficient'], isNull);
  });

  test('en modification, le code et le compte ne sont pas renvoyés ni exigés', () {
    final f = AssetForm.build(input(isNew: false, accountId: null)).fields!;
    expect(f.containsKey('code'), isFalse);
    expect(f.containsKey('asset_account_id'), isFalse);
  });

  test('refuse un compte manquant à la création, une valeur nulle, une durée nulle ou une date illisible', () {
    const message = 'Code, désignation, compte, dates, valeur brute et durée requis';
    expect(AssetForm.build(input(accountId: null)).error, message);
    expect(AssetForm.build(input(gross: '0')).error, message);
    expect(AssetForm.build(input(months: '0')).error, message);
    expect(AssetForm.build(input(months: 'abc')).error, message);
    expect(AssetForm.build(input(acq: '31/02/2026')).error, message);
  });

  test('dégressif : coefficient saisi avec virgule, sinon 1,5', () {
    expect(AssetForm.build(input(method: 'declining', coef: '2,25')).fields!['declining_coefficient'], 2.25);
    expect(AssetForm.build(input(method: 'declining')).fields!['declining_coefficient'], 1.5);
  });
}
