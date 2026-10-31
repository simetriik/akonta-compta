import '../../../data/inventory_repository.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

FixedAsset fixedAssetFromJson(Map<String, dynamic> j) => FixedAsset(
        id: j['id'] as String,
        code: j['code'] as String,
        designation: j['designation'] as String,
        assetAccountCode: (j['accounts'] as Map?)?['code'] as String? ?? '',
        acquisitionDate: DateTime.parse(j['acquisition_date'] as String),
        serviceDate: DateTime.parse(j['service_date'] as String),
        grossValue: (j['gross_value'] as num).toInt(),
        salvageValue: (j['salvage_value'] as num?)?.toInt() ?? 0,
        method: j['method'] as String,
        durationMonths: (j['duration_months'] as num).toInt(),
        decliningCoefficient: j['declining_coefficient'] == null ? null : double.parse('${j['declining_coefficient']}'),
        priorDepreciation: (j['prior_depreciation'] as num?)?.toInt() ?? 0,
        status: j['status'] as String,
        disposalDate: j['disposal_date'] == null ? null : DateTime.parse(j['disposal_date'] as String),
        disposalPrice: (j['disposal_price'] as num?)?.toInt(),
      );

PlanRow planRowFromJson(Map<String, dynamic> j) => PlanRow(
        yearNo: (j['year_no'] as num).toInt(),
        periodStart: DateTime.parse(j['period_start'] as String),
        periodEnd: DateTime.parse(j['period_end'] as String),
        rate: double.parse('${j['rate']}'),
        charge: (j['charge'] as num).toInt(),
        cumulated: (j['cumulated'] as num).toInt(),
        netBookValue: (j['net_book_value'] as num).toInt(),
      );

StockRow stockRowFromJson(Map<String, dynamic> j) => StockRow(
        id: j['id'] as String,
        stockAccountCode: (j['stock'] as Map?)?['code'] as String? ?? '',
        variationAccountCode: (j['variation'] as Map?)?['code'] as String? ?? '',
        openingValue: (j['opening_value'] as num).toInt(),
        closingValue: (j['closing_value'] as num).toInt(),
        entryId: j['entry_id'] as String?,
      );

ProvisionRow provisionRowFromJson(Map<String, dynamic> j) => ProvisionRow(
        id: j['id'] as String,
        kind: j['kind'] as String,
        thirdPartyCode: (j['third_parties'] as Map?)?['code'] as String?,
        baseAmount: (j['base_amount'] as num).toInt(),
        rate: j['rate'] == null ? null : double.parse('${j['rate']}'),
        amount: (j['amount'] as num).toInt(),
        previousAmount: (j['previous_amount'] as num).toInt(),
        note: j['note'] as String?,
        entryId: j['entry_id'] as String?,
      );

AccrualRow accrualRowFromJson(Map<String, dynamic> j) => AccrualRow(
        id: j['id'] as String,
        kind: j['kind'] as String,
        description: j['description'] as String,
        accountCode: (j['account'] as Map?)?['code'] as String? ?? '',
        counterpartCode: (j['counterpart'] as Map?)?['code'] as String? ?? '',
        totalAmount: (j['total_amount'] as num).toInt(),
        periodFrom: DateTime.parse(j['period_from'] as String),
        periodTo: DateTime.parse(j['period_to'] as String),
        amount: (j['amount'] as num).toInt(),
        entryId: j['entry_id'] as String?,
        reversalEntryId: j['reversal_entry_id'] as String?,
      );
