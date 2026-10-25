import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import '../data/supabase_providers.dart';
import 'admin/cabinet_screen.dart';
import 'admin/users_screen.dart';
import 'auth/login_screen.dart';
import 'auth/mfa_screens.dart';
import 'dashboard/dashboard_screen.dart';
import 'entities/entities_screen.dart';
import 'entities/entity_detail_screen.dart';
import 'entities/entity_wizard_screen.dart';
import 'references/references_screen.dart';
import 'shell/app_shell.dart';

/// Rafraîchit le routeur à chaque changement de session.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Routes : connexion → (défi ou enrôlement TOTP) → gabarit avec modules.
final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final listenable = _AuthListenable(client.auth.onAuthStateChange);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) async {
      final signedIn = client.auth.currentSession != null;
      final onLogin = state.matchedLocation == '/connexion';
      if (!signedIn) return onLogin ? null : '/connexion';
      if (onLogin) return '/';
      // MFA : défi si un facteur est enrôlé ; enrôlement forcé pour les rôles qui l'exigent.
      final onMfa = state.matchedLocation.startsWith('/mfa');
      final status = await ref.read(mfaStatusProvider.future);
      if (status != null) {
        if (status.challengeRequired) return onMfa ? null : '/mfa/verification';
        if (!status.hasVerifiedTotp) {
          final perms = await ref.read(permissionsProvider.future);
          if (perms.requiresMfa) return state.matchedLocation == '/mfa/activation' ? null : '/mfa/activation';
        }
      }
      if (onMfa) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/connexion', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/mfa/verification', builder: (context, _) => MfaChallengeScreen(onVerified: () => context.go('/'))),
      GoRoute(path: '/mfa/activation', builder: (context, _) => MfaEnrollScreen(mandatory: true, onDone: () => context.go('/'))),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/dossiers', builder: (_, _) => const EntitiesScreen()),
          GoRoute(path: '/dossiers/nouveau', builder: (_, _) => const EntityWizardScreen()),
          GoRoute(path: '/dossiers/:id', builder: (_, state) => EntityDetailScreen(entityId: state.pathParameters['id']!)),
          GoRoute(path: '/saisie', builder: (_, _) => const PlaceholderScreen(title: 'Saisie')),
          GoRoute(path: '/consultation', builder: (_, _) => const PlaceholderScreen(title: 'Consultation')),
          GoRoute(path: '/pieces', builder: (_, _) => const PlaceholderScreen(title: 'Pièces justificatives')),
          GoRoute(path: '/referentiels', builder: (_, _) => const ReferencesScreen()),
          GoRoute(path: '/import', builder: (_, _) => const PlaceholderScreen(title: 'Import Perfecto')),
          GoRoute(path: '/cabinet', builder: (_, _) => const CabinetScreen()),
          GoRoute(path: '/utilisateurs', builder: (_, _) => const UsersScreen()),
        ],
      ),
    ],
  );
});
