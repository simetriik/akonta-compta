import 'dart:async';

import 'change_feed.dart';

/// Relit les données affichées quand un autre utilisateur les modifie.
///
/// Les changements reçus sont regroupés (un lot de saisies ne provoque qu'une relecture). Si le canal temps réel est coupé, une relecture
/// périodique prend le relais, puis une relecture complète rattrape ce qui a pu être manqué à la reconnexion.
class LiveRefresh {
  LiveRefresh({required this.onRefresh, this.debounce = const Duration(milliseconds: 500), this.pollInterval = const Duration(seconds: 60)});

  /// Relit les données des familles indiquées.
  final void Function(Set<ChangeTopic> topics) onRefresh;
  final Duration debounce;
  final Duration pollInterval;

  final _pending = <ChangeTopic>{};
  Timer? _debounceTimer;
  Timer? _pollTimer;
  StreamSubscription<ChangeTopic>? _changesSub;
  StreamSubscription<bool>? _connectionSub;
  ChangeSubscription? _subscription;
  bool _hasBeenConnected = false;
  bool _disposed = false;

  /// Branche l'écoute ; elle est fermée avec [dispose].
  void attach(ChangeSubscription subscription) {
    _subscription = subscription;
    _changesSub = subscription.changes.listen(_onChange);
    _connectionSub = subscription.connection.listen(_onConnection);
    _onConnection(subscription.isConnected);
  }

  /// Relit tout maintenant : reprise de l'application, retour en ligne, geste manuel.
  void refreshAll() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _pending.clear();
    onRefresh(ChangeTopic.values.toSet());
  }

  void _onChange(ChangeTopic topic) {
    _pending.add(topic);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      final topics = Set<ChangeTopic>.of(_pending);
      _pending.clear();
      if (!_disposed && topics.isNotEmpty) onRefresh(topics);
    });
  }

  void _onConnection(bool connected) {
    if (_disposed) return;
    if (connected) {
      _pollTimer?.cancel();
      _pollTimer = null;
      // Première connexion : les listes viennent d'être lues. Reconnexion : des changements ont pu passer pendant la coupure.
      if (_hasBeenConnected) refreshAll();
      _hasBeenConnected = true;
    } else {
      _pollTimer ??= Timer.periodic(pollInterval, (_) => refreshAll());
    }
  }

  /// Arrête les relectures et ferme l'écoute (la fermeture réseau se termine en arrière-plan).
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _changesSub?.cancel();
    _connectionSub?.cancel();
    _subscription?.close();
  }
}
