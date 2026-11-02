import 'dart:typed_data';

import '../../domain/invoice_models.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../connectivity/connectivity.dart';

/// Cas d'usage de la facturation e-MECeF. La lecture se sert du cache hors connexion ; tout ce qui parle à la DGI
/// ou modifie les factures exige une connexion (la DGI doit confirmer en temps réel).
class InvoicesService {
  InvoicesService(this._repository, this._online);

  final InvoicesRepository _repository;
  final OnlinePolicy _online;

  Future<List<EmcfDevice>> devices(String entityId) => _repository.devices(entityId);

  Future<EmcfDevice> createDevice({required String cabinetId, required String entityId, required String nim, required String label, required String mode}) async {
    _online.require('La déclaration d\'un e-MCF');
    return _repository.createDevice(cabinetId: cabinetId, entityId: entityId, nim: nim.trim().toUpperCase(), label: label.trim(), mode: mode);
  }

  Future<void> setDeviceActive(String deviceId, bool active) async {
    _online.require('La gestion des e-MCF');
    return _repository.setDeviceActive(deviceId, active);
  }

  Future<void> setToken(String deviceId, String token) async {
    _online.require('L\'enregistrement du jeton');
    return _repository.setToken(deviceId, token.trim());
  }

  Future<List<Invoice>> invoices(String entityId) => _repository.invoices(entityId);

  Future<Invoice> invoice(String id) => _repository.invoice(id);

  Future<String> saveDraft(String cabinetId, InvoiceDraft draft) async {
    _online.require('L\'enregistrement d\'une facture');
    return _repository.saveDraft(cabinetId, draft);
  }

  Future<void> deleteDraft(String id) async {
    _online.require('La suppression d\'un brouillon de facture');
    return _repository.deleteDraft(id);
  }

  Future<IssueResult> issue(String id) async {
    _online.require('L\'émission d\'une facture normalisée');
    return _repository.issue(id);
  }

  Future<IssueResult> resume(String id) async {
    _online.require('La reprise d\'une facture');
    return _repository.resume(id);
  }

  Future<IssueResult> cancelPending(String id) async {
    _online.require('L\'annulation d\'une facture');
    return _repository.cancelPending(id);
  }

  Future<String> createCreditNote(String originalId) async {
    _online.require('La création d\'un avoir');
    return _repository.createCreditNote(originalId);
  }

  Future<(String, Uint8List)> pdf(String id) async {
    _online.require('Le PDF de la facture');
    return _repository.pdf(id);
  }

  Future<InvoiceAccountSettings?> accountSettings(String entityId) => _repository.accountSettings(entityId);

  Future<void> saveAccountSettings(String cabinetId, InvoiceAccountSettings settings) async {
    _online.require('Le paramétrage de la facturation');
    return _repository.saveAccountSettings(cabinetId, settings);
  }

  Future<InvoiceEntryLink?> invoiceEntry(String invoiceId) => _repository.invoiceEntry(invoiceId);

  Future<EntryOutcome> generateEntry(String invoiceId) async {
    _online.require('La génération de l\'écriture');
    return _repository.generateEntry(invoiceId);
  }
}
