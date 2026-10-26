import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/ak_widgets.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

/// Référentiels du dossier courant : plan de comptes, tiers, journaux, modèles d'écritures, taux (§10.3).
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireEntity(
      builder: (entity) {
        final margin = akPageMargin(context);
        return DefaultTabController(
          length: 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AkPageHead(title: 'Référentiels', subtitle: entity.dossierLabel),
              const SizedBox(height: AkSpace.s3),
              Expanded(
                child: AkCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: Column(children: [
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: EdgeInsets.symmetric(horizontal: AkSpace.s2),
                      tabs: [Tab(text: 'Plan de comptes'), Tab(text: 'Tiers'), Tab(text: 'Journaux'), Tab(text: 'Modèles d\'écritures'), Tab(text: 'Taux')],
                    ),
                    Expanded(child: TabBarView(children: [AccountsTab(entity: entity), ThirdPartiesTab(entity: entity), JournalsTab(entity: entity), TemplatesTab(entity: entity), const TaxRatesTab()])),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Largeur d'une boîte de dialogue, réduite sur les écrans étroits.
double _dialogWidth(BuildContext context, double wanted) => math.min(wanted, MediaQuery.sizeOf(context).width - 80);

/// Barre d'outils d'un onglet : filtres à gauche, action principale à droite (sous les filtres sur mobile).
class _Toolbar extends StatelessWidget {
  const _Toolbar({this.filters = const [], this.action});

  final List<Widget> filters;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final compact = akIsCompact(context);
    final filterWrap = Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: filters);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (filters.isNotEmpty) filterWrap, if (filters.isNotEmpty && action != null) const SizedBox(height: AkSpace.s2), ?action])
          : Row(children: [Expanded(child: filterWrap), if (action != null) ...[const SizedBox(width: AkSpace.s3), action!]]),
    );
  }
}

/// Champ de recherche compact (32 px, 44 px sur mobile).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final h = akControlHeight(context);
    return SizedBox(
      width: akIsCompact(context) ? double.infinity : 280,
      height: h,
      child: Semantics(
        label: hint,
        child: TextField(
          style: AkText.table.copyWith(color: t.text),
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(Icons.search, size: 18, color: t.textMuted), prefixIconConstraints: const BoxConstraints(minWidth: 36), contentPadding: EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: (h - 18) / 2)),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Liste déroulante à contour de champ (remplace le DropdownButton nu).
class _AkDropdown<T> extends StatelessWidget {
  const _AkDropdown({required this.value, required this.items, required this.onChanged, this.hint});

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      height: akControlHeight(context),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderControl), borderRadius: AkRadius.mdAll),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          hint: hint == null ? null : Text(hint!, style: AkText.table.copyWith(color: t.text)),
          style: AkText.table.copyWith(color: t.text),
          icon: Icon(Icons.expand_more, size: 18, color: t.textMuted),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Ligne de liste : filet bas, hauteur tactile sur mobile.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.child, this.onTap, this.indent = 0});

  final Widget child;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: akIsCompact(context) ? AkSpace.rowTouch : AkSpace.rowCompact + 8),
      padding: EdgeInsets.fromLTRB(AkSpace.s4 + indent, 4, AkSpace.s2, 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.ak.border))),
      child: child,
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Mention « Désactivé » (icône + mot) pour un élément retiré de l'usage.
class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkBadge(label: 'Désactivé', color: t.textMuted, tint: t.surfaceSunken, icon: Icons.block);
  }
}

Widget _formError(String error, {Key? key}) => Padding(padding: const EdgeInsets.only(top: AkSpace.s2), child: AkBanner(kind: AkBannerKind.danger, child: Text(error, key: key)));

