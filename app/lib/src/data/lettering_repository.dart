import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';
import '../infrastructure/supabase/mappers/lettering_repository_mappers.dart';

class UnletteredLine {
  const UnletteredLine({required this.lineId, required this.entryId, required this.entryDate, required this.journalCode, required this.number, this.reference, required this.label, this.thirdPartyId, this.thirdPartyCode, required this.debit, required this.credit});

  final String lineId;
  final String entryId;
  final DateTime entryDate;
  final String journalCode;
  final int number;
  final String? reference;
  final String label;
  final String? thirdPartyId;
  final String? thirdPartyCode;
  final int debit;
  final int credit;
}

class LetteringProposal {
  const LetteringProposal({required this.debitLineId, required this.creditLineIds, this.thirdPartyCode, required this.amount, required this.rule});

  final String debitLineId;
  final List<String> creditLineIds;
  final String? thirdPartyCode;
  final int amount;
  final String rule;

  List<String> get allLineIds => [debitLineId, ...creditLineIds];
  String get ruleLabel => rule == 'same_amount' ? 'même montant' : 'facture = règlement + retenue';
}

class LetteringGroup {
  const LetteringGroup({required this.id, required this.code, required this.isPartial, required this.totalDebit, required this.totalCredit, required this.createdAt, this.unletteredAt});

  final String id;
  final String code;
  final bool isPartial;
  final int totalDebit;
  final int totalCredit;
  final DateTime createdAt;
  final DateTime? unletteredAt;
}

/// Module 7 — lettrage : lignes non lettrées, propositions, lettrage, délettrage.
class LetteringRepository {
  LetteringRepository(this._client);

  final SupabaseClient _client;

  Future<List<UnletteredLine>> unlettered(String entityId, String accountId, {String? thirdPartyId}) async {
    final rows = await _client.rpc('unlettered_lines', params: {'p_entity': entityId, 'p_account': accountId, 'p_third_party': thirdPartyId}) as List;
    return rows.map((j) => unletteredLineFromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<LetteringProposal>> proposals(String entityId, String accountId, {String? thirdPartyId}) async {
    final rows = await _client.rpc('lettering_proposals', params: {'p_entity': entityId, 'p_account': accountId, 'p_third_party': thirdPartyId}) as List;
    return rows.map((j) => letteringProposalFromJson(j as Map<String, dynamic>)).toList();
  }

  Future<String> letter(List<String> lineIds, {bool allowPartial = false}) async =>
      (await _client.rpc('letter_lines', params: {'p_line_ids': lineIds, 'p_allow_partial': allowPartial})) as String;

  Future<void> unletter(String letteringId, String reason) => _client.rpc('unletter', params: {'p_lettering': letteringId, 'p_reason': reason});

  Future<List<LetteringGroup>> groups(String entityId, String accountId, {String? thirdPartyId}) async {
    var q = _client.from('letterings').select().eq('entity_id', entityId).eq('account_id', accountId).isFilter('unlettered_at', null);
    if (thirdPartyId != null) q = q.eq('third_party_id', thirdPartyId);
    final rows = await q.order('created_at', ascending: false).limit(100);
    return rows.map(letteringGroupFromJson).toList();
  }

  Future<void> setLetterable(String accountId, bool value) => _client.from('accounts').update({'is_letterable': value}).eq('id', accountId);
}

final letteringRepositoryProvider = Provider<LetteringRepository>((ref) => LetteringRepository(ref.watch(supabaseClientProvider)));
