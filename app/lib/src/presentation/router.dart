import 'dart:async';

import 'package:akonta/design/catalog/catalog_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/supabase_providers.dart';
import 'admin/cabinet_screen.dart';
import 'admin/users_screen.dart';
import 'auth/login_screen.dart';
import 'auth/mfa_screens.dart';
import 'consultation/consultation_screen.dart';
import 'closing/closing_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'entities/entities_screen.dart';
import 'entries/entries_screen.dart';
import 'entries/entry_editor_screen.dart';
import 'entities/entity_detail_screen.dart';
import 'entities/entity_wizard_screen.dart';
import 'imports/import_screen.dart';
import 'inventory/inventory_screen.dart';
import 'lettering/lettering_screen.dart';
import 'reconciliation/reconciliation_screen.dart';
import 'references/references_screen.dart';
import 'shell/app_shell.dart';

/// Rafraîchit le routeur quand la session change de nature (connexion, déconnexion, TOTP vérifié),
/// pas à chaque rafraîchissement de jeton.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Stream<AuthState> stream) {
    _sub = stream.listen((state) {
      if (state.event != AuthChangeEvent.tokenRefreshed) notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Le catalogue du système de design n'existe qu'en mode développement.
final bool _devCatalog = kDebugMode || const bool.fromEnvironment('AK_DEV');

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
      if (_devCatalog && state.matchedLocation == '/catalogue') return null;
      if (!signedIn) return onLogin ? null : '/connexion';
      if (onLogin) return '/';
      // MFA : défi si un facteur est enrôlé ; enrôlement forcé pour les rôles qui l'exigent.
      // Statut lu directement sur la session (synchrone) : passer par un provider asynchrone
      // laissait la redirection initiale en attente au chargement à froid d'une URL profonde.
      final onMfa = state.matchedLocation.startsWith('/mfa');
      final status = await ref.read(authRepositoryProvider).mfaStatus();
      if (status.challengeRequired) return onMfa ? null : '/mfa/verification';
      if (!status.hasVerifiedTotp) {
        final perms = await ref.read(permissionsProvider.future);
        if (perms.requiresMfa) return state.matchedLocation == '/mfa/activation' ? null : '/mfa/activation';
      }
      if (onMfa) return '/';
      return null;
    },
    routes: [
      // Catalogue du système de design : mode développement seulement.
      if (_devCatalog) GoRoute(path: '/catalogue', builder: (_, _) => const CatalogScreen()),
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
          GoRoute(path: '/saisie', builder: (_, _) => const EntriesScreen()),
          GoRoute(path: '/saisie/nouvelle', builder: (_, _) => const EntryEditorScreen()),
          GoRoute(path: '/saisie/:id', builder: (_, state) => EntryEditorScreen(entryId: state.pathParameters['id']!)),
          GoRoute(path: '/consultation', builder: (_, _) => const ConsultationScreen()),
          GoRoute(path: '/pieces', builder: (_, _) => const DocumentsScreen()),
          GoRoute(path: '/lettrage', builder: (_, _) => const LetteringScreen()),
          GoRoute(path: '/rapprochement', builder: (_, _) => const ReconciliationScreen()),
          GoRoute(path: '/inventaire', builder: (_, _) => const InventoryScreen()),
          GoRoute(path: '/cloture', builder: (_, _) => const ClosingScreen()),
          GoRoute(path: '/referentiels', builder: (_, _) => const ReferencesScreen()),
          GoRoute(path: '/import', builder: (_, _) => const ImportScreen()),
          GoRoute(path: '/cabinet', builder: (_, _) => const CabinetScreen()),
          GoRoute(path: '/utilisateurs', builder: (_, _) => const UsersScreen()),
        ],
      ),
    ],
  );
});
