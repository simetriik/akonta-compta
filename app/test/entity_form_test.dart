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
}
