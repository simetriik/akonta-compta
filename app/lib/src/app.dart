import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import 'core/config.dart';
import 'presentation/auth/inactivity_watcher.dart';
import 'presentation/router.dart';
import 'application/providers/repositories.dart';
import 'application/providers/session_providers.dart';

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
      darkTheme: buildAkontaDarkTheme(),
      themeMode: ThemeMode.system,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        // Écrans de moins de 900 px : contrôles tactiles de 48 px (système de design).
        final touch = MediaQuery.sizeOf(context).width < AkBreakpoint.expanded;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: dark ? buildAkontaDarkTheme(touch: touch) : buildAkontaTheme(touch: touch),
          child: InactivityWatcher(
            enabled: signedIn,
            timeout: Duration(minutes: minutes),
            onTimeout: () => ref.read(authRepositoryProvider).signOut(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
