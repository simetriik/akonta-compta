import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX-14 : un dialogue ouvert depuis une cellule de la grille de saisie héritait du thème « tableur » (champs sans
/// bordure). Un dialogue doit toujours reprendre le thème de l'application.
void main() {
  testWidgets('un dialogue ouvert depuis la grille de saisie garde des champs encadrés', (tester) async {
    late BuildContext cellContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkontaTheme(),
        home: Scaffold(
          body: AkEntryGridTheme(
            child: Builder(
              builder: (context) {
                cellContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    showDialog<void>(context: cellContext, builder: (_) => const AkDialog(title: 'Test', content: AkTextField(key: Key('f'), label: 'IFU')));
    await tester.pumpAndSettle();
    final decorator = tester.widget<InputDecorator>(find.descendant(of: find.byKey(const Key('f')), matching: find.byType(InputDecorator)));
    final border = decorator.decoration.enabledBorder ?? Theme.of(tester.element(find.byKey(const Key('f')))).inputDecorationTheme.enabledBorder;
    expect((border as OutlineInputBorder).borderSide.color, isNot(Colors.transparent));
    expect(Theme.of(tester.element(find.byKey(const Key('f')))).inputDecorationTheme.filled, isTrue);
  });
}
