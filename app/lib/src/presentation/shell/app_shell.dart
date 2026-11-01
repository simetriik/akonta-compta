import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../domain/models.dart';
import '../../application/providers/repositories.dart';
import '../../application/providers/session_providers.dart';
import 'offline_gate.dart';
import '../auth/change_password.dart';

/// Gabarit commun : rail de navigation bleu nuit (étendu au bureau, réduit sur tablette, barre basse sur mobile)
/// et barre supérieure avec le dossier courant toujours visible, ouvrable par Ctrl K (§12.3).
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
    (route: '/utilisateurs', icon: Icons.manage_accounts_outlined, label: 'Collaborateurs', perm: 'users.manage', admin: true),
    (route: '/journal-erreurs', icon: Icons.bug_report_outlined, label: 'Journal des erreurs', perm: techAdminOnly, admin: true),
  ];

  /// Pseudo-permission : l'entrée n'apparaît que pour l'administrateur technique (rôle `tech_admin`).
  static const techAdminOnly = 'tech.errors';

  /// Entrées de la barre basse mobile (libellés courts pour tenir sur 360 px).
  static const _mobileBar = [('/pieces', 'Pièces'), ('/', 'Accueil'), ('/saisie', 'Saisie'), ('/consultation', 'Consulter')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jeton encore valide mais compte disparu (supprimé, ou base de démo rechargée) : on déconnecte
    // plutôt que d'afficher un gabarit vide.
    final profileState = ref.watch(currentProfileProvider);
    if (profileState.hasValue && profileState.value == null && ref.watch(currentUserProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authRepositoryProvider).signOut());
    }
    // Un seul dossier accessible (ou dossier qui vient d'être créé) : on le choisit à la place de l'utilisateur.
    final accessible = ref.watch(entityDashboardProvider).value;
    if (accessible != null && accessible.length == 1 && ref.watch(currentEntityProvider) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(currentEntityProvider) == null) ref.read(currentEntityProvider.notifier).select(accessible.first);
      });
    }
    final t = context.ak;
    final location = GoRouterState.of(context).uri.path;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final entity = ref.watch(currentEntityProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final visible = destinations.where((d) {
      final p = d.perm;
      if (p == null) return true;
      if (p == techAdminOnly) return perms.roles.any((r) => r.code == 'tech_admin');
      if (perms.cabinetWide.contains(p)) return true;
      return perms.byEntity.values.any((set) => set.contains(p));
    }).toList();
    final selected = visible.indexWhere((d) => d.route == '/' ? location == '/' : location.startsWith(d.route));
    final width = MediaQuery.sizeOf(context).width;

    void signOut() => ref.read(authRepositoryProvider).signOut();
    Future<void> pickEntity() => _pickEntity(context, ref, entity);

    Widget withShortcut(Widget body) => CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyK, control: true): pickEntity},
      child: Focus(autofocus: true, child: body),
    );

    // Bureau et tablette : rail à gauche sur toute la hauteur, barre haute et contenu à droite.
    if (width >= AkBreakpoint.medium) {
      final collapsed = width < AkBreakpoint.expanded;
      return withShortcut(
        Scaffold(
          body: Row(
            children: [
              _Rail(items: visible, selected: selected, collapsed: collapsed, onSelect: (d) => context.go(d.route)),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(entity: entity, profile: profile, onSignOut: signOut, onPick: pickEntity),
                    Expanded(child: OfflineGate(location: location, child: child)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return withShortcut(
      Scaffold(
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
          backgroundColor: t.railBg,
          shape: const RoundedRectangleBorder(),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AkSpace.s4),
                  child: Align(alignment: Alignment.centerLeft, child: AkLogo(height: 36, tone: AkLogoTone.onDark)),
                ),
                Expanded(
                  child: _Rail(
                    items: visible,
                    selected: selected,
                    bordered: false,
                    showLogo: false,
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
        body: OfflineGate(location: location, child: child),
        // Mobile : barre d'onglets basse sur le fond du rail, centrée sur la capture des pièces ; le reste est dans le tiroir.
        bottomNavigationBar: Builder(
          builder: (context) {
            final items = [
              for (final (route, short) in _mobileBar)
                for (final d in visible.where((d) => d.route == route)) (d, short),
            ];
            final current = items.indexWhere((e) => e.$1.route == '/' ? location == '/' : location.startsWith(e.$1.route));
            return NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: t.railBg,
                indicatorColor: t.railActiveBg,
                surfaceTintColor: Colors.transparent,
                iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? t.railActiveText : t.railText)),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (s) => AkText.label.copyWith(color: s.contains(WidgetState.selected) ? t.railActiveText : t.railText),
                ),
              ),
              child: NavigationBar(
                height: 64,
                selectedIndex: current < 0 ? items.length : current,
                onDestinationSelected: (i) => i == items.length ? Scaffold.of(context).openDrawer() : context.go(items[i].$1.route),
                destinations: [
                  for (final (d, short) in items) NavigationDestination(icon: Icon(d.icon), label: short),
                  const NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Recherche d'un dossier (Ctrl K) : filtre par nom ou exercice, Entrée choisit la première proposition.
Future<void> _pickEntity(BuildContext context, WidgetRef ref, EntitySummary? current) async {
  final entities = ref.read(entityDashboardProvider).value ?? const <EntitySummary>[];
  if (entities.isEmpty) return;
  final picked = await showDialog<EntitySummary>(
    context: context,
    builder: (_) => _EntityPickerDialog(entities: entities, currentId: current?.id),
  );
  if (picked != null) ref.read(currentEntityProvider.notifier).select(picked);
}

class _EntityPickerDialog extends StatefulWidget {
  const _EntityPickerDialog({required this.entities, this.currentId});

  final List<EntitySummary> entities;
  final String? currentId;

  @override
  State<_EntityPickerDialog> createState() => _EntityPickerDialogState();
}

class _EntityPickerDialogState extends State<_EntityPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final q = _query.trim().toLowerCase();
    final found = [for (final e in widget.entities) if (q.isEmpty || e.dossierLabel.toLowerCase().contains(q)) e];
    return AkDialog(
      title: 'Changer de dossier',
      size: AkDialogSize.m,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(
            autofocus: true,
            hint: 'Rechercher un dossier',
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) {
              if (found.isNotEmpty) Navigator.pop(context, found.first);
            },
          ),
          const SizedBox(height: AkSpace.s3),
          if (found.isEmpty)
            const AkEmptyState('Aucun dossier ne correspond.')
          else
            for (final e in found)
              InkWell(
                borderRadius: AkRadius.mdAll,
                hoverColor: t.surfaceHover,
                onTap: () => Navigator.pop(context, e),
                child: Container(
                  constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowComfort),
                  padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(child: Text(e.dossierLabel, style: AkText.body.copyWith(color: t.text))),
                      if (e.id == widget.currentId) Icon(Icons.check, size: AkSpace.iconMd, color: t.textStrong),
                    ],
                  ),
                ),
              ),
        ],
      ),
      actions: [AkButton.secondary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}

typedef _Dest = ({String route, IconData icon, String label, String? perm, bool admin});

/// Rail de navigation sur fond bleu nuit : icône + libellé (étendu) ou icône seule avec infobulle (réduit).
/// Entrée active : fond `railActiveBg` et barre orange à gauche ; section Administration séparée.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.items,
    required this.selected,
    required this.onSelect,
    this.bordered = true,
    this.collapsed = false,
    this.showLogo = true,
  });

  final List<_Dest> items;
  final int selected;
  final ValueChanged<_Dest> onSelect;
  final bool bordered;
  final bool collapsed;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final main = [for (var i = 0; i < items.length; i++) if (!items[i].admin) i];
    final admin = [for (var i = 0; i < items.length; i++) if (items[i].admin) i];
    Widget tile(int i) => _RailItem(dest: items[i], active: i == selected, collapsed: collapsed, onTap: () => onSelect(items[i]));
    final list = ListView(
      padding: const EdgeInsets.all(AkSpace.s2),
      children: [
        for (final i in main) tile(i),
        if (admin.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AkSpace.s2, horizontal: AkSpace.s1),
            child: Divider(height: 1, color: t.railActiveBg),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s3, AkSpace.s2, AkSpace.s3, AkSpace.s1),
              child: Text('Administration', style: AkText.label.copyWith(color: t.railText)),
            ),
          for (final i in admin) tile(i),
        ],
      ],
    );
    if (!bordered) return list;
    return Container(
      width: collapsed ? AkSpace.railCollapsed : AkSpace.railWidth,
      color: t.railBg,
      child: Column(
        children: [
          if (showLogo)
            SizedBox(
              height: AkSpace.topbarHeight,
              child: Center(
                child: collapsed ? const AkLogo(height: 32, symbolOnly: true, tone: AkLogoTone.onDark) : const AkLogo(height: 32, tone: AkLogoTone.onDark),
              ),
            ),
          Expanded(child: list),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.dest, required this.active, required this.collapsed, required this.onTap});

  final _Dest dest;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final color = active ? t.railActiveText : t.railText;
    final row = Row(
      children: [
        // Barre d'indicateur de 3 px sur l'entrée active.
        Container(width: 3, height: AkSpace.s6, decoration: BoxDecoration(color: active ? t.railIndicator : Colors.transparent, borderRadius: AkRadius.smAll)),
        SizedBox(width: collapsed ? 0 : AkSpace.s3),
        if (collapsed) const Spacer(),
        Icon(dest.icon, size: AkSpace.iconMd, color: color),
        if (collapsed) const Spacer(),
        if (!collapsed) ...[
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Text(
              dest.label,
              overflow: TextOverflow.ellipsis,
              style: AkText.table.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ],
        if (collapsed) const SizedBox(width: 3),
      ],
    );
    final item = Material(
      color: active ? t.railActiveBg : Colors.transparent,
      borderRadius: AkRadius.mdAll,
      child: InkWell(
        borderRadius: AkRadius.mdAll,
        hoverColor: t.railActiveBg.withValues(alpha: 0.6),
        onTap: onTap,
        child: Semantics(
          selected: active,
          button: true,
          label: dest.label,
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: AkSpace.control), child: row),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s1),
      child: collapsed ? Tooltip(message: dest.label, child: item) : item,
    );
  }
}