// ---------------------------------------------------------------------------
// Plan de comptes
// ---------------------------------------------------------------------------
class AccountsTab extends ConsumerStatefulWidget {
  const AccountsTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<AccountsTab> {
  String _search = '';
  int? _classFilter;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final accounts = ref.watch(accountsProvider(widget.entity.id));
    final compact = akIsCompact(context);
    return Column(children: [
      _Toolbar(
        filters: [
          _SearchField(hint: 'Numéro ou intitulé', onChanged: (v) => setState(() => _search = v.trim().toLowerCase())),
          _AkDropdown<int?>(
            value: _classFilter,
            hint: 'Classe',
            items: [const DropdownMenuItem(value: null, child: Text('Toutes')), for (var c = 1; c <= 8; c++) DropdownMenuItem(value: c, child: Text('Classe $c'))],
            onChanged: (v) => setState(() => _classFilter = v),
          ),
        ],
        action: FilledButton.icon(
          key: const Key('new-account'),
          style: FilledButton.styleFrom(minimumSize: Size(0, akControlHeight(context))),
          onPressed: () => showDialog(context: context, builder: (_) => AccountDialog(entity: widget.entity)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Subdiviser un compte'),
        ),
      ),
      Expanded(
        child: AsyncView(
          value: accounts,
          onRetry: () => ref.invalidate(accountsProvider(widget.entity.id)),
          builder: (list) {
            final filtered = list.where((a) => (_classFilter == null || a.classNo == _classFilter) && (_search.isEmpty || a.code.startsWith(_search) || a.label.toLowerCase().contains(_search))).toList();
            if (filtered.isEmpty) return const AkEmptyState('Aucun compte.');
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final a = filtered[i];
                final depth = a.significant.length.clamp(1, 7) - 1;
                final meta = [if (a.isCollective) 'collectif', if (a.isLetterable) 'lettrable', a.normalSide == 'debit' ? 'débiteur' : 'créditeur'].join(' · ');
                final label = Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: (a.allowPosting ? AkText.table : AkText.table.copyWith(fontWeight: FontWeight.w600)).copyWith(color: a.isActive ? t.text : t.textMuted, decoration: a.isActive ? null : TextDecoration.lineThrough));
                return _ListRow(
                  indent: depth * 14.0,
                  child: Row(children: [
                    SizedBox(width: 96, child: Text(a.code, style: AkText.code.copyWith(color: t.text, fontWeight: a.allowPosting ? FontWeight.w400 : FontWeight.w600))),
                    Expanded(
                      child: compact
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, Text(meta, style: AkText.caption.copyWith(color: t.textMuted))])
                          : Row(children: [Expanded(child: label), Text(meta, style: AkText.caption.copyWith(color: t.textMuted))]),
                    ),
                    if (!a.isActive) const Padding(padding: EdgeInsets.only(left: AkSpace.s2), child: _InactiveBadge()),
                    PopupMenuButton<String>(
                      onSelected: (v) => _action(v, a),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                        PopupMenuItem(value: 'toggle', child: Text(a.isActive ? 'Désactiver' : 'Réactiver')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer (sans mouvement)')),
                      ],
                    ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _action(String action, Account a) async {
    final repo = ref.read(referencesRepositoryProvider);
    try {
      switch (action) {
        case 'rename':
          final label = await _prompt(context, 'Nouvel intitulé', a.label);
          if (label != null && label.trim().isNotEmpty) await repo.renameAccount(a.id, label.trim());
        case 'toggle':
          await repo.setAccountActive(a.id, !a.isActive);
        case 'delete':
          await repo.deleteAccount(a.id);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_frenchError(e))));
    }
    ref.invalidate(accountsProvider(widget.entity.id));
  }
}

String _frenchError(Object e) {
  final m = e.toString();
  if (m.contains('subdivisions')) return 'Ce compte a des subdivisions : désactivez-le plutôt.';
  if (m.contains('mouvements')) return 'Ce compte a des mouvements : désactivez-le plutôt.';
  if (m.contains('duplicate key')) return 'Ce code existe déjà.';
  if (m.contains('42501') || m.contains('row-level security')) return 'Action non autorisée pour votre rôle.';
  return m;
}

Future<String?> _prompt(BuildContext context, String title, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider'))],
    ),
  );
}

/// Subdivision : numéro complété à la longueur de l'entité, parent trouvé par la base, sens hérité.
class AccountDialog extends ConsumerStatefulWidget {
  const AccountDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<AccountDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  bool _collective = false;
  String? _error;
  int _length = 7;

  @override
  void initState() {
    super.initState();
    ref.read(supabaseClientProvider).from('entities').select('account_length').eq('id', widget.entity.id).single().then((r) {
      if (mounted) setState(() => _length = (r['account_length'] as num).toInt());
    });
  }

  @override
  Widget build(BuildContext context) {
    final padded = padAccountCode(_code.text, _length);
    return AlertDialog(
      title: const Text('Nouveau compte (subdivision)'),
      content: SizedBox(
        width: _dialogWidth(context, 380),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _code, key: const Key('account-code'), autofocus: true, decoration: InputDecoration(labelText: 'Numéro', helperText: padded == null ? 'Chiffres uniquement, $_length au plus' : 'Sera enregistré : $padded'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          TextField(controller: _label, key: const Key('account-label'), decoration: const InputDecoration(labelText: 'Intitulé')),
          CheckboxListTile(value: _collective, onChanged: (v) => setState(() => _collective = v ?? false), title: const Text('Compte collectif (tiers rattachés)'), contentPadding: EdgeInsets.zero),
          if (_error != null) _formError(_error!, key: const Key('account-error')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('account-submit'),
          onPressed: () async {
            if (padded == null || _label.text.trim().isEmpty) {
              setState(() => _error = 'Numéro et intitulé requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).createAccount(cabinet!.id, widget.entity.id, code: padded, label: _label.text.trim(), isCollective: _collective ? true : null);
              ref.invalidate(accountsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tiers
// ---------------------------------------------------------------------------
class ThirdPartiesTab extends ConsumerStatefulWidget {
  const ThirdPartiesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<ThirdPartiesTab> createState() => _ThirdPartiesTabState();
}

class _ThirdPartiesTabState extends ConsumerState<ThirdPartiesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final tps = ref.watch(thirdPartiesProvider(widget.entity.id));
    return Column(children: [
      _Toolbar(
        filters: [_SearchField(hint: 'Code ou nom', onChanged: (v) => setState(() => _search = v.trim().toLowerCase()))],
        action: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: Size(0, akControlHeight(context))),
          onPressed: () => showDialog(context: context, builder: (_) => ThirdPartyDialog(entity: widget.entity)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau tiers'),
        ),
      ),
      Expanded(
        child: AsyncView(
          value: tps,
          onRetry: () => ref.invalidate(thirdPartiesProvider(widget.entity.id)),
          builder: (list) {
            final filtered = list.where((p) => _search.isEmpty || p.code.toLowerCase().contains(_search) || p.name.toLowerCase().contains(_search)).toList();
            if (filtered.isEmpty) return const AkEmptyState('Aucun tiers.');
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                return _ListRow(
                  onTap: () => showDialog(context: context, builder: (_) => ThirdPartyDialog(entity: widget.entity, initial: p)),
                  child: Row(children: [
                    SizedBox(width: 96, child: Text(p.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: p.isActive ? t.text : t.textMuted, decoration: p.isActive ? null : TextDecoration.lineThrough)),
                        Text([ThirdParty.typeLabels[p.type] ?? p.type, if (p.collectiveCodes.isNotEmpty) 'collectifs ${p.collectiveCodes.join(', ')}', if (p.taxId != null) 'IFU ${p.taxId}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.caption.copyWith(color: t.textMuted)),
                      ]),
                    ),
                    if (!p.isActive) const Padding(padding: EdgeInsets.only(left: AkSpace.s2), child: _InactiveBadge()),
                    Switch(value: p.isActive, onChanged: (v) async {
                      await ref.read(referencesRepositoryProvider).setThirdPartyActive(p.id, v);
                      ref.invalidate(thirdPartiesProvider(widget.entity.id));
                    }),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class ThirdPartyDialog extends ConsumerStatefulWidget {
  const ThirdPartyDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final ThirdParty? initial;

  @override
  ConsumerState<ThirdPartyDialog> createState() => _ThirdPartyDialogState();
}

class _ThirdPartyDialogState extends ConsumerState<ThirdPartyDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _taxId = TextEditingController(text: widget.initial?.taxId);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _email = TextEditingController(text: widget.initial?.email);
  late String _type = widget.initial?.type ?? 'customer';
  final Set<String> _collectives = {};
  bool _loaded = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[];
    final collectives = accounts.where((a) => a.isCollective && a.allowPosting && a.isActive).toList();
    if (!_loaded && widget.initial != null && accounts.isNotEmpty) {
      _collectives.addAll(collectives.where((a) => widget.initial!.collectiveCodes.contains(a.code)).map((a) => a.id));
      _loaded = true;
    }
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau tiers' : 'Tiers ${widget.initial!.code}'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: _dialogWidth(context, 460),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                SizedBox(width: 140, child: TextFormField(controller: _code, key: const Key('tp-code'), enabled: widget.initial == null, decoration: const InputDecoration(labelText: 'Code'), validator: validateThirdPartyCode, textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _name, key: const Key('tp-name'), decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null)),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [for (final e in ThirdParty.typeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _type = v ?? 'other'),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: _taxId, decoration: const InputDecoration(labelText: 'IFU')),
              const SizedBox(height: 8),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'))),
              ]),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Comptes collectifs de rattachement', style: AkText.bodyStrong.copyWith(color: context.ak.text))),
              Wrap(
                spacing: 6,
                children: [
                  for (final a in collectives)
                    FilterChip(label: Text('${a.code} ${a.label}'), selected: _collectives.contains(a.id), onSelected: (v) => setState(() => v ? _collectives.add(a.id) : _collectives.remove(a.id))),
                ],
              ),
              if (_error != null) _formError(_error!),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('tp-submit'),
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).saveThirdParty(cabinet!.id, widget.entity.id,
                  id: widget.initial?.id, code: _code.text, name: _name.text, type: _type, taxId: _taxId.text, address: _address.text, phone: _phone.text, email: _email.text, collectiveAccountIds: _collectives.toList());
              ref.invalidate(thirdPartiesProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Journaux
// ---------------------------------------------------------------------------
class JournalsTab extends ConsumerWidget {
  const JournalsTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final journals = ref.watch(journalsProvider(entity.id));
    return Column(children: [
      _Toolbar(
        action: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: Size(0, akControlHeight(context))),
          onPressed: () => showDialog(context: context, builder: (_) => JournalDialog(entity: entity)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau journal'),
        ),
      ),
      Expanded(
        child: AsyncView(
          value: journals,
          onRetry: () => ref.invalidate(journalsProvider(entity.id)),
          builder: (list) => list.isEmpty
              ? const AkEmptyState('Aucun journal.')
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final j = list[i];
                    return _ListRow(
                      onTap: () => showDialog(context: context, builder: (_) => JournalDialog(entity: entity, initial: j)),
                      child: Row(children: [
                        SizedBox(width: 64, child: Text(j.code, style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600))),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(j.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: j.isActive ? t.text : t.textMuted, decoration: j.isActive ? null : TextDecoration.lineThrough)),
                            Text([Journal.typeLabels[j.type] ?? j.type, if (j.treasuryAccountCode != null) 'compte ${j.treasuryAccountCode}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.caption.copyWith(color: t.textMuted)),
                          ]),
                        ),
                        if (!j.isActive) const Padding(padding: EdgeInsets.only(left: AkSpace.s2), child: _InactiveBadge()),
                        if (j.type == 'opening')
                          const Padding(padding: EdgeInsets.symmetric(horizontal: AkSpace.s2), child: Tooltip(message: 'Journal imposé', child: Icon(Icons.lock_outline, size: 20)))
                        else
                          Switch(value: j.isActive, onChanged: (v) async {
                            await ref.read(referencesRepositoryProvider).setJournalActive(j.id, v);
                            ref.invalidate(journalsProvider(entity.id));
                          }),
                      ]),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}

class JournalDialog extends ConsumerStatefulWidget {
  const JournalDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final Journal? initial;

  @override
  ConsumerState<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends ConsumerState<JournalDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _label = TextEditingController(text: widget.initial?.label);
  late String _type = widget.initial?.type ?? 'misc';
  late String? _account = widget.initial?.treasuryAccountId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.classNo == 5 && a.allowPosting && a.isActive).toList();
    final treasury = _type == 'bank' || _type == 'cash';
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau journal' : 'Journal ${widget.initial!.code}'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: _dialogWidth(context, 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(width: 110, child: TextFormField(controller: _code, enabled: widget.initial == null, decoration: const InputDecoration(labelText: 'Code'), validator: validateJournalCode, textCapitalization: TextCapitalization.characters)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé'), validator: (v) => (v ?? '').trim().isEmpty ? 'Libellé requis' : null)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final e in Journal.typeLabels.entries.where((e) => e.key != 'opening')) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: widget.initial == null ? (v) => setState(() => _type = v ?? 'misc') : null,
            ),
            if (treasury) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _account,
                decoration: const InputDecoration(labelText: 'Compte de trésorerie (classe 5)'),
                items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.label}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _account = v),
                validator: (v) => v == null ? 'Compte requis pour un journal de trésorerie' : null,
              ),
            ],
            if (_error != null) _formError(_error!),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).saveJournal(cabinet!.id, widget.entity.id, id: widget.initial?.id, code: _code.text, label: _label.text, type: _type, treasuryAccountId: treasury ? _account : null);
              ref.invalidate(journalsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Modèles d'écritures
// ---------------------------------------------------------------------------
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final templates = ref.watch(templatesProvider(entity.id));
    return Column(children: [
      _Toolbar(
        action: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: Size(0, akControlHeight(context))),
          onPressed: () => showDialog(context: context, builder: (_) => TemplateDialog(entity: entity)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau modèle'),
        ),
      ),
      Expanded(
        child: AsyncView(
          value: templates,
          onRetry: () => ref.invalidate(templatesProvider(entity.id)),
          builder: (list) => list.isEmpty
              ? const AkEmptyState('Aucun modèle d\'écriture.')
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
                        title: Row(children: [
                          Text(m.code, style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600)),
                          const SizedBox(width: AkSpace.s2),
                          Expanded(child: Text('— ${m.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
                        ]),
                        subtitle: Text([m.isCabinetLevel ? 'modèle du cabinet' : 'modèle du dossier', if (m.journalType != null) Journal.typeLabels[m.journalType] ?? m.journalType!, if (m.description != null) m.description!].join(' · '), style: AkText.caption.copyWith(color: t.textMuted)),
                        children: [
                          for (final l in m.lines)
                            Container(
                              color: t.surfaceSunken,
                              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 6),
                              child: Row(children: [
                                SizedBox(width: 28, child: Text('${l.lineNo}', style: AkText.code.copyWith(color: t.textMuted))),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text.rich(TextSpan(children: [
                                      TextSpan(text: l.accountCode, style: AkText.code.copyWith(color: t.text)),
                                      TextSpan(text: '${l.usesThirdParty ? ' + tiers' : ''} · ${l.side == 'debit' ? 'Débit' : 'Crédit'}', style: AkText.table.copyWith(color: t.text)),
                                    ])),
                                    Text('${l.label ?? ''} · ${l.formulaLabel}', style: AkText.caption.copyWith(color: t.textMuted)),
                                  ]),
                                ),
                              ]),
                            ),
                          if (!m.isCabinetLevel)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.all(AkSpace.s2),
                                child: TextButton(
                                  style: TextButton.styleFrom(foregroundColor: t.danger, minimumSize: Size(0, akControlHeight(context))),
                                  onPressed: () async {
                                    await ref.read(referencesRepositoryProvider).deactivateTemplate(m.id);
                                    ref.invalidate(templatesProvider(entity.id));
                                  },
                                  child: const Text('Retirer ce modèle'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}

/// Création d'un modèle du dossier : lignes avec compte, sens, formule (saisie, % d'une ligne, solde).
class TemplateDialog extends ConsumerStatefulWidget {
  const TemplateDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<TemplateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  String? _journalType;
  final List<_LineDraft> _lines = [_LineDraft(), _LineDraft(formula: 'balance', side: 'credit')];
  String? _error;

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(taxRatesProvider).value ?? const <TaxRate>[];
    final rateCodes = rates.map((r) => r.code).toSet().toList()..sort();
    return AlertDialog(
      title: const Text('Nouveau modèle d\'écriture'),
      content: SizedBox(
        width: _dialogWidth(context, 720),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
              SizedBox(width: 140, child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code'), textCapitalization: TextCapitalization.characters)),
              SizedBox(width: 240, child: TextField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé'))),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  initialValue: _journalType,
                  decoration: const InputDecoration(labelText: 'Journal'),
                  items: [const DropdownMenuItem(value: null, child: Text('Tous')), for (final e in Journal.typeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _journalType = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            for (var i = 0; i < _lines.length; i++) _lineRow(i, rateCodes),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _lines.add(_LineDraft())), icon: const Icon(Icons.add), label: const Text('Ajouter une ligne'))),
            if (_error != null) _formError(_error!),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }

  Widget _lineRow(int i, List<String> rateCodes) {
    final t = context.ak;
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 20, child: Text('${i + 1}', style: AkText.code.copyWith(color: t.textMuted))),
        SizedBox(width: 96, child: TextField(controller: l.account, style: AkText.code.copyWith(color: t.text), decoration: const InputDecoration(labelText: 'Compte'))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(value: l.thirdParty, onChanged: (v) => setState(() => l.thirdParty = v ?? false)),
          Text('tiers', style: AkText.caption.copyWith(color: t.text)),
        ]),
        _AkDropdown<String>(value: l.side, items: const [DropdownMenuItem(value: 'debit', child: Text('Débit')), DropdownMenuItem(value: 'credit', child: Text('Crédit'))], onChanged: (v) => setState(() => l.side = v ?? 'debit')),
        _AkDropdown<String>(value: l.formula, items: const [DropdownMenuItem(value: 'input', child: Text('Saisie')), DropdownMenuItem(value: 'percent_of', child: Text('% d\'une ligne')), DropdownMenuItem(value: 'balance', child: Text('Solde'))], onChanged: (v) => setState(() => l.formula = v ?? 'input')),
        if (l.formula == 'percent_of') ...[
          SizedBox(width: 64, child: TextField(controller: l.refLine, decoration: const InputDecoration(labelText: 'Ligne'))),
          _AkDropdown<String?>(value: l.rateCode, hint: 'Taux', items: [const DropdownMenuItem(value: null, child: Text('% fixe')), for (final c in rateCodes) DropdownMenuItem(value: c, child: Text(c))], onChanged: (v) => setState(() => l.rateCode = v)),
          if (l.rateCode == null) SizedBox(width: 72, child: TextField(controller: l.percent, decoration: const InputDecoration(labelText: '%'))),
        ],
        SizedBox(width: 200, child: TextField(controller: l.label, decoration: const InputDecoration(labelText: 'Libellé'))),
        IconButton(tooltip: 'Retirer la ligne', icon: const Icon(Icons.close), onPressed: _lines.length <= 2 ? null : () => setState(() => _lines.removeAt(i))),
      ]),
    );
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _label.text.trim().isEmpty) {
      setState(() => _error = 'Code et libellé requis');
      return;
    }
    final lines = <TemplateLine>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(l.account.text.trim())) {
        setState(() => _error = 'Ligne ${i + 1} : compte numérique requis');
        return;
      }
      final pct = l.percent.text.trim().isEmpty ? null : double.tryParse(l.percent.text.replaceAll(',', '.'));
      lines.add(TemplateLine(
        lineNo: i + 1,
        accountCode: l.account.text.trim(),
        usesThirdParty: l.thirdParty,
        side: l.side,
        formula: l.formula,
        refLineNo: l.formula == 'percent_of' ? int.tryParse(l.refLine.text.trim()) : null,
        percent: l.formula == 'percent_of' && l.rateCode == null && pct != null ? pct / 100 : null,
        taxRateCode: l.formula == 'percent_of' ? l.rateCode : null,
        label: l.label.text.trim().isEmpty ? null : l.label.text.trim(),
      ));
    }
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref.read(referencesRepositoryProvider).saveTemplate(cabinet!.id, widget.entity.id, code: _code.text, label: _label.text, journalType: _journalType, lines: lines);
      ref.invalidate(templatesProvider(widget.entity.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _frenchError(e));
    }
  }
}

class _LineDraft {
  _LineDraft({this.formula = 'input', this.side = 'debit'});

  final account = TextEditingController();
  final label = TextEditingController();
  final refLine = TextEditingController(text: '1');
  final percent = TextEditingController();
  bool thirdParty = false;
  String side;
  String formula;
  String? rateCode;
}

// ---------------------------------------------------------------------------
// Taux
// ---------------------------------------------------------------------------
class TaxRatesTab extends ConsumerWidget {
  const TaxRatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final rates = ref.watch(taxRatesProvider);
    final canEdit = ref.watch(permissionsProvider).value?.has('cabinet.settings') ?? false;
    return Column(children: [
      if (canEdit)
        _Toolbar(
          action: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: Size(0, akControlHeight(context))),
            onPressed: () => showDialog(context: context, builder: (_) => const TaxRateDialog()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouveau taux'),
          ),
        ),
      Expanded(
        child: AsyncView(
          value: rates,
          onRetry: () => ref.invalidate(taxRatesProvider),
          builder: (list) => SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 2 * akPageMargin(context) - 2),
                child: DataTable(
                  columnSpacing: AkSpace.s6,
                  horizontalMargin: AkSpace.s4,
                  columns: const [DataColumn(label: Text('Code')), DataColumn(label: Text('Libellé')), DataColumn(label: Text('Taux'), numeric: true), DataColumn(label: Text('Valide du')), DataColumn(label: Text('au'))],
                  rows: [
                    for (final r in list)
                      DataRow(cells: [
                        DataCell(Text(r.code, style: AkText.code.copyWith(color: t.text))),
                        DataCell(Text(r.label)),
                        DataCell(AkAmountText(r.percentLabel)),
                        DataCell(Text(Fmt.date(r.validFrom))),
                        DataCell(Text(r.validTo == null ? '—' : Fmt.date(r.validTo))),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class TaxRateDialog extends ConsumerStatefulWidget {
  const TaxRateDialog({super.key});

  @override
  ConsumerState<TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends ConsumerState<TaxRateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  final _rate = TextEditingController();
  final _from = TextEditingController(text: Fmt.date(DateTime.now()));
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau taux (ou nouvelle valeur d\'un taux existant)'),
      content: SizedBox(
        width: _dialogWidth(context, 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code (ex. TVA, AIB1)'), textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 8),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Taux en % (ex. 18)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'Valide à partir du'))),
          ]),
          if (_error != null) _formError(_error!),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
            final from = Fmt.parseDate(_from.text);
            if (!RegExp(r'^[A-Z0-9_]{2,20}$').hasMatch(_code.text.trim().toUpperCase()) || _label.text.trim().isEmpty || rate == null || rate < 0 || rate > 100 || from == null) {
              setState(() => _error = 'Code, libellé, taux (0-100) et date valides requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).addTaxRate(cabinet!.id, code: _code.text, label: _label.text, rate: rate / 100, validFrom: from);
              ref.invalidate(taxRatesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
