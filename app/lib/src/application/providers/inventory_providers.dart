import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/inventory_models.dart';
import '../../domain/consultation_models.dart';
import 'repositories.dart';

final fixedAssetsProvider = FutureProvider.family<List<FixedAsset>, String>((ref, entityId) => ref.watch(inventoryRepositoryProvider).assets(entityId));

final stocksProvider = FutureProvider.family<List<StockRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).stocks(fyId));

final provisionsProvider = FutureProvider.family<List<ProvisionRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).provisions(fyId));

final accrualsProvider = FutureProvider.family<List<AccrualRow>, String>((ref, fyId) => ref.watch(inventoryRepositoryProvider).accruals(fyId));

/// Stock initial par compte de stock : solde des comptes de classe 3 à la date d'ouverture de l'exercice
/// (à-nouveaux), lu dans la balance ; affiché avant même la génération des variations.
final stockOpeningBalancesProvider = FutureProvider.family<Map<String, int>, ({String entityId, DateTime startDate})>((ref, key) async {
  final rows = await ref.watch(consultationRepositoryProvider).trialBalance(ConsultationParams(entityId: key.entityId, from: key.startDate, to: key.startDate, classNo: 3));
  return {for (final r in rows) r.accountCode: r.openingDebit - r.openingCredit + r.periodDebit - r.periodCredit};
});
