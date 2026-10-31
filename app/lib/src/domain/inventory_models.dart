class FixedAsset {
  const FixedAsset({required this.id, required this.code, required this.designation, required this.assetAccountCode, required this.acquisitionDate, required this.serviceDate, required this.grossValue, required this.salvageValue, required this.method, required this.durationMonths, this.decliningCoefficient, required this.priorDepreciation, required this.status, this.disposalDate, this.disposalPrice});

  final String id;
  final String code;
  final String designation;
  final String assetAccountCode;
  final DateTime acquisitionDate;
  final DateTime serviceDate;
  final int grossValue;
  final int salvageValue;
  final String method;
  final int durationMonths;
  final double? decliningCoefficient;
  final int priorDepreciation;
  final String status;
  final DateTime? disposalDate;
  final int? disposalPrice;

  String get statusLabel => switch (status) { 'in_service' => 'En service', 'disposed' => 'Cédée', 'scrapped' => 'Rebut', _ => status };
}

class PlanRow {
  const PlanRow({required this.yearNo, required this.periodStart, required this.periodEnd, required this.rate, required this.charge, required this.cumulated, required this.netBookValue});

  final int yearNo;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double rate;
  final int charge;
  final int cumulated;
  final int netBookValue;
}

class StockRow {
  const StockRow({required this.id, required this.stockAccountCode, required this.variationAccountCode, required this.openingValue, required this.closingValue, this.entryId});

  final String id;
  final String stockAccountCode;
  final String variationAccountCode;
  final int openingValue;
  final int closingValue;
  final String? entryId;
}

class ProvisionRow {
  const ProvisionRow({required this.id, required this.kind, this.thirdPartyCode, required this.baseAmount, this.rate, required this.amount, required this.previousAmount, this.note, this.entryId});

  final String id;
  final String kind;
  final String? thirdPartyCode;
  final int baseAmount;
  final double? rate;
  final int amount;
  final int previousAmount;
  final String? note;
  final String? entryId;
}

class AccrualRow {
  const AccrualRow({required this.id, required this.kind, required this.description, required this.accountCode, required this.counterpartCode, required this.totalAmount, required this.periodFrom, required this.periodTo, required this.amount, this.entryId, this.reversalEntryId});

  final String id;
  final String kind;
  final String description;
  final String accountCode;
  final String counterpartCode;
  final int totalAmount;
  final DateTime periodFrom;
  final DateTime periodTo;
  final int amount;
  final String? entryId;
  final String? reversalEntryId;

  static const kindLabels = {'cap': 'Charge à payer', 'par': 'Produit à recevoir', 'cca': 'Charge constatée d\'avance', 'pca': 'Produit constaté d\'avance'};
}
