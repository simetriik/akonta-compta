
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AkPageHead(title: 'Référentiels', subtitle: entity.dossierLabel),
                const SizedBox(height: AkSpace.s3),
                Expanded(
                  child: AkCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Column(
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.symmetric(horizontal: AkSpace.s2),
                          tabs: [
                            Tab(text: 'Plan de comptes'),
                            Tab(text: 'Tiers'),
                            Tab(text: 'Journaux'),
                            Tab(text: 'Modèles d\'écritures'),
                            Tab(text: 'Taux'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              AccountsTab(entity: entity),
                              ThirdPartiesTab(entity: entity),
                              JournalsTab(entity: entity),
                              TemplatesTab(entity: entity),
                              const TaxRatesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Largeur d'une boîte de dialogue, réduite sur les écrans étroits.

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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filters.isNotEmpty) filterWrap,
                if (filters.isNotEmpty && action != null) const SizedBox(height: AkSpace.s2),
                ?action,
              ],
            )
          : Row(
              children: [
                Expanded(child: filterWrap),
                if (action != null) ...[const SizedBox(width: AkSpace.s3), action!],
              ],
            ),
    );
  }
}

/// Champ de recherche compact (32 px, 48 px sur mobile).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: akIsCompact(context) ? double.infinity : 280,
      child: Semantics(
        label: hint,
        child: AkTextField(dense: true, hint: hint, prefixIcon: const Icon(Icons.search, size: 18), onChanged: onChanged),
      ),
    );
  }
}

/// Liste déroulante compacte de barre d'outils (largeur bornée).
Widget _toolbarDropdown<T>({required T? value, required String hint, required List<AkOption<T>> items, required ValueChanged<T?> onChanged}) => SizedBox(
  width: 160,
  child: AkDropdown<T>(value: value, hint: hint, dense: true, items: items, onChanged: onChanged),
);

/// Ligne de liste : filet bas, hauteur tactile sur mobile.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.child, this.onTap, this.indent = 0});

  final Widget child;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact + 8),
      padding: EdgeInsets.fromLTRB(AkSpace.s4 + indent, 4, AkSpace.s2, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.ak.border)),
      ),
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