/// Barre supérieure (bureau et tablette) : dossier courant toujours visible à gauche, alertes, menu utilisateur.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.entity, required this.profile, required this.onSignOut, required this.onPick});

  final EntitySummary? entity;
  final Profile? profile;
  final VoidCallback onSignOut;
  final VoidCallback onPick;

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
          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _CurrentEntitySelector(entity: entity))),
          const SizedBox(width: AkSpace.s2),
          AkIconButton(icon: Icons.search, tooltip: 'Changer de dossier (Ctrl K)', onPressed: onPick),
          const Spacer(),
          if (toCorrect > 0)
            Tooltip(
              message: '$toCorrect écriture(s) à corriger',
              child: InkWell(
                borderRadius: AkRadius.mdAll,
                onTap: () => context.go('/saisie'),
                child: Padding(
                  padding: const EdgeInsets.all(AkSpace.s2),
                  child: Badge(label: Text('$toCorrect'), backgroundColor: t.dangerSolid, textColor: t.onDanger, child: const Icon(Icons.notifications_outlined)),
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
      onSelected: (v) => v == 'password' ? showChangePasswordDialog(context) : onSignOut(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'password', child: Row(children: [Icon(Icons.lock_outline, size: AkSpace.iconSm), SizedBox(width: AkSpace.s2), Text('Changer mon mot de passe')])),
        const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: AkSpace.iconSm), SizedBox(width: AkSpace.s2), Text('Se déconnecter')])),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: AkSpace.s1),
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
                    Text(profile.jobTitle!, style: AkText.caption.copyWith(color: t.textMuted)),
                ],
              ),
            ],
            Icon(Icons.expand_more, size: AkSpace.iconMd, color: t.textMuted),
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
    final entities = ref.watch(entityDashboardProvider).value ?? const <EntitySummary>[];
    final current = entities.where((e) => e.id == entity?.id).firstOrNull;   // dossier absent de la liste (changement d'utilisateur)
    return SizedBox(
      width: mobile ? null : 420,
      child: AkDropdown<String>(
        key: const Key('current-entity'),
        hint: 'Choisir un dossier',
        value: current?.id,
        items: [for (final e in entities) AkOption(e.id, e.dossierLabel)],
        onChanged: (id) => ref.read(currentEntityProvider.notifier).select(entities.where((e) => e.id == id).firstOrNull),
      ),
    );
  }
}
