import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/client_access_repository.dart';

class SupabaseClientAccessRepository implements ClientAccessRepository {
  SupabaseClientAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> access(String entityId) async {
    final row = await _client.from('entities').select('client_access').eq('id', entityId).single();
    return row['client_access'] as String;
  }

  @override
  Future<void> setAccess(String entityId, String status, {String? reason}) =>
      _client.rpc('set_client_access', params: {'p_entity': entityId, 'p_status': status, 'p_reason': reason});

  @override
  Future<void> returnDraft(String entryId, String comment) => _client.rpc('return_draft_to_client', params: {'p_entry': entryId, 'p_comment': comment});
}
