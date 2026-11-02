import 'dart:typed_data';

import '../invoice_models.dart';

/// Factures normalisées e-MECeF : e-MCF du dossier, brouillons, émission auprès de la DGI (via l'Edge Function), avoirs, PDF.
abstract interface class InvoicesRepository {
  Future<List<EmcfDevice>> devices(String entityId);

  Future<EmcfDevice> createDevice({required String cabinetId, required String entityId, required String nim, required String label, required String mode});

  Future<void> setDeviceActive(String deviceId, bool active);

  /// Enregistre le jeton : l'Edge Function le vérifie auprès de la DGI (jeton valable, NIM concordant) avant de le garder.
  Future<void> setToken(String deviceId, String token);

  Future<List<Invoice>> invoices(String entityId);

  Future<Invoice> invoice(String id);

  /// Crée ou remplace un brouillon (lignes et paiements compris) ; renvoie son identifiant.
  Future<String> saveDraft(String cabinetId, InvoiceDraft draft);

  Future<void> deleteDraft(String id);

  /// Émet la facture : soumission, contrôle des totaux, confirmation.
  Future<IssueResult> issue(String id);

  /// Reprend une facture restée « en cours » après une coupure.
  Future<IssueResult> resume(String id);

  /// Annule une facture en cours auprès de la DGI.
  Future<IssueResult> cancelPending(String id);

  /// Crée le brouillon d'avoir d'une facture de vente confirmée ; renvoie son identifiant.
  Future<String> createCreditNote(String originalId);

  /// PDF de la facture normalisée (nom du fichier, contenu).
  Future<(String, Uint8List)> pdf(String id);
}
