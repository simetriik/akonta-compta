import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/closing_models.dart';
import '../closing/tax_worksheet.dart';
import 'services.dart';

/// Clé des données de clôture : un exercice d'un dossier.
typedef ClosingKey = ({String entityId, String fyId});

/// Contrôles de clôture ; `ref.invalidate` les relance.
final closingChecksProvider = FutureProvider.autoDispose.family<List<ClosingCheck>, ClosingKey>(
  (ref, k) => ref.watch(closingServiceProvider).runChecks(k.entityId, k.fyId),
);

/// Tableau de passage du résultat comptable au résultat fiscal, chargé d'un bloc (une erreur sur l'une des trois lectures l'annonce à l'écran).
final taxWorksheetProvider = FutureProvider.autoDispose.family<TaxWorksheet, ClosingKey>((ref, k) async {
  final service = ref.watch(closingServiceProvider);
  final adjustments = await service.proposeAdjustments(k.entityId, k.fyId);
  final accounting = await service.accountingResult(k.entityId, k.fyId);
  final computation = await service.taxComputation(k.fyId);
  return TaxWorksheet(accountingResult: accounting, adjustments: adjustments, computation: computation);
});

/// Résultat en instance d'affectation à l'ouverture de l'exercice [ClosingKey.fyId] (l'exercice suivant) ; `ref.invalidate` le relit.
final pendingResultProvider = FutureProvider.autoDispose.family<int, ClosingKey>(
  (ref, k) => ref.watch(closingServiceProvider).pendingResult(k.entityId, k.fyId),
);

/// Derniers états financiers générés d'un exercice, ou `null` s'il n'y en a pas.
final latestStatementsProvider = FutureProvider.autoDispose.family<FinancialStatements?, String>(
  (ref, fyId) => ref.watch(closingServiceProvider).latestStatements(fyId),
);
