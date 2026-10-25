import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/auth_repository.dart';
import 'data/supabase_providers.dart';
import 'presentation/auth/inactivity_watcher.dart';
import 'presentation/router.dart';

/// Application Akonta : thème, français, routeur, déconnexion pour inactivité.
class AkontaApp extends ConsumerWidget {
  const AkontaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final signedIn = ref.watch(currentUserProvider) != null;
    final minutes = ref.watch(currentCabinetProvider).value?.inactivityMinutes ?? AppConfig.defaultInactivityMinutes;
    return MaterialApp.router(
      title: 'Akonta',
      theme: buildAkontaTheme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => InactivityWatcher(
        enabled: signedIn,
        timeout: Duration(minutes: minutes),
        onTimeout: () => ref.read(authRepositoryProvider).signOut(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
