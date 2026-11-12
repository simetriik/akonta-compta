import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/third_party_type.dart';

void main() {
  test('le collectif donne le type du tiers : 401 fournisseur, 411 client, 422 personnel, 4431 sans type imposé', () {
    expect(ThirdPartyType.forCollective('4011000'), 'supplier');
    expect(ThirdPartyType.forCollective('4111000'), 'customer');
    expect(ThirdPartyType.forCollective('4221000'), 'employee');
    expect(ThirdPartyType.forCollective('4431000'), isNull);
  });
}
