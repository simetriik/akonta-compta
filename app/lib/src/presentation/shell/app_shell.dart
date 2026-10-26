import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../data/auth_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';

/// Gabarit commun : barre supérieure + rail de navigation (desktop) ou tiroir (mobile), dossier courant toujours visible (§12.3).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    (route: '/', icon: Icons.space_dashboard_outlined, label: 'Tableau de bord', perm: null, admin: false),
    (route: '/dossiers', icon: Icons.folder_open_outlined, label: 'Dossiers', perm: 'entities.manage', admin: false),
    (route: '/saisie', icon: Icons.edit_square, label: 'Saisie', perm: 'entries.draft', admin: false),
    (route: '/consultation', icon: Icons.menu_book_outlined, label: 'Consultation', perm: 'ledger.read', admin: false),
    (route: '/pieces', icon: Icons.receipt_long_outlined, label: 'Pièces', perm: 'documents.attach', admin: false),
    (route: '/lettrage', icon: Icons.link_outlined, label: 'Lettrage', perm: 'lettering.manage', admin: false),
    (route: '/rapprochement', icon: Icons.account_balance_outlined, label: 'Rapprochement', perm: 'reconciliation.manage', admin: false),
    (route: '/inventaire', icon: Icons.inventory_2_outlined, label: 'Inventaire', perm: 'inventory.prepare', admin: false),
    (route: '/cloture', icon: Icons.lock_clock_outlined, label: 'Clôture', perm: 'closing.provisional', admin: false),
    (route: '/referentiels', icon: Icons.account_tree_outlined, label: 'Référentiels', perm: 'references.manage', admin: false),
    (route: '/import', icon: Icons.upload_file_outlined, label: 'Import Perfecto', perm: 'import.perfecto', admin: false),
    (route: '/cabinet', icon: Icons.apartment_outlined, label: 'Cabinet', perm: 'cabinet.settings', admin: true),
    (route: '/utilisateurs', icon: Icons.manage_accounts_outlined, label: 'Utilisateurs', perm: 'users.manage', admin: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jeton encore valide mais compte disparu (supprimé, ou base de démo rechargée) : on déconnecte
    // plutôt que d'afficher un gabarit vide.
    final profileState = ref.watch(currentProfileProvider);
    if (profileState.hasValue && profileState.value == null && ref.watch(currentUserProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authRepositoryProvider).signOut());
    }
    final t = context.ak;
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

    void signOut() => ref.read(authRepositoryProvider).signOut();

    if (wide) {
      return Scaffold(
        body: Column(
          children: [
            _TopBar(entity: entity, profile: profile, onSignOut: signOut),
            Expanded(
              child: Row(
                children: [
                  _Rail(items: visible, selected: selected, onSelect: (d) => context.go(d.route)),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AkSpace.s2,
        title: Row(
          children: [
            const AkLogo(height: 28, symbolOnly: true),
            const SizedBox(width: AkSpace.s2),
            Expanded(child: _CurrentEntitySelector(entity: entity, mobile: true)),
          ],
        ),
        actions: [
          if (profile != null) _UserMenu(profile: profile, onSignOut: signOut, compact: true),
        ],
      ),
      drawer: Drawer(
        backgroundColor: t.surface,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.all(AkSpace.s4), child: Align(alignment: Alignment.centerLeft, child: AkLogo(height: 36))),
              Divider(color: t.border),
              Expanded(
                child: _Rail(
                  items: visible,
                  selected: selected,
                  bordered: false,
                  onSelect: (d) {
                    Navigator.pop(context);
                    context.go(d.route);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: child,
    );
  }
}

typedef _Dest = ({String route, IconData icon, String label, String? perm, bool admin});

/// Rail de navigation : icône + libellé, entrée active teintée, section Administration séparée.
class _Rail extends StatelessWidget {
  const _Rail({required this.items, required this.selected, required this.onSelect, this.bordered = true});

  final List<_Dest> items;
  final int selected;
  final ValueChanged<_Dest> onSelect;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final main = [for (var i = 0; i < items.length; i++) if (!items[i].admin) i];
    final admin = [for (var i = 0; i < items.length; i++) if (items[i].admin) i];
    Widget tile(int i) => _RailItem(dest: items[i], active: i == selected, onTap: () => onSelect(items[i]));
    return Container(
      width: bordered ? AkSpace.railWidth : null,
      decoration: BoxDecoration(color: t.surface, border: bordered ? Border(right: BorderSide(color: t.border)) : null),
      child: ListView(
        padding: const EdgeInsets.all(AkSpace.s2),
        children: [
          for (final i in main) tile(i),
          if (admin.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Divider(height: 1, color: t.border)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
              child: Text('Administration', style: AkText.label.copyWith(fontSize: 11, color: t.textMuted)),
            ),
            for (final i in admin) tile(i),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.dest, required this.active, required this.onTap});

  final _Dest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final color = active ? t.brandText : t.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? t.brandTint : Colors.transparent,
        borderRadius: AkRadius.mdAll,
        child: InkWell(
          borderRadius: AkRadius.mdAll,
          hoverColor: t.surfaceHover,
          onTap: onTap,
          child: Semantics(
            selected: active,
            button: true,
            child: SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(dest.icon, size: 20, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dest.label,
                        overflow: TextOverflow.ellipsis,
                        style: AkText.table.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre supérieure desktop : logo, dossier courant, alertes, menu utilisateur.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.entity, required this.profile, required this.onSignOut});

  final EntitySummary? entity;
  final Profile? profile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final toCorrect = entity?.toCorrectCount ?? 0;
    return Container(
      height: AkSpace.topbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          const AkLogo(height: 32),
          const SizedBox(width: AkSpace.s6),
          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _CurrentEntitySelector(entity: entity))),
          const Spacer(),
          if (toCorrect > 0)
            Tooltip(
              message: '$toCorrect écriture(s) à corriger',
              child: IconButton(
                onPressed: () => context.go('/saisie'),
                icon: Badge(
                  label: Text('$toCorrect'),
                  backgroundColor: t.danger,
                  textColor: t.surface,
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
          if (profile != null) _UserMenu(profile: profile!, onSignOut: onSignOut),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.profile, required this.onSignOut, this.compact = false});

  final Profile profile;
  final VoidCallback onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final name = profile.fullName.isEmpty ? profile.email : profile.fullName;
    return PopupMenuButton<String>(
      tooltip: 'Menu utilisateur',
      offset: const Offset(0, 44),
      onSelected: (_) => onSignOut(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Se déconnecter')])),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AkAvatar(name),
            if (!compact) ...[
              const SizedBox(width: AkSpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: AkText.table.copyWith(color: t.text, fontWeight: FontWeight.w600)),
                  if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty)
                    Text(profile.jobTitle!, style: AkText.caption.copyWith(fontSize: 11, color: t.textMuted)),
                ],
              ),
            ],
            Icon(Icons.expand_more, size: 18, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur du dossier courant (entité + exercice), visible dans la barre supérieure.
class _CurrentEntitySelector extends ConsumerWidget {
  const _CurrentEntitySelector({required this.entity, this.mobile = false});

  final EntitySummary? entity;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final entities = ref.watch(entityDashboardProvider).value ?? const <EntitySummary>[];
    final current = entities.where((e) => e.id == entity?.id).firstOrNull;   // dossier absent de la liste (changement d'utilisateur)
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderControl), borderRadius: AkRadius.mdAll),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('current-entity'),
          isExpanded: true,
          isDense: true,
          dropdownColor: t.surface,
          borderRadius: AkRadius.mdAll,
          icon: Icon(Icons.expand_more, size: 18, color: t.textMuted),
          value: current?.id,
          hint: Text('Choisir un dossier', style: AkText.table.copyWith(color: t.textMuted)),
          selectedItemBuilder: (_) => [
            for (final e in entities)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mobile) Text('Dossier courant', style: AkText.label.copyWith(fontSize: 11, height: 14 / 11, color: t.textMuted)),
                  Text(e.dossierLabel, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text, fontWeight: FontWeight.w600)),
                ],
              ),
          ],
          items: [
            for (final e in entities)
              DropdownMenuItem(value: e.id, child: Text(e.dossierLabel, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
          ],
          onChanged: (id) => ref.read(currentEntityProvider.notifier).select(entities.where((e) => e.id == id).firstOrNull),
        ),
      ),
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
