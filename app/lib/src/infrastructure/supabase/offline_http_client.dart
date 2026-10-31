import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../application/connectivity/connectivity.dart';
import '../../application/offline/response_cache.dart';
import '../../core/errors/errors.dart';

/// Client HTTP des appels Supabase avec cache de lecture hors connexion.
///
/// - Lecture (GET sur l'API de données, et quelques fonctions de lecture) : la réponse est conservée ; sans connexion, la dernière
///   réponse conservée pour la même requête et le même utilisateur est renvoyée.
/// - Toute autre requête (écriture, calcul) sans connexion : refus immédiat, sans attente.
/// - Le cache est propre à l'utilisateur : la clé contient son identifiant, extrait du jeton.
class OfflineHttpClient extends http.BaseClient {
  OfflineHttpClient(this._inner, {required this.cache, required this.connectivity, required this.onOffline, this.timeout = const Duration(seconds: 20)});

  final http.Client _inner;
  final ResponseCache cache;
  final ConnectivityPort connectivity;
  final void Function() onOffline;
  final Duration timeout;

  /// Fonctions SQL de lecture dont le résultat peut être relu hors connexion.
  static const cacheableRpc = {'entity_dashboard'};

  static bool _isData(Uri u) => u.path.contains('/rest/v1/');

  static bool _isCacheable(http.BaseRequest r) {
    if (!_isData(r.url)) return false;
    if (r.method == 'GET') return true;
    if (r.method == 'POST') {
      final i = r.url.pathSegments.indexOf('rpc');
      return i >= 0 && i + 1 < r.url.pathSegments.length && cacheableRpc.contains(r.url.pathSegments[i + 1]);
    }
    return false;
  }

  static String? _subject(String? authorization) {
    if (authorization == null || !authorization.startsWith('Bearer ')) return null;
    final parts = authorization.substring(7).split('.');
    if (parts.length < 2) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String _key(http.BaseRequest r) {
    final body = r is http.Request ? r.body : '';
    final raw = '${r.method} ${r.url} ${r.headers['accept'] ?? ''} ${r.headers['range'] ?? ''} ${_subject(r.headers['authorization']) ?? 'anonyme'} $body';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static bool _isNetworkFailure(Object e) => e is TimeoutException || e is http.ClientException || looksLikeNetworkFailure(e.toString());

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isData(request.url)) return _inner.send(request);
    if (!_isCacheable(request)) {
      if (!connectivity.isOnline) throw http.ClientException('Hors connexion', request.url);
      try {
        return await _inner.send(request).timeout(timeout);
      } catch (e) {
        if (_isNetworkFailure(e)) onOffline();
        rethrow;
      }
    }
    final key = _key(request);
    if (connectivity.isOnline) {
      try {
        final response = await _inner.send(request).timeout(timeout);
        if (response.statusCode != 200) return response;
        final bytes = await response.stream.toBytes();
        await cache.write(key, CachedResponse(status: 200, headers: response.headers, body: bytes));
        return http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length, request: request, headers: response.headers, reasonPhrase: response.reasonPhrase);
      } catch (e) {
        if (!_isNetworkFailure(e)) rethrow;
        onOffline();
      }
    }
    final hit = await cache.read(key);
    if (hit == null) throw http.ClientException('Hors connexion : donnée non disponible sur cet appareil', request.url);
    return http.StreamedResponse(Stream.value(hit.body), hit.status, contentLength: hit.body.length, request: request, headers: {...hit.headers, 'x-akonta-offline-cache': '1'});
  }
}
