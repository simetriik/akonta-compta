import 'dart:typed_data';

import '../connectivity/connectivity.dart';
import '../../domain/repositories/consultation_repository.dart';
import '../../domain/consultation_models.dart';

/// Cas d'usage consultation : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class ConsultationService {
  ConsultationService(this._repository, this._online);

  final ConsultationRepository _repository;
  final OnlinePolicy _online;

  Future<List<LedgerLine>> generalLedger(ConsultationParams p) async {
    _online.require('Le grand livre');
    return _repository.generalLedger(p);
  }

  Future<List<BalanceRow>> trialBalance(ConsultationParams p) async {
    _online.require('La balance');
    return _repository.trialBalance(p);
  }

  Future<List<BalanceRow>> auxiliaryBalance(ConsultationParams p) async {
    _online.require('La balance auxiliaire');
    return _repository.auxiliaryBalance(p);
  }

  Future<List<AgedRow>> agedBalance(ConsultationParams p) async {
    _online.require('La balance âgée');
    return _repository.agedBalance(p);
  }

  Future<List<CentralizationRow>> centralization(ConsultationParams p) async {
    _online.require('La centralisation des journaux');
    return _repository.centralization(p);
  }

  /// Export PDF / Excel : renvoie le nom du fichier et son contenu.
  Future<(String, Uint8List)> export({required ConsultationParams p, required String kind, required String format, bool allCounterparts = false}) async {
    _online.require('L\'export');
    return _repository.export(p: p, kind: kind, format: format, allCounterparts: allCounterparts);
  }
}
