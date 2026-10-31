import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config.dart';
import 'src/composition/supabase_overrides.dart';
import 'src/core/errors/errors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerSupabaseErrorClassifier();
  installErrorHooks();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  runApp(ProviderScope(overrides: supabaseOverrides(), child: const AkontaApp()));
}
