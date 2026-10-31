import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/offline/response_cache.dart';
import 'package:akonta/src/infrastructure/local/local_response_cache.dart';
import 'package:akonta/src/infrastructure/supabase/offline_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Net implements ConnectivityPort {
  _Net() : online = true;

  bool online;

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> check() async => online;
}

String jwt(String sub) {
  String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return 'Bearer ${enc({'alg': 'none'})}.${enc({'sub': sub})}.sig';
}

void main() {
  late _Net net;
  late InMemoryResponseCache cache;
  late int calls;
  late bool serverDown;
  late int offlineSignals;
  late OfflineHttpClient client;

  setUp(() {
    net = _Net();
    cache = InMemoryResponseCache();
    calls = 0;
    serverDown = false;
    offlineSignals = 0;
    final inner = MockClient((request) async {
      calls++;
      if (serverDown) throw http.ClientException('Failed to fetch', request.url);
      return http.Response(jsonEncode([{'id': 1, 'path': request.url.path}]), 200, headers: {'content-type': 'application/json'});
    });
    client = OfflineHttpClient(inner, cache: cache, connectivity: net, onOffline: () {
      offlineSignals++;
      net.online = false;
    });
  });

  final accounts = Uri.parse('https://x.test/rest/v1/accounts?select=*');

  Future<http.Response> get(Uri uri, {String user = 'u1'}) async => http.Response.fromStream(await client.send(http.Request('GET', uri)..headers['authorization'] = jwt(user)));

  test('en ligne, la lecture passe par le serveur', () async {
    final r = await get(accounts);
    expect(r.statusCode, 200);
    expect(r.headers['x-akonta-offline-cache'], isNull);
    expect(calls, 1);
  });

  test('serveur injoignable : la dernière lecture de ce même utilisateur est renvoyée et l\'appareil passe hors ligne', () async {
    await get(accounts);
    serverDown = true;
    final r = await get(accounts);
    expect(r.statusCode, 200);
    expect(r.headers['x-akonta-offline-cache'], '1');
    expect(jsonDecode(r.body), [{'id': 1, 'path': '/rest/v1/accounts'}]);
    expect(offlineSignals, 1);
  });

  test('hors ligne, aucune requête n\'est tentée : le cache répond directement', () async {
    await get(accounts);
    net.online = false;
    final before = calls;
    final r = await get(accounts);
    expect(calls, before);
    expect(r.headers['x-akonta-offline-cache'], '1');
  });

  test('le cache est propre à chaque utilisateur', () async {
    await get(accounts, user: 'u1');
    net.online = false;
    await expectLater(get(accounts, user: 'u2'), throwsA(isA<http.ClientException>()));
  });

  test('une lecture jamais effectuée est refusée avec un message clair', () async {
    net.online = false;
    await expectLater(get(Uri.parse('https://x.test/rest/v1/never')), throwsA(isA<http.ClientException>().having((e) => e.message, 'message', contains('Hors connexion'))));
  });

  test('hors ligne, une écriture est refusée sans attendre ; en ligne elle passe', () async {
    final write = http.Request('POST', Uri.parse('https://x.test/rest/v1/entries'))..body = '{}';
    final ok = await http.Response.fromStream(await client.send(write));
    expect(ok.statusCode, 200);
    net.online = false;
    final before = calls;
    await expectLater(client.send(http.Request('POST', Uri.parse('https://x.test/rest/v1/entries'))), throwsA(isA<http.ClientException>()));
    expect(calls, before);
  });

  test('un calcul (fonction SQL) n\'est jamais servi depuis le cache, la liste des dossiers l\'est', () async {
    final ledger = Uri.parse('https://x.test/rest/v1/rpc/general_ledger');
    final dashboard = Uri.parse('https://x.test/rest/v1/rpc/entity_dashboard');
    Future<http.Response> post(Uri u) async => http.Response.fromStream(await client.send(http.Request('POST', u)..headers['authorization'] = jwt('u1')));
    await post(ledger);
    await post(dashboard);
    net.online = false;
    await expectLater(post(ledger), throwsA(isA<http.ClientException>()));
    expect((await post(dashboard)).headers['x-akonta-offline-cache'], '1');
  });

  test('l\'authentification et le stockage ne passent jamais par le cache', () async {
    final auth = Uri.parse('https://x.test/auth/v1/token');
    await client.send(http.Request('POST', auth));
    net.online = false;
    final r = await client.send(http.Request('POST', auth));
    expect(r.statusCode, 200); // directement au serveur, sans refus anticipé ni cache
  });

  test('une réponse d\'erreur du serveur n\'est pas conservée', () async {
    final failing = OfflineHttpClient(MockClient((_) async => http.Response('{"message":"x"}', 500)), cache: cache, connectivity: net, onOffline: () {});
    final r = await http.Response.fromStream(await failing.send(http.Request('GET', accounts)));
    expect(r.statusCode, 500);
    net.online = false;
    await expectLater(failing.send(http.Request('GET', accounts)), throwsA(isA<http.ClientException>()));
  });

  test('délai dépassé : traité comme un défaut de connexion', () async {
    final slow = OfflineHttpClient(MockClient((_) => Completer<http.Response>().future), cache: cache, connectivity: net, onOffline: () => offlineSignals++, timeout: const Duration(milliseconds: 20));
    await expectLater(slow.send(http.Request('GET', accounts)), throwsA(isA<http.ClientException>()));
    expect(offlineSignals, 1);
  });

  test('le cache en mémoire conserve et vide', () async {
    await cache.write('k', CachedResponse(status: 200, headers: const {'a': 'b'}, body: Uint8List.fromList([1, 2])));
    expect((await cache.read('k'))!.body, [1, 2]);
    await cache.clear();
    expect(await cache.read('k'), isNull);
  });
}
