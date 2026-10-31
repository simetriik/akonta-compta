import 'dart:async';

import 'package:http/http.dart' as http;

import '../../application/connectivity/connectivity.dart';

/// Moniteur de connexion : interroge régulièrement le service d'authentification (point de santé) ; les échecs réseau constatés
/// par le client HTTP le basculent aussitôt hors ligne. Plus fréquent hors ligne (retour rapide), plus lent en ligne.
class ReachabilityMonitor implements ConnectivityPort {
  ReachabilityMonitor({required this.healthUrl, required this.apiKey, http.Client? client, this.onlineInterval = const Duration(seconds: 30), this.offlineInterval = const Duration(seconds: 5)})
      : _client = client ?? http.Client();

  final Uri healthUrl;
  final String apiKey;
  final http.Client _client;
  final Duration onlineInterval;
  final Duration offlineInterval;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _online = true;
  Timer? _timer;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  void _set(bool online) {
    if (online == _online) return;
    _online = online;
    _changes.add(online);
    _schedule();
  }

  /// Appelé par le client HTTP à la première erreur réseau.
  void markOffline() => _set(false);

  @override
  Future<bool> check() async {
    try {
      final r = await _client.get(healthUrl, headers: {'apikey': apiKey}).timeout(const Duration(seconds: 4));
      _set(r.statusCode < 500);
    } catch (_) {
      _set(false);
    }
    return _online;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_online ? onlineInterval : offlineInterval, () async {
      await check();
      _schedule();
    });
  }

  void start() {
    check();
    _schedule();
  }

  void dispose() {
    _timer?.cancel();
    _changes.close();
  }
}
