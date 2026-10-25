import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../widgets/akonta_logo.dart';

/// Gabarit commun : navigation latérale (desktop) ou tiroir (mobile), dossier courant toujours visible (§12.3).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    (route: '/', icon: Icons.dashboard_outlined, label: 'Tableau de bord', perm: null),
    (route: '/dossiers', icon: Icons.folder_copy_outlined, label: 'Dossiers', perm: 'entities.manage'),
    (route: '/saisie', icon: Icons.edit_note_outlined, label: 'Saisie', perm: 'entries.draft'),
    (route: '/consultation', icon: Icons.menu_book_outlined, label: 'Consultation', perm: 'ledger.read'),
    (route: '/pieces', icon: Icons.attach_file_outlined, label: 'Pièces', perm: 'documents.attach'),
    (route: '/lettrage', icon: Icons.link_outlined, label: 'Lettrage', perm: 'lettering.manage'),
    (route: '/rapprochement', icon: Icons.account_balance_outlined, label: 'Rapprochement', perm: 'reconciliation.manage'),
    (route: '/inventaire', icon: Icons.inventory_2_outlined, label: 'Inventaire', perm: 'inventory.prepare'),
    (route: '/cloture', icon: Icons.lock_clock_outlined, label: 'Clôture', perm: 'closing.provisional'),
    (route: '/referentiels', icon: Icons.account_tree_outlined, label: 'Référentiels', perm: 'references.manage'),
    (route: '/import', icon: Icons.upload_file_outlined, label: 'Import Perfecto', perm: 'import.perfecto'),
    (route: '/cabinet', icon: Icons.business_outlined, label: 'Cabinet', perm: 'cabinet.settings'),
    (route: '/utilisateurs', icon: Icons.manage_accounts_outlined, label: 'Utilisateurs', perm: 'users.manage'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jeton encore valide mais compte disparu (supprimé, ou base de démo rechargée) : on déconnecte
    // plutôt que d'afficher un gabarit vide.
    final profileState = ref.watch(currentProfileProvider);
    if (profileState.hasValue && profileState.value == null && ref.watch(currentUserProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authRepositoryProvider).signOut());
    }
    final location = GoRouterState.of(context).uri.path;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final entity = ref.watch(currentEntityProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final visible = destinations.where((d) {
      final p = d.perm;
      if (p == null) return true;
      if (perms.cabinetWide.contains(p)) return true;
      return perms.byEntity.values.any((set) => set.contains(p));
    }).toList();
    final selected = visible.indexWhere((d) => d.route == '/' ? location == '/' : location.startsWith(d.route));
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final rail = NavigationRail(
      selectedIndex: selected < 0 ? 0 : selected,
      extended: wide,
      minExtendedWidth: 200,
      backgroundColor: Colors.white,
      leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AkontaLogo(height: 36, withWordmark: false)),
      onDestinationSelected: (i) => context.go(visible[i].route),
      destinations: [for (final d in visible) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label))],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (!wide) const AkontaLogo(height: 28, withWordmark: false),
            if (!wide) const SizedBox(width: 8),
            Expanded(child: _CurrentEntitySelector(entity: entity)),
          ],
        ),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(profile.fullName.isEmpty ? profile.email : profile.fullName, style: const TextStyle(fontSize: 13))),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: ListView(
                children: [
                  const DrawerHeader(child: AkontaLogo(height: 40)),
                  for (final d in visible)
                    ListTile(
                      leading: Icon(d.icon),
                      title: Text(d.label),
                      selected: visible.indexOf(d) == selected,
                      onTap: () {
                        Navigator.pop(context);
                        context.go(d.route);
                      },
                    ),
                ],
              ),
            ),
      body: Row(
        children: [
          if (wide) rail,
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sélecteur du dossier courant (entité + exercice), visible dans la barre supérieure.
class _CurrentEntitySelector extends ConsumerWidget {
  const _CurrentEntitySelector({required this.entity});

  final EntitySummary? entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entityDashboardProvider).value ?? const <EntitySummary>[];
    return Row(
      children: [
        const Icon(Icons.folder_open, size: 20, color: AkColors.terracotta),
        const SizedBox(width: 8),
        Flexible(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('current-entity'),
              isExpanded: true,
              value: entities.any((e) => e.id == entity?.id) ? entity?.id : null,   // dossier absent de la liste (changement d'utilisateur)
              hint: const Text('Choisir un dossier', style: TextStyle(fontSize: 14)),
              items: [
                for (final e in entities)
                  DropdownMenuItem(value: e.id, child: Text(e.dossierLabel, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
              ],
              onChanged: (id) => ref.read(currentEntityProvider.notifier).select(entities.where((e) => e.id == id).firstOrNull),
            ),
          ),
        ),
      ],
    );
  }
}

/// Écran provisoire d'un module non encore livré.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title — à venir', style: Theme.of(context).textTheme.titleMedium));
  }
}
