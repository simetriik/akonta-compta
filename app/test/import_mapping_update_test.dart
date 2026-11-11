import 'package:akonta/src/infrastructure/supabase/supabase_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recette 09/11/2026 (AN-07) : modifier une cellule de la table de correspondance de l'import ne doit pas
/// effacer les autres colonnes de la ligne.
void main() {
  test('modifier le compte n\'envoie que le compte', () {
    expect(mappingUpdatePayload(accountCode: ' 4111000 '), {'account_code': '4111000'});
  });

  test('modifier le code tiers n\'envoie que le tiers, en majuscules', () {
    expect(mappingUpdatePayload(thirdPartyCode: 'cdx'), {'third_party_code': 'CDX'});
  });

  test('un champ vidé volontairement est remis à null', () {
    expect(mappingUpdatePayload(thirdPartyName: '  '), {'third_party_name': null});
  });

  test('la case « créer le tiers » n\'efface rien d\'autre', () {
    expect(mappingUpdatePayload(createThirdParty: true), {'create_third_party': true});
  });

  test('aucun champ fourni : rien à écrire', () {
    expect(mappingUpdatePayload(), isEmpty);
  });
}