Widget _formError(String error, {Key? key}) => Padding(
  padding: const EdgeInsets.only(top: AkSpace.s2),
  child: AkBanner(
    kind: AkBannerKind.danger,
    child: Text(error, key: key),
  ),
);

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
    return Column(
      children: [
        _Toolbar(
          filters: [
            _SearchField(hint: 'Numéro ou intitulé', onChanged: (v) => setState(() => _search = v.trim().toLowerCase())),
            _toolbarDropdown<int?>(
              value: _classFilter,
              hint: 'Classe',
              items: [const AkOption(null, 'Toutes'), for (var c = 1; c <= 8; c++) AkOption(c, 'Classe $c')],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
          ],
          action: AkButton.primary(
            'Subdiviser un compte',
            key: const Key('new-account'),
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AccountDialog(entity: widget.entity),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: accounts,
            onRetry: () => ref.invalidate(accountsProvider(widget.entity.id)),
            builder: (list) {
              final filtered = list
                  .where(
                    (a) =>
                        (_classFilter == null || a.classNo == _classFilter) &&
                        (_search.isEmpty || a.code.startsWith(_search) || a.label.toLowerCase().contains(_search)),
                  )
                  .toList();
              if (filtered.isEmpty) return const AkEmptyState('Aucun compte.');
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  final depth = a.significant.length.clamp(1, 7) - 1;
                  final meta = [
                    if (a.isCollective) 'collectif',
                    if (a.isLetterable) 'lettrable',
                    a.normalSide == 'debit' ? 'débiteur' : 'créditeur',
                  ].join(' · ');
                  final label = Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (a.allowPosting ? AkText.table : AkText.table.copyWith(fontWeight: FontWeight.w600)).copyWith(
                      color: a.isActive ? t.text : t.textMuted,
                      decoration: a.isActive ? null : TextDecoration.lineThrough,
                    ),
                  );
                  return _ListRow(
                    indent: depth * 14.0,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            a.code,
                            style: AkText.code.copyWith(color: t.text, fontWeight: a.allowPosting ? FontWeight.w400 : FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label,
                                    Text(meta, style: AkText.caption.copyWith(color: t.textMuted)),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: label),
                                    Text(meta, style: AkText.caption.copyWith(color: t.textMuted)),
                                  ],
                                ),
                        ),
                        if (!a.isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: AkSpace.s2),
                            child: _InactiveBadge(),
                          ),
                        PopupMenuButton<String>(
                          onSelected: (v) => _action(v, a),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                            PopupMenuItem(value: 'toggle', child: Text(a.isActive ? 'Désactiver' : 'Réactiver')),
                            const PopupMenuItem(value: 'delete', child: Text('Supprimer (sans mouvement)')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _action(String action, Account a) async {
    final repo = ref.read(referencesServiceProvider);
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
      if (mounted) showAkToast(context, errorText(e), kind: AkToastKind.danger);
    }
    ref.invalidate(accountsProvider(widget.entity.id));
  }
}

Future<String?> _prompt(BuildContext context, String title, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AkDialog(
      title: title,
      content: AkTextField(controller: c, autofocus: true),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx)),
        AkButton.primary('Valider', onPressed: () => Navigator.pop(ctx, c.text)),
      ],
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
    ref.read(entityProvider(widget.entity.id).future).then((e) {
      if (mounted) setState(() => _length = e.accountLength);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padded = padAccountCode(_code.text, _length);
    return AkDialog(
      title: 'Nouveau compte (subdivision)',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(
            controller: _code,
            key: const Key('account-code'),
            autofocus: true,
            label: 'Numéro',
            helper: padded == null ? 'Chiffres uniquement, $_length au plus' : 'Sera enregistré : $padded',
            mono: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _label, key: const Key('account-label'), label: 'Intitulé'),
          const SizedBox(height: AkSpace.s2),
          AkCheckbox(value: _collective, onChanged: (v) => setState(() => _collective = v), label: 'Compte collectif (tiers rattachés)'),
          if (_error != null) _formError(_error!, key: const Key('account-error')),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Créer',
          key: const Key('account-submit'),
          onPressed: () async {
            if (padded == null || _label.text.trim().isEmpty) {
              setState(() => _error = 'Numéro et intitulé requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(referencesServiceProvider)
                  .createAccount(cabinet!.id, widget.entity.id, code: padded, label: _label.text.trim(), isCollective: _collective ? true : null);
              ref.invalidate(accountsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
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
    return Column(
      children: [
        _Toolbar(
          filters: [_SearchField(hint: 'Code ou nom', onChanged: (v) => setState(() => _search = v.trim().toLowerCase()))],
          action: AkButton.primary(
            'Nouveau tiers',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ThirdPartyDialog(entity: widget.entity),
            ),
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
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ThirdPartyDialog(entity: widget.entity, initial: p),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            p.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AkText.table.copyWith(
                                  color: p.isActive ? t.text : t.textMuted,
                                  decoration: p.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                [
                                  ThirdParty.typeLabels[p.type] ?? p.type,
                                  if (p.collectiveCodes.isNotEmpty) 'collectifs ${p.collectiveCodes.join(', ')}',
                                  if (p.taxId != null) 'IFU ${p.taxId}',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AkText.caption.copyWith(color: t.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (!p.isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: AkSpace.s2),
                            child: _InactiveBadge(),
                          ),
                        AkSwitch(
                          value: p.isActive,
                          onChanged: (v) async {
                            await ref.read(referencesServiceProvider).setThirdPartyActive(p.id, v);
                            ref.invalidate(thirdPartiesProvider(widget.entity.id));
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
    return AkDialog(
      title: widget.initial == null ? 'Nouveau tiers' : 'Tiers ${widget.initial!.code}',
      size: AkDialogSize.m,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: AkTextField(
                    controller: _code,
                    key: const Key('tp-code'),
                    enabled: widget.initial == null,
                    label: 'Code',
                    mono: true,
                    validator: validateThirdPartyCode,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(
                    controller: _name,
                    key: const Key('tp-name'),
                    label: 'Nom',
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _type,
              label: 'Type',
              items: [for (final e in ThirdParty.typeLabels.entries) AkOption(e.key, e.value)],
              onChanged: (v) => setState(() => _type = v ?? 'other'),
            ),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _taxId, label: 'IFU'),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _address, label: 'Adresse'),
            const SizedBox(height: AkSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkTextField(controller: _phone, label: 'Téléphone', keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            Text('Comptes collectifs de rattachement', style: AkText.bodyStrong.copyWith(color: context.ak.text)),
            const SizedBox(height: AkSpace.s2),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s1,
              children: [
                for (final a in collectives)
                  FilterChip(
                    label: Text('${a.code} ${a.label}'),
                    selected: _collectives.contains(a.id),
                    onSelected: (v) => setState(() => v ? _collectives.add(a.id) : _collectives.remove(a.id)),
                  ),
              ],
            ),
            if (_error != null) _formError(_error!),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          key: const Key('tp-submit'),
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(referencesServiceProvider)
                  .saveThirdParty(
                    cabinet!.id,
                    widget.entity.id,
                    id: widget.initial?.id,
                    code: _code.text,
                    name: _name.text,
                    type: _type,
                    taxId: _taxId.text,
                    address: _address.text,
                    phone: _phone.text,
                    email: _email.text,
                    collectiveAccountIds: _collectives.toList(),
                  );
              ref.invalidate(thirdPartiesProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
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
    return Column(
      children: [
        _Toolbar(
          action: AkButton.primary(
            'Nouveau journal',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => JournalDialog(entity: entity),
            ),
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
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => JournalDialog(entity: entity, initial: j),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                j.code,
                                style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    j.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AkText.table.copyWith(
                                      color: j.isActive ? t.text : t.textMuted,
                                      decoration: j.isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    [Journal.typeLabels[j.type] ?? j.type, if (j.treasuryAccountCode != null) 'compte ${j.treasuryAccountCode}'].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AkText.caption.copyWith(color: t.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (!j.isActive)
                              const Padding(
                                padding: EdgeInsets.only(left: AkSpace.s2),
                                child: _InactiveBadge(),
                              ),
                            if (j.type == 'opening')
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: AkSpace.s2),
                                child: Tooltip(message: 'Journal imposé', child: Icon(Icons.lock_outline, size: 20)),
                              )
                            else
                              AkSwitch(
                                value: j.isActive,
                                onChanged: (v) async {
                                  await ref.read(referencesServiceProvider).setJournalActive(j.id, v);
                                  ref.invalidate(journalsProvider(entity.id));
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
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
  bool _accountMissing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[])
        .where((a) => a.classNo == 5 && a.allowPosting && a.isActive)
        .toList();
    final treasury = _type == 'bank' || _type == 'cash';
    return AkDialog(
      title: widget.initial == null ? 'Nouveau journal' : 'Journal ${widget.initial!.code}',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: AkTextField(
                    controller: _code,
                    enabled: widget.initial == null,
                    label: 'Code',
                    mono: true,
                    validator: validateJournalCode,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _label, label: 'Libellé', validator: (v) => (v ?? '').trim().isEmpty ? 'Libellé requis' : null),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _type,
              label: 'Type',
              items: [for (final e in Journal.typeLabels.entries.where((e) => e.key != 'opening')) AkOption(e.key, e.value)],
              onChanged: widget.initial == null ? (v) => setState(() => _type = v ?? 'misc') : null,
            ),
            if (treasury) ...[
              const SizedBox(height: AkSpace.s3),
              AkAccountField(
                accounts: accounts,
                selected: accounts.where((a) => a.id == _account).firstOrNull,
                label: 'Compte de trésorerie (classe 5)',
                invalid: _accountMissing,
                helper: _accountMissing ? 'Compte requis pour un journal de trésorerie' : null,
                onSelected: (a) => setState(() {
                  _account = a.id;
                  _accountMissing = false;
                }),
                onCleared: () => _account = null,
              ),
            ],
            if (_error != null) _formError(_error!),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: () async {
            final formOk = _form.currentState!.validate();
            if (treasury && _account == null) setState(() => _accountMissing = true);
            if (!formOk || (treasury && _account == null)) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(referencesServiceProvider)
                  .saveJournal(
                    cabinet!.id,
                    widget.entity.id,
                    id: widget.initial?.id,
                    code: _code.text,
                    label: _label.text,
                    type: _type,
                    treasuryAccountId: treasury ? _account : null,
                  );
              ref.invalidate(journalsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
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
    return Column(
      children: [
        _Toolbar(
          action: AkButton.primary(
            'Nouveau modèle',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => TemplateDialog(entity: entity),
            ),
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
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: t.border)),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
                          title: Row(
                            children: [
                              Text(
                                m.code,
                                style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: AkSpace.s2),
                              Expanded(
                                child: Text(
                                  '— ${m.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AkText.table.copyWith(color: t.text),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            [
                              m.isCabinetLevel ? 'modèle du cabinet' : 'modèle du dossier',
                              if (m.journalType != null) Journal.typeLabels[m.journalType] ?? m.journalType!,
                              if (m.description != null) m.description!,
                            ].join(' · '),
                            style: AkText.caption.copyWith(color: t.textMuted),
                          ),
                          children: [
                            for (final l in m.lines)
                              Container(
                                color: t.surfaceSunken,
                                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text('${l.lineNo}', style: AkText.code.copyWith(color: t.textMuted)),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: l.accountCode,
                                                  style: AkText.code.copyWith(color: t.text),
                                                ),
                                                TextSpan(
                                                  text: '${l.usesThirdParty ? ' + tiers' : ''} · ${l.side == 'debit' ? 'Débit' : 'Crédit'}',
                                                  style: AkText.table.copyWith(color: t.text),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text('${l.label ?? ''} · ${l.formulaLabel}', style: AkText.caption.copyWith(color: t.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!m.isCabinetLevel)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(AkSpace.s2),
                                  child: AkButton.dangerOutline(
                                    'Retirer ce modèle',
                                    dense: true,
                                    onPressed: () async {
                                      await ref.read(referencesServiceProvider).deactivateTemplate(m.id);
                                      ref.invalidate(templatesProvider(entity.id));
                                    },
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
      ],
    );
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
    return AkDialog(
      title: 'Nouveau modèle d\'écriture',
      size: AkDialogSize.l,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              SizedBox(
                width: 140,
                child: AkTextField(controller: _code, label: 'Code', mono: true, textCapitalization: TextCapitalization.characters),
              ),
              SizedBox(
                width: 240,
                child: AkTextField(controller: _label, label: 'Libellé'),
              ),
              SizedBox(
                width: 170,
                child: AkDropdown<String?>(
                  value: _journalType,
                  label: 'Journal',
                  items: [const AkOption(null, 'Tous'), for (final e in Journal.typeLabels.entries) AkOption(e.key, e.value)],
                  onChanged: (v) => setState(() => _journalType = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          for (var i = 0; i < _lines.length; i++) _lineRow(i, rateCodes),
          Align(
            alignment: Alignment.centerLeft,
            child: AkButton.ghost('Ajouter une ligne', icon: Icons.add, onPressed: () => setState(() => _lines.add(_LineDraft()))),
          ),
          if (_error != null) _formError(_error!),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Enregistrer', onPressed: _save),
      ],
    );
  }

  Widget _lineRow(int i, List<String> rateCodes) {
    final t = context.ak;
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Wrap(
        spacing: AkSpace.s2,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 20,
            height: akControlHeight(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${i + 1}', style: AkText.code.copyWith(color: t.textMuted)),
            ),
          ),
          SizedBox(
            width: 96,
            child: AkTextField(controller: l.account, label: 'Compte', mono: true),
          ),
          AkCheckbox(value: l.thirdParty, onChanged: (v) => setState(() => l.thirdParty = v), label: 'tiers'),
          SizedBox(
            width: 110,
            child: AkDropdown<String>(
              value: l.side,
              label: 'Sens',
              items: const [AkOption('debit', 'Débit'), AkOption('credit', 'Crédit')],
              onChanged: (v) => setState(() => l.side = v ?? 'debit'),
            ),
          ),
          SizedBox(
            width: 150,
            child: AkDropdown<String>(
              value: l.formula,
              label: 'Formule',
              items: const [AkOption('input', 'Saisie'), AkOption('percent_of', '% d\'une ligne'), AkOption('balance', 'Solde')],
              onChanged: (v) => setState(() => l.formula = v ?? 'input'),
            ),
          ),
          if (l.formula == 'percent_of') ...[
            SizedBox(
              width: 72,
              child: AkTextField(controller: l.refLine, label: 'Ligne', keyboardType: TextInputType.number),
            ),
            SizedBox(
              width: 120,
              child: AkDropdown<String?>(
                value: l.rateCode,
                label: 'Taux',
                items: [const AkOption(null, '% fixe'), for (final c in rateCodes) AkOption(c, c)],
                onChanged: (v) => setState(() => l.rateCode = v),
              ),
            ),
            if (l.rateCode == null)
              SizedBox(
                width: 80,
                child: AkTextField(controller: l.percent, label: '%', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
          ],
          SizedBox(
            width: 200,
            child: AkTextField(controller: l.label, label: 'Libellé'),
          ),
          AkIconButton(tooltip: 'Retirer la ligne', icon: Icons.close, onPressed: _lines.length <= 2 ? null : () => setState(() => _lines.removeAt(i))),
        ],
      ),
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
      lines.add(
        TemplateLine(
          lineNo: i + 1,
          accountCode: l.account.text.trim(),
          usesThirdParty: l.thirdParty,
          side: l.side,
          formula: l.formula,
          refLineNo: l.formula == 'percent_of' ? int.tryParse(l.refLine.text.trim()) : null,
          percent: l.formula == 'percent_of' && l.rateCode == null && pct != null ? pct / 100 : null,
          taxRateCode: l.formula == 'percent_of' ? l.rateCode : null,
          label: l.label.text.trim().isEmpty ? null : l.label.text.trim(),
        ),
      );
    }
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref
          .read(referencesServiceProvider)
          .saveTemplate(cabinet!.id, widget.entity.id, code: _code.text, label: _label.text, journalType: _journalType, lines: lines);
      ref.invalidate(templatesProvider(widget.entity.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = errorText(e));
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
    return Column(
      children: [
        if (canEdit)
          _Toolbar(
            action: AkButton.primary(
              'Nouveau taux',
              icon: Icons.add,
              dense: true,
              onPressed: () => showDialog(context: context, builder: (_) => const TaxRateDialog()),
            ),
          ),
        Expanded(
          child: AsyncView(
            value: rates,
            onRetry: () => ref.invalidate(taxRatesProvider),
            builder: (list) => SingleChildScrollView(
              padding: EdgeInsets.all(akPageMargin(context)),
              child: AkTable<TaxRate>(
                minWidth: 560,
                rows: list,
                emptyMessage: 'Aucun taux.',
                columns: [
                  AkColumn<TaxRate>(
                    label: 'Code',
                    width: 120,
                    cell: (context, r) => Text(r.code, style: AkText.code.copyWith(color: t.text)),
                  ),
                  AkColumn<TaxRate>.text(label: 'Libellé', text: (r) => r.label, flex: 3),
                  AkColumn<TaxRate>(label: 'Taux', width: 80, numeric: true, cell: (context, r) => AkAmountText(r.percentLabel)),
                  AkColumn<TaxRate>.text(label: 'Valide du', text: (r) => Fmt.date(r.validFrom), width: 110),
                  AkColumn<TaxRate>.text(label: 'au', text: (r) => r.validTo == null ? '—' : Fmt.date(r.validTo), width: 110),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
    return AkDialog(
      title: 'Nouveau taux (ou nouvelle valeur d\'un taux existant)',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(controller: _code, label: 'Code (ex. TVA, AIB1)', mono: true, textCapitalization: TextCapitalization.characters),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _label, label: 'Libellé'),
          const SizedBox(height: AkSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkTextField(controller: _rate, label: 'Taux en % (ex. 18)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _from, label: 'Valide à partir du'),
              ),
            ],
          ),
          if (_error != null) _formError(_error!),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: () async {
            final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
            final from = Fmt.parseDate(_from.text);
            if (!RegExp(r'^[A-Z0-9_]{2,20}$').hasMatch(_code.text.trim().toUpperCase()) ||
                _label.text.trim().isEmpty ||
                rate == null ||
                rate < 0 ||
                rate > 100 ||
                from == null) {
              setState(() => _error = 'Code, libellé, taux (0-100) et date valides requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesServiceProvider).addTaxRate(cabinet!.id, code: _code.text, label: _label.text, rate: rate / 100, validFrom: from);
              ref.invalidate(taxRatesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
        ),
      ],
    );
  }
}
