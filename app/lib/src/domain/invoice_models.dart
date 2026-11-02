// Facturation normalisée e-MECeF (D-043) : entités du domaine, sans dépendance à Flutter ni à la base.
// Périmètre déclaré à la DGI : factures de vente (FV) et d'avoir (FA), groupes de taxe A (exonéré) et B (taxable), AIB 1 % et 5 %.

enum InvoiceStatus { draft, pending, confirmed, cancelled }

InvoiceStatus invoiceStatusFromCode(String code) => switch (code) {
      'pending' => InvoiceStatus.pending,
      'confirmed' => InvoiceStatus.confirmed,
      'cancelled' => InvoiceStatus.cancelled,
      _ => InvoiceStatus.draft,
    };

/// Types de paiement acceptés par l'e-MCF (`PaymentTypeEnum`), avec leur libellé en français.
const Map<String, String> paymentTypeLabels = {
  'ESPECES': 'Espèces',
  'MOBILEMONEY': 'Mobile Money',
  'VIREMENT': 'Virement',
  'CARTEBANCAIRE': 'Carte bancaire',
  'CHEQUES': 'Chèque',
  'CREDIT': 'Crédit',
  'AUTRE': 'Autre',
};

/// Un e-MCF : point de vente du dossier avec son NIM. Le jeton n'est jamais lisible par l'application.
class EmcfDevice {
  const EmcfDevice({required this.id, required this.entityId, required this.nim, required this.label, required this.mode, required this.isActive});

  final String id;
  final String entityId;
  final String nim;
  final String label;
  final String mode; // 'test' ou 'production'
  final bool isActive;

  bool get isTest => mode == 'test';
}

class InvoiceLine {
  const InvoiceLine({this.code, required this.name, required this.price, required this.quantity, required this.taxGroup});

  final String? code;
  final String name;

  /// Prix unitaire TTC en FCFA.
  final int price;
  final double quantity;

  /// 'A' (exonéré) ou 'B' (taxable).
  final String taxGroup;

  /// Montant TTC de la ligne : prix × quantité, arrondi au franc (demi vers le haut), comme le calcul de contrôle SQL.
  int get amount => ((price * (quantity * 1000).round()) + 500) ~/ 1000;
}

class InvoicePayment {
  const InvoicePayment({required this.name, required this.amount});

  final String name;
  final int amount;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.entityId,
    required this.deviceId,
    required this.type,
    required this.status,
    required this.isTest,
    required this.operatorName,
    required this.createdAt,
    this.aib,
    this.clientIfu,
    this.clientName,
    this.clientContact,
    this.clientAddress,
    this.originalInvoiceId,
    this.reference,
    this.commercialMessage,
    this.total,
    this.codeMecef,
    this.qrCode,
    this.counters,
    this.dgiNim,
    this.dgiDatetime,
    this.issuedAt,
    this.lastError,
    this.lines = const [],
    this.payments = const [],
  });

  final String id;
  final String entityId;
  final String deviceId;
  final String type; // 'FV' ou 'FA'
  final InvoiceStatus status;
  final bool isTest;
  final String operatorName;
  final DateTime createdAt;
  final String? aib; // 'A' = 1 %, 'B' = 5 %
  final String? clientIfu;
  final String? clientName;
  final String? clientContact;
  final String? clientAddress;
  final String? originalInvoiceId;
  final String? reference;
  final String? commercialMessage;
  final int? total;
  final String? codeMecef;
  final String? qrCode;
  final String? counters;
  final String? dgiNim;
  final String? dgiDatetime;
  final DateTime? issuedAt;
  final String? lastError;
  final List<InvoiceLine> lines;
  final List<InvoicePayment> payments;

  bool get isCreditNote => type == 'FA';
  bool get isEditable => status == InvoiceStatus.draft;
  String get typeLabel => isCreditNote ? 'Facture d\'avoir' : 'Facture de vente';
}

/// Contenu d'un brouillon à enregistrer (création ou remplacement des lignes et paiements).
class InvoiceDraft {
  const InvoiceDraft({
    this.id,
    required this.entityId,
    required this.deviceId,
    required this.type,
    required this.operatorName,
    required this.lines,
    this.payments = const [],
    this.aib,
    this.clientIfu,
    this.clientName,
    this.clientContact,
    this.clientAddress,
    this.commercialMessage,
    this.originalInvoiceId,
    this.reference,
  });

  final String? id;
  final String entityId;
  final String deviceId;
  final String type;
  final String operatorName;
  final List<InvoiceLine> lines;
  final List<InvoicePayment> payments;
  final String? aib;
  final String? clientIfu;
  final String? clientName;
  final String? clientContact;
  final String? clientAddress;
  final String? commercialMessage;
  final String? originalInvoiceId;
  final String? reference;
}

/// Résultat d'une tentative d'émission auprès de la DGI.
enum IssueState {
  /// La DGI a confirmé : la facture est normalisée.
  confirmed,

  /// Refus, divergence de totaux ou expiration : la facture est redevenue modifiable.
  draft,

  /// Coupure avant la confirmation : la facture est en cours, à reprendre dans les deux minutes.
  pending,
}

class IssueResult {
  const IssueResult({required this.state, this.message, this.gaps = const []});

  final IssueState state;
  final String? message;
  final List<String> gaps;
}

/// Totaux affichés pendant la saisie (aperçu) : même règle que le calcul de contrôle de la base. La DGI reste la référence.
class InvoiceTotalsPreview {
  const InvoiceTotalsPreview({required this.totalA, required this.totalB, required this.htB, required this.vatB});

  final int totalA;
  final int totalB;
  final int htB;
  final int vatB;

  int get total => totalA + totalB;
}
