import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/partner_form.dart';

void main() {
  test('associé valide : nom nettoyé et part décimale à virgule', () {
    final r = PartnerForm.build(name: '  Moubarak  ', percent: '55,5', alreadyAllocated: 0);
    expect(r.error, isNull);
    expect((r.value!.name, r.value!.sharePercent), ('Moubarak', 55.5));
  });

  test('nom trop court, part nulle ou hors bornes : refusés', () {
    expect(PartnerForm.build(name: 'M', percent: '10', alreadyAllocated: 0).error, isNotNull);
    expect(PartnerForm.build(name: 'Moubarak', percent: '0', alreadyAllocated: 0).error, isNotNull);
    expect(PartnerForm.build(name: 'Moubarak', percent: '101', alreadyAllocated: 0).error, isNotNull);
    expect(PartnerForm.build(name: 'Moubarak', percent: 'abc', alreadyAllocated: 0).error, isNotNull);
  });

  test('le total des parts ne dépasse pas 100 %', () {
    expect(PartnerForm.build(name: 'Gwladys', percent: '30', alreadyAllocated: 55).error, isNull);
    expect(PartnerForm.build(name: 'Aline', percent: '20', alreadyAllocated: 85).error, contains('100'));
  });
}
