import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/lettering_models.dart';
import 'mappers/lettering_repository_mappers.dart';
import '../../domain/repositories/lettering_repository.dart';

/// Module 7 — lettrage : lignes non lettrées, propositions, lettrage, délettrage.
class SupabaseLetteringRepository implements LetteringRepository {
  SupabaseLetteringRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UnletteredLine>> unlettered(String entityId, String accountId, {String? thirdPartyId}) async {
    final rows = await _client.rpc('unlettered_lines', params: {'p_entity': entityId, 'p_account': accountId, 'p_third_party': thirdPartyId}) as List;
    return rows.map((j) => unletteredLineFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LetteringProposal>> proposals(String entityId, String accountId, {String? thirdPartyId}) async {
    final rows = await _client.rpc('lettering_proposals', params: {'p_entity': entityId, 'p_account': accountId, 'p_third_party': thirdPartyId}) as List;
    return rows.map((j) => letteringProposalFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> letter(List<String> lineIds, {bool allowPartial = false}) async =>
      (await _client.rpc('letter_lines', params: {'p_line_ids': lineIds, 'p_allow_partial': allowPartial})) as String;

  @override
  Future<void> unletter(String letteringId, String reason) => _client.rpc('unletter', params: {'p_lettering': letteringId, 'p_reason': reason});

  @override
  Future<List<LetteringGroup>> groups(String entityId, String accountId, {String? thirdPartyId}) async {
    var q = _client.from('letterings').select().eq('entity_id', entityId).eq('account_id', accountId).isFilter('unlettered_at', null);
    if (thirdPartyId != null) q = q.eq('third_party_id', thirdPartyId);
    final rows = await q.order('created_at', ascending: false).limit(100);
    return rows.map(letteringGroupFromJson).toList();
  }

  @override
  Future<void> setLetterable(String accountId, bool value) => _client.from('accounts').update({'is_letterable': value}).eq('id', accountId);
}
