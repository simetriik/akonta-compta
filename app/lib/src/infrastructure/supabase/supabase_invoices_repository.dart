import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error.dart';
import '../../domain/invoice_models.dart';
import '../../domain/repositories/invoices_repository.dart';
import 'mappers/invoices_repository_mappers.dart';

/// Facturation e-MECeF : lectures et brouillons par PostgREST sous RLS ; tout ce qui parle à la DGI ou au PDF passe par l'Edge
/// Function `emcf-invoice` (le jeton de l'e-MCF n'est jamais lu par l'application).
class SupabaseInvoicesRepository implements InvoicesRepository {
  SupabaseInvoicesRepository(this._client);

  final SupabaseClient _client;

  static const _invoiceColumns = '*, invoice_lines(*), invoice_payments(*)';

  @override
  Future<List<EmcfDevice>> devices(String entityId) async {
    final rows = await _client.from('emcf_devices').select().eq('entity_id', entityId).order('created_at');
    return rows.map(emcfDeviceFromJson).toList();
  }

  @override
  Future<EmcfDevice> createDevice({required String cabinetId, required String entityId, required String nim, required String label, required String mode}) async {
    final row = await _client.from('emcf_devices').insert({'cabinet_id': cabinetId, 'entity_id': entityId, 'nim': nim, 'label': label, 'mode': mode}).select().single();
    return emcfDeviceFromJson(row);
  }

  @override
  Future<void> setDeviceActive(String deviceId, bool active) => _client.from('emcf_devices').update({'is_active': active}).eq('id', deviceId);

  @override
  Future<void> setToken(String deviceId, String token) async {
    await _invoke({'action': 'set_token', 'device_id': deviceId, 'token': token});
  }

  @override
  Future<List<Invoice>> invoices(String entityId) async {
    final rows = await _client.from('invoices').select(_invoiceColumns).eq('entity_id', entityId).order('created_at', ascending: false).limit(500);
    return rows.map(invoiceFromJson).toList();
  }

  @override
  Future<Invoice> invoice(String id) async => invoiceFromJson(await _client.from('invoices').select(_invoiceColumns).eq('id', id).single());

  @override
  Future<String> saveDraft(String cabinetId, InvoiceDraft draft) async {
    final id = await _client.rpc('save_invoice_draft', params: {'p_invoice': draft.id, 'p_data': invoiceDraftToJson(cabinetId, draft)});
    return id as String;
  }

  @override
  Future<void> deleteDraft(String id) => _client.from('invoices').delete().eq('id', id);

  @override
  Future<IssueResult> issue(String id) async => issueResultFromJson(await _invoke({'action': 'issue', 'invoice_id': id}));

  @override
  Future<IssueResult> resume(String id) async => issueResultFromJson(await _invoke({'action': 'resume', 'invoice_id': id}));

  @override
  Future<IssueResult> cancelPending(String id) async => issueResultFromJson(await _invoke({'action': 'cancel', 'invoice_id': id}));

  @override
  Future<String> createCreditNote(String originalId) async => await _client.rpc('create_credit_note', params: {'p_original': originalId}) as String;

  @override
  Future<(String, Uint8List)> pdf(String id) async {
    final res = await _client.functions.invoke('emcf-invoice', body: {'action': 'pdf', 'invoice_id': id});
    if (res.status != 200) throw FunctionException(status: res.status, details: res.data);
    final invoice = await this.invoice(id);
    final name = 'facture-${invoice.codeMecef ?? id}.pdf';
    return (name, res.data as Uint8List);
  }

  @override
  Future<InvoiceAccountSettings?> accountSettings(String entityId) async {
    final rows = await _client.from('invoice_account_settings').select().eq('entity_id', entityId).order('valid_from', ascending: false).limit(1);
    return rows.isEmpty ? null : invoiceAccountSettingsFromJson(rows.first);
  }

  @override
  Future<void> saveAccountSettings(String cabinetId, InvoiceAccountSettings settings) =>
      _client.from('invoice_account_settings').upsert(invoiceAccountSettingsToJson(cabinetId, settings), onConflict: 'entity_id,valid_from');

  @override
  Future<InvoiceEntryLink?> invoiceEntry(String invoiceId) async {
    final rows = await _client.rpc('invoice_entry', params: {'p_invoice': invoiceId}) as List;
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return InvoiceEntryLink(entryId: r['entry_id'] as String, isValidated: r['status'] == 'validated', number: (r['number'] as num?)?.toInt());
  }

  @override
  Future<EntryOutcome> generateEntry(String invoiceId) async {
    final res = await _client.functions.invoke('emcf-invoice', body: {'action': 'generate_entry', 'invoice_id': invoiceId});
    // 422 : l'Edge Function a répondu avec le motif (paramètres absents, facture de test…) : on le rend sans lever d'erreur.
    final data = res.data;
    final outcome = data is Map<String, dynamic> ? entryOutcomeFromJson(data['entry']) : null;
    if (outcome == null) throw FunctionException(status: res.status, details: res.data);
    return outcome;
  }

  /// Appelle l'Edge Function et renvoie son corps JSON ; les refus (4xx) deviennent des erreurs classées par le classeur Supabase.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final res = await _client.functions.invoke('emcf-invoice', body: body);
    if (res.status < 200 || res.status >= 300) throw FunctionException(status: res.status, details: res.data);
    final data = res.data;
    if (data is! Map<String, dynamic>) throw const AppError.business('Réponse inattendue du service de facturation.');
    return data;
  }
}
