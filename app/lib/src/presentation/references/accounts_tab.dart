import 'references_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../../application/rules/account_selection.dart';

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
        ListToolbar(
          filters: [
            ToolbarSearchField(hint: 'Numéro ou intitulé', onChanged: (v) => setState(() => _search = v.trim().toLowerCase())),
            toolbarDropdown<int?>(
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
              final filtered = AccountSelection.filterPlan(list, search: _search, classNo: _classFilter);
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
                  return ListRow(
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
                            child: InactiveBadge(),
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
          final label = await promptText(context, 'Nouvel intitulé', a.label);
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
    ref
        .read(entityProvider(widget.entity.id).future)
        .then((e) {
          if (mounted) setState(() => _length = e.accountLength);
        })
        .catchError((Object e) {
          // Longueur par défaut conservée ; le serveur refuse de toute façon un numéro de mauvaise longueur.
          if (mounted) setState(() => _error = errorText(e));
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
          if (_error != null) formError(_error!, key: const Key('account-error')),
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
