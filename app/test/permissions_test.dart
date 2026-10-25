import 'package:akonta/src/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const partner = AssignedRole(roleId: 'r1', code: 'partner', name: 'Associé', entityId: null, requiresMfa: true, grantsAllEntities: true, accountingAccess: true);
  const assistant = AssignedRole(roleId: 'r2', code: 'assistant', name: 'Assistant', entityId: 'e1', requiresMfa: false, grantsAllEntities: false, accountingAccess: true);

  test('une permission de portée cabinet vaut pour tous les dossiers', () {
    const p = PermissionSet(byEntity: {}, cabinetWide: {'closing.final'}, roles: [partner]);
    expect(p.has('closing.final'), isTrue);
    expect(p.has('closing.final', entityId: 'e9'), isTrue);
    expect(p.requiresMfa, isTrue);
  });

  test('une permission de dossier ne vaut que pour ce dossier', () {
    const p = PermissionSet(byEntity: {'e1': {'entries.validate'}}, cabinetWide: {}, roles: [assistant]);
    expect(p.has('entries.validate', entityId: 'e1'), isTrue);
    expect(p.has('entries.validate', entityId: 'e2'), isFalse);
    expect(p.has('entries.validate'), isFalse);
    expect(p.requiresMfa, isFalse);
  });
}
