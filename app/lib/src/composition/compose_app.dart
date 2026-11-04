import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/offline/in_memory_outbox.dart';
import '../application/offline/response_cache.dart';
import '../application/providers/session_providers.dart' show lastEntityStoreProvider;
import '../application/providers/live_refresh_providers.dart';
import '../application/providers/repositories.dart';
import '../application/providers/services.dart';
import '../core/config.dart';
import '../domain/repositories/outbox_repository.dart';
import '../infrastructure/local/local_database_opener.dart';
import '../infrastructure/local/local_outbox_repository.dart';
import '../infrastructure/local/local_response_cache.dart';
import '../infrastructure/local/shared_prefs_last_entity_store.dart';
import '../infrastructure/supabase/offline_http_client.dart';
import '../infrastructure/supabase/reachability_monitor.dart';
import '../infrastructure/supabase/supabase_change_feed.dart';
import 'supabase_overrides.dart';

/// Résultat de la composition : remplacements de providers à passer au `ProviderScope`.
class AppComposition {
  const AppComposition({required this.overrides});

  final List<Override> overrides;
}

/// Racine de composition : choisit les adaptateurs (Supabase, base locale chiffrée ou mémoire), initialise le client de données et
/// branche le moniteur de connexion. C'est le seul endroit qui connaît à la fois les ports et leurs implémentations.
Future<AppComposition> composeApp() async {
  registerSupabaseErrorClassifier();

  // Stockage local : base chiffrée sur ordinateur et mobile ; mémoire sur le web ou si la clé de chiffrement est indisponible.
  final database = await openLocalDatabase();
  final ResponseCache cache = database == null ? InMemoryResponseCache() : LocalResponseCache(database);
  final OutboxRepository outbox = database == null ? InMemoryOutboxRepository() : LocalOutboxRepository(database);

  final monitor = ReachabilityMonitor(healthUrl: Uri.parse('${AppConfig.supabaseUrl}/auth/v1/health'), apiKey: AppConfig.supabasePublishableKey);
  final client = OfflineHttpClient(http.Client(), cache: cache, connectivity: monitor, onOffline: monitor.markOffline);

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
    httpClient: client,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  // Les lectures conservées sont propres à l'utilisateur ; elles sont aussi effacées à sa déconnexion.
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut) cache.clear();
  });
  monitor.start();

  return AppComposition(overrides: [
    ...supabaseOverrides(),
    connectivityProvider.overrideWithValue(monitor),
    changeFeedProvider.overrideWithValue(SupabaseChangeFeed(Supabase.instance.client)),
    outboxRepositoryProvider.overrideWithValue(outbox),
    lastEntityStoreProvider.overrideWithValue(SharedPrefsLastEntityStore(await SharedPreferences.getInstance())),
  ]);
}
