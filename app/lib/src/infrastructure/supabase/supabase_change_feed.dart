import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/realtime/change_feed.dart';

/// Écoute Supabase Realtime (Postgres Changes) : un canal par dossier courant, plus un canal pour les notifications de l'utilisateur.
/// La RLS s'applique à l'abonné : il ne reçoit que les changements des dossiers auxquels il a accès. Le contenu de l'événement
/// n'est jamais lu, il sert uniquement de signal pour relire les listes par les dépôts habituels.
class SupabaseChangeFeed implements ChangeFeedPort {
  SupabaseChangeFeed(this._client);

  final SupabaseClient _client;

  @override
  ChangeSubscription? open({required String userId, String? entityId}) => _SupabaseChangeSubscription(_client, userId, entityId);
}

class _SupabaseChangeSubscription implements ChangeSubscription {
  _SupabaseChangeSubscription(this._client, String userId, String? entityId) {
    final suffix = '$userId-${entityId ?? 'none'}-${DateTime.now().microsecondsSinceEpoch}';
    _channel = _client.channel('live-$suffix');

    void on(String table, ChangeTopic topic, {String? column, String? value}) {
      _channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: column == null ? null : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: column, value: value!),
        callback: (_) => _changes.add(topic),
      );
    }

    on('notifications', ChangeTopic.notifications, column: 'user_id', value: userId);
    if (entityId != null) {
      on('entries', ChangeTopic.entries, column: 'entity_id', value: entityId);
      on('documents', ChangeTopic.documents, column: 'entity_id', value: entityId);
      on('invoices', ChangeTopic.invoices, column: 'entity_id', value: entityId);
      // Pas de colonne de dossier sur les rattachements : la RLS limite déjà les événements reçus.
      on('entry_documents', ChangeTopic.documents);
    }
    _channel.subscribe(_onStatus);
  }

  final SupabaseClient _client;
  late final RealtimeChannel _channel;
  final _changes = StreamController<ChangeTopic>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  bool _connected = false;
  bool _closed = false;

  void _onStatus(RealtimeSubscribeStatus status, Object? error) {
    if (_closed) return;
    final connected = status == RealtimeSubscribeStatus.subscribed;
    if (connected == _connected) return;
    _connected = connected;
    _connection.add(connected);
  }

  @override
  Stream<ChangeTopic> get changes => _changes.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _client.removeChannel(_channel);
    await _changes.close();
    await _connection.close();
  }
}
