import 'dart:typed_data';
import '../consultation_models.dart';

abstract interface class ConsultationRepository {
  Future<List<LedgerLine>> generalLedger(ConsultationParams p);

  Future<List<BalanceRow>> trialBalance(ConsultationParams p);

  Future<List<BalanceRow>> auxiliaryBalance(ConsultationParams p);

  Future<List<AgedRow>> agedBalance(ConsultationParams p);

  Future<List<CentralizationRow>> centralization(ConsultationParams p);

  /// Export PDF / Excel : renvoie le nom du fichier et son contenu.
  Future<(String, Uint8List)> export({required ConsultationParams p, required String kind, required String format, bool allCounterparts = false});
}
