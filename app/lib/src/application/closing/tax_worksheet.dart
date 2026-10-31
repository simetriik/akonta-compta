import '../../domain/closing_models.dart';

/// Tableau de passage du résultat comptable au résultat fiscal : résultat de l'exercice, retraitements proposés
/// (modifiables par le comptable) et dernier calcul de l'impôt s'il existe.
class TaxWorksheet {
  TaxWorksheet({required this.accountingResult, required this.adjustments, this.computation});

  final int accountingResult;
  final List<TaxAdjustment> adjustments;
  final TaxComputation? computation;

  /// Total des réintégrations (charges non déductibles ajoutées au résultat).
  int get addBacks => _sum('add_back');

  /// Total des déductions (produits non imposables retirés du résultat).
  int get deductions => _sum('deduction');

  /// Résultat fiscal = résultat comptable + réintégrations - déductions, recalculé à chaque modification.
  int get taxableResult => accountingResult + addBacks - deductions;

  int _sum(String kind) => adjustments.where((a) => a.kind == kind).fold<int>(0, (s, a) => s + a.amount);
}
