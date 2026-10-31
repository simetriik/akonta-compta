import 'package:intl/date_symbol_data_local.dart';
import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/presentation/references/tax_rates_tab.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  testWidgets('le dialogue de taux affiche les champs Ak et refuse une saisie invalide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: const Scaffold(body: TaxRateDialog()),
        ),
      ),
    );
    expect(find.byType(AkTextField), findsNWidgets(4));
    expect(find.byType(AkDateField), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Code, libellé, taux (0-100) et date valides requis'), findsOneWidget);
  });
}
