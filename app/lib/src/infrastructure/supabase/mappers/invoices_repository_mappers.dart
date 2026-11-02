import '../../../domain/invoice_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités de la facturation.

EmcfDevice emcfDeviceFromJson(Map<String, dynamic> j) => EmcfDevice(
      id: j['id'] as String,
      entityId: j['entity_id'] as String,
      nim: j['nim'] as String,
      label: j['label'] as String,
      mode: j['mode'] as String,
      isActive: j['is_active'] as bool,
    );

InvoiceLine invoiceLineFromJson(Map<String, dynamic> j) => InvoiceLine(
      code: j['code'] as String?,
      name: j['name'] as String,
      price: (j['price'] as num).toInt(),
      quantity: (j['quantity'] as num).toDouble(),
      taxGroup: j['tax_group'] as String,
    );

InvoicePayment invoicePaymentFromJson(Map<String, dynamic> j) => InvoicePayment(name: j['name'] as String, amount: (j['amount'] as num).toInt());

Invoice invoiceFromJson(Map<String, dynamic> j) {
  final lines = [for (final l in (j['invoice_lines'] as List? ?? const [])) l as Map<String, dynamic>]..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num));
  return Invoice(
    id: j['id'] as String,
    entityId: j['entity_id'] as String,
    deviceId: j['device_id'] as String,
    type: j['type'] as String,
    status: invoiceStatusFromCode(j['status'] as String),
    isTest: j['is_test'] as bool,
    operatorName: j['operator_name'] as String,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    aib: j['aib'] as String?,
    clientIfu: j['client_ifu'] as String?,
    clientName: j['client_name'] as String?,
    clientContact: j['client_contact'] as String?,
    clientAddress: j['client_address'] as String?,
    originalInvoiceId: j['original_invoice_id'] as String?,
    reference: j['reference'] as String?,
    commercialMessage: j['commercial_message'] as String?,
    total: (j['total'] as num?)?.toInt(),
    codeMecef: j['code_mecef'] as String?,
    qrCode: j['qr_code'] as String?,
    counters: j['counters'] as String?,
    dgiNim: j['dgi_nim'] as String?,
    dgiDatetime: j['dgi_datetime'] as String?,
    issuedAt: j['issued_at'] == null ? null : DateTime.parse(j['issued_at'] as String).toLocal(),
    lastError: j['last_error'] as String?,
    lines: lines.map(invoiceLineFromJson).toList(),
    payments: [for (final p in (j['invoice_payments'] as List? ?? const [])) invoicePaymentFromJson(p as Map<String, dynamic>)],
  );
}

/// Charge de `save_invoice_draft` : champs de la facture, lignes et paiements.
Map<String, dynamic> invoiceDraftToJson(String cabinetId, InvoiceDraft d) => {
      'cabinet_id': cabinetId,
      'entity_id': d.entityId,
      'device_id': d.deviceId,
      'type': d.type,
      'operator_name': d.operatorName.trim(),
      'aib': d.aib,
      'client_ifu': d.clientIfu,
      'client_name': d.clientName,
      'client_contact': d.clientContact,
      'client_address': d.clientAddress,
      'commercial_message': d.commercialMessage,
      'lines': [
        for (final l in d.lines) {'code': l.code, 'name': l.name.trim(), 'price': l.price, 'quantity': l.quantity, 'tax_group': l.taxGroup},
      ],
      'payments': [
        for (final p in d.payments) {'name': p.name, 'amount': p.amount},
      ],
    };

IssueResult issueResultFromJson(Map<String, dynamic> j) {
  final state = switch (j['state']) {
    'confirmed' => IssueState.confirmed,
    'pending' => IssueState.pending,
    _ => IssueState.draft,
  };
  return IssueResult(state: state, message: j['reason'] as String?, gaps: [for (final g in (j['gaps'] as List? ?? const [])) g as String], entry: entryOutcomeFromJson(j['entry']));
}

InvoiceAccountSettings invoiceAccountSettingsFromJson(Map<String, dynamic> j) => InvoiceAccountSettings(
      entityId: j['entity_id'] as String,
      validFrom: DateTime.parse(j['valid_from'] as String),
      clientAccountId: j['client_account_id'] as String,
      salesExemptAccountId: j['sales_exempt_account_id'] as String,
      salesTaxableAccountId: j['sales_taxable_account_id'] as String,
      vatAccountId: j['vat_account_id'] as String,
      aibAccountId: j['aib_account_id'] as String?,
    );

Map<String, dynamic> invoiceAccountSettingsToJson(String cabinetId, InvoiceAccountSettings s) => {
      'cabinet_id': cabinetId,
      'entity_id': s.entityId,
      'valid_from': s.validFrom.toIso8601String().substring(0, 10),
      'client_account_id': s.clientAccountId,
      'sales_exempt_account_id': s.salesExemptAccountId,
      'sales_taxable_account_id': s.salesTaxableAccountId,
      'vat_account_id': s.vatAccountId,
      'aib_account_id': s.aibAccountId,
    };

EntryOutcome? entryOutcomeFromJson(Object? j) {
  if (j is! Map<String, dynamic>) return null;
  final state = switch (j['state']) {
    'generated' => EntryState.generated,
    'skipped' => EntryState.skipped,
    _ => EntryState.failed,
  };
  return EntryOutcome(state: state, message: j['message'] as String?, entryId: j['entry_id'] as String?);
}
