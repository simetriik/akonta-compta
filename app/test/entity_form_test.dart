import 'package:akonta/src/infrastructure/supabase/mappers/entity_models_mappers.dart';
import 'package:akonta/src/domain/entity_models.dart';
import 'package:akonta/src/presentation/entities/entity_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la fiche entité exige une dénomination et un IFU bien formé', (tester) async {
    var submitted = false;
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EntityForm(onSubmit: (_) async => submitted = true))));
    await tester.enterText(find.byKey(const Key('entity-tax-id')), '123');
    await tester.tap(find.byKey(const Key('entity-submit')));
    await tester.pump();
    expect(find.text('Dénomination obligatoire'), findsOneWidget);
    expect(find.text('IFU : 13 chiffres attendus'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('à la création, un bandeau dit que seule la dénomination est obligatoire et le défaut de longueur est rappelé', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EntityForm(defaultAccountLength: 7, onSubmit: (_) async {}))));
    expect(find.textContaining('Seule la dénomination est obligatoire'), findsOneWidget);
    expect(find.textContaining('(7 chiffres)'), findsOneWidget);
  });

  group('référentiel comptable', () {
    testWidgets('une forme juridique associative pré-sélectionne le SYCEBNL et la valeur part à la création', (tester) async {
      EntityInput? sent;
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: EntityForm(onSubmit: (i) async => sent = i))));
      expect(find.text('Système normal SYSCOHADA · FCFA'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('entity-name')), 'Association Espoir');
      await tester.enterText(find.byKey(const Key('entity-legal-form')), 'Association loi 1901');
      await tester.pump();
      expect(find.text('SYCEBNL · FCFA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('entity-submit')));
      await tester.pump();
      expect(sent?.accountingSystem, 'sycebnl');
      expect(sent?.toJson()['accounting_system'], 'sycebnl');
    });

    testWidgets('à la modification, le référentiel est figé et n\'est pas renvoyé', (tester) async {
      EntityInput? sent;
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const initial = EntityDetail(id: 'e1', cabinetId: 'c1', name: 'Association Espoir', accountingSystem: 'sycebnl');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: EntityForm(initial: initial, onSubmit: (i) async => sent = i))));
      expect(find.text('Figé à la création'), findsOneWidget);
      await tester.tap(find.byKey(const Key('entity-submit')));
      await tester.pump();
      expect(sent?.accountingSystem, isNull);
      expect(sent?.toJson().containsKey('accounting_system'), isFalse);
    });

    test('suggestAccountingSystem reconnaît les entités à but non lucratif', () {
      expect(EntityInput.suggestAccountingSystem('Association'), 'sycebnl');
      expect(EntityInput.suggestAccountingSystem('ONG'), 'sycebnl');
      expect(EntityInput.suggestAccountingSystem('Fondation d\'entreprise'), 'sycebnl');
      expect(EntityInput.suggestAccountingSystem('Syndicat professionnel'), 'sycebnl');
      expect(EntityInput.suggestAccountingSystem('SARL'), isNull);
      expect(EntityInput.suggestAccountingSystem('Société anonyme'), isNull);
      expect(EntityInput.suggestAccountingSystem(null), isNull);
    });
  });
}
