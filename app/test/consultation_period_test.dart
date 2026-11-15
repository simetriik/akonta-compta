import 'package:akonta/src/application/providers/consultation_providers.dart';
import 'package:akonta/src/application/providers/entities_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/consultation_models.dart';
import 'package:akonta/src/domain/entity_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/consultation/consultation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden/golden_harness.dart';

class _Entity2028 extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearId: 'fy28', fiscalYearLabel: '2028', fiscalYearStatus: 'open');
}

/// AN-43 : la période par défaut de la Consultation est celle de l'exercice du dossier, pas l'année civile en cours.
void main() {
  setUpAll(setUpGolden);

  test('piste d\'audit : la période de l\'exercice est prolongée jusqu\'à aujourd\'hui, sauf si l\'utilisateur l\'a modifiée', () {
    final p = ConsultationParams(entityId: 'e1', from: DateTime(2027), to: DateTime(2027, 12, 31));
    final today = DateTime(2028, 2, 10, 15, 30);
    expect(auditPeriodFor(p, today, edited: false).to, DateTime(2028, 2, 10));
    expect(auditPeriodFor(p, today, edited: false).from, DateTime(2027));
    expect(auditPeriodFor(p, today, edited: true), same(p));
    expect(auditPeriodFor(p, DateTime(2027, 6, 1), edited: false), same(p)); // exercice en cours : inchangé
  });

  testWidgets('la période par défaut reprend les dates de l\'exercice courant', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      goldenApp(
        home: const ConsultationScreen(),
        overrides: [
          currentEntityProvider.overrideWith(_Entity2028.new),
          fiscalYearsProvider.overrideWith(
            (ref, id) async => [FiscalYear(id: 'fy28', entityId: 'e1', label: '2028', startDate: DateTime(2028), endDate: DateTime(2028, 12, 31), status: 'open')],
          ),
          generalLedgerProvider.overrideWith((ref, p) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('01/01/2028'), findsOneWidget);
    expect(find.text('31/12/2028'), findsOneWidget);
  });
}
