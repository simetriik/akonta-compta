import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/consultation_providers.dart';
import 'package:akonta/src/domain/consultation_models.dart';
import 'package:akonta/src/presentation/consultation/balance_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un clic sur un compte de la balance ouvre son grand livre', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final params = ConsultationParams(entityId: 'e1', from: DateTime(2026), to: DateTime(2026, 12, 31));
    String? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialBalanceProvider.overrideWith(
            (ref, p) async => const [BalanceRow(accountCode: '4011000', accountLabel: 'Fournisseurs', openingDebit: 0, openingCredit: 0, periodDebit: 0, periodCredit: 5000, closingDebit: 0, closingCredit: 5000)],
          ),
        ],
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: Scaffold(
            body: SizedBox(height: 800, child: BalanceTab(params: params, onOpenAccount: (code) => opened = code)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fournisseurs'));
    await tester.pump();
    expect(opened, '4011000');
  });
}
