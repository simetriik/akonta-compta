import 'package:akonta/src/application/rules/notification_text.dart';
import 'package:akonta/src/application/rules/team_rules.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Assignment _a(String id, String user, String code, {String entity = 'e1'}) =>
    Assignment(id: id, userId: user, userName: user, roleId: code, roleName: code, roleCode: code, entityId: entity);

const _roles = [
  RoleDef(id: 'p', code: 'partner', name: 'Associé', isSystem: true, permissions: {}),
  RoleDef(id: 'm', code: 'manager', name: 'Chef', isSystem: true, permissions: {}),
  RoleDef(id: 'a', code: 'assistant', name: 'Assistant', isSystem: true, permissions: {}),
  RoleDef(id: 't', code: 'trainee', name: 'Stagiaire', isSystem: true, permissions: {}),
];

void main() {
  const partner = PermissionSet(byEntity: {}, cabinetWide: {'assignments.manage', 'team.assign'}, roles: []);
  const manager = PermissionSet(byEntity: {'e1': {'team.assign'}}, cabinetWide: {}, roles: []);
  const assistant = PermissionSet(byEntity: {'e1': {'entries.draft'}}, cabinetWide: {}, roles: []);

  group('droits sur l\'équipe', () {
    test('l\'associé gère tous les dossiers et choisit le chef de mission', () {
      expect(TeamRules.canManage(partner, 'e9'), isTrue);
      expect(TeamRules.canSetManager(partner), isTrue);
      expect(TeamRules.assignableRoles(partner, 'e9', _roles).map((r) => r.code), ['manager', 'assistant', 'trainee']);
    });

    test('le chef de mission gère son dossier seulement, assistants et stagiaires', () {
      expect(TeamRules.canManage(manager, 'e1'), isTrue);
      expect(TeamRules.canManage(manager, 'e2'), isFalse);
      expect(TeamRules.canSetManager(manager), isFalse);
      expect(TeamRules.assignableRoles(manager, 'e1', _roles).map((r) => r.code), ['assistant', 'trainee']);
      expect(TeamRules.assignableRoles(manager, 'e2', _roles), isEmpty);
    });

    test('un assistant ne gère rien', () {
      expect(TeamRules.canManage(assistant, 'e1'), isFalse);
      expect(TeamRules.assignableRoles(assistant, 'e1', _roles), isEmpty);
    });
  });

  group('équipe d\'un dossier', () {
    final all = [_a('1', 'zoe', 'trainee'), _a('2', 'Awa', 'assistant'), _a('3', 'kofi', 'manager'), _a('4', 'ben', 'assistant'), _a('5', 'x', 'manager', entity: 'e2')];

    test('seul le dossier demandé, chef de mission d\'abord puis assistants puis stagiaires, par nom', () {
      expect(TeamRules.teamOf(all, 'e1').map((a) => a.userName), ['kofi', 'Awa', 'ben', 'zoe']);
    });

    test('le chef de mission du dossier est retrouvé', () {
      expect(TeamRules.manager(TeamRules.teamOf(all, 'e1'))?.userName, 'kofi');
      expect(TeamRules.manager(TeamRules.teamOf(all, 'e3')), isNull);
    });
  });

  group('texte des notifications', () {
    test('affectation', () {
      final text = NotificationText.describe({
        'kind': 'assigned',
        'payload': {'role': 'Assistant', 'entity': 'SARL Test', 'by': 'Awa'},
      });
      expect(text, 'Vous êtes affecté(e) au dossier « SARL Test » comme assistant (par Awa).');
    });

    test('écriture à corriger et type inconnu', () {
      expect(NotificationText.describe({'kind': 'entry_to_correct', 'payload': {'number': 12, 'comment': 'compte'}}), 'Une écriture est à corriger (n° 12) : compte.');
      expect(NotificationText.describe({'kind': 'autre', 'payload': {}}), 'Nouvelle notification.');
    });
  });
}
