import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../widgets/error_display.dart';

import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/inventory_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../domain/inventory_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import 'inventory_widgets.dart';
import '../../application/rules/account_selection.dart';
import '../../application/rules/inventory_forms.dart';

class AccrualsTab extends ConsumerWidget {
  const AccrualsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final accruals = ref.watch(accrualsProvider(fy.id));
    return AsyncView(
      value: accruals,
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer au 31/12',
                icon: Icons.auto_awesome,
                onPressed: () =>
                    runGeneration(context, ref, () => ref.read(inventoryServiceProvider).generateAccruals(entity.id, fy.id), 'Régularisations au 31/12'),
              ),
              AkButton.secondary(
                'Extournes N+1',
                icon: Icons.undo,
                onPressed: () async {
                  try {
                    final ids = await ref.read(inventoryServiceProvider).generateReversals(entity.id, fy.id);
                    if (context.mounted) {
                      showAkToast(context, '${ids.length} extourne(s) générée(s) au 1er janvier N+1.');
                    }
                  } catch (e) {
                    if (context.mounted) showErrorSnack(context, errorText(e));
                  }
                },
              ),
              AkButton.secondary(
                'Régularisation',
                icon: Icons.add,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AccrualDialog(entity: entity, fy: fy),
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkTable<AccrualRow>(
            rows: list,
            minWidth: 760,
            emptyMessage: 'Aucune régularisation saisie.',
            columns: [
              AkColumn<AccrualRow>(
                label: 'Régularisation',
                flex: 3,
                cell: (context, a) => Text('${AccrualRow.kindLabels[a.kind]} · ${a.description}', style: AkText.body.copyWith(color: t.text)),
              ),
              AkColumn<AccrualRow>(
                label: 'Détail',
                flex: 4,
                cell: (context, a) => Text(
                  '${a.accountCode} / ${a.counterpartCode} · ${Fmt.fcfa(a.totalAmount, showZero: true)} du ${Fmt.date(a.periodFrom)} au ${Fmt.date(a.periodTo)} · part régularisée ${Fmt.fcfa(a.amount, showZero: true)}${a.entryId != null ? ' · écriture générée' : ''}${a.reversalEntryId != null ? ' · extournée' : ''}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ),
              AkColumn<AccrualRow>(
                label: '',
                width: 48,
                cell: (context, a) => a.entryId == null
                    ? AkIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Supprimer',
                        dense: true,
                        onPressed: () async {
                          final ok = await showAkConfirm(
                            context,
                            title: 'Supprimer cette régularisation ?',
                            message: 'La ligne de régularisation sera supprimée. Aucune écriture n\'a encore été générée.',
                            confirmLabel: 'Supprimer',
                            danger: true,
                          );
                          if (!ok || !context.mounted) return;
                          try {
                            await ref.read(inventoryServiceProvider).deleteAccrual(a.id);
                            ref.invalidate(accrualsProvider(fy.id));
                          } catch (e) {
                            if (context.mounted) showError(context, e, action: 'Suppression impossible');
                          }
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccrualDialog extends ConsumerStatefulWidget {
  const AccrualDialog({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<AccrualDialog> createState() => _AccrualDialogState();
}

class _AccrualDialogState extends ConsumerState<AccrualDialog> {
  String _kind = 'cca';
  final _desc = TextEditingController();
  final _total = TextEditingController();
  late final _from = TextEditingController(text: Fmt.date(widget.fy.startDate));
  late final _to = TextEditingController(text: Fmt.date(widget.fy.endDate));
  String? _account;
  String? _counterpart;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = AccountSelection.postable(ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]);
    final defaultCounterpart = AccountSelection.accrualDefaultPrefix(_kind);
    return AkDialog(
      title: 'Régularisation',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDropdown<String>(
            label: 'Type',
            value: _kind,
            items: [for (final e in AccrualRow.kindLabels.entries) AkOption(e.key, e.value)],
            onChanged: (v) => setState(() => _kind = v ?? 'cca'),
          ),
          const SizedBox(height: AkSpace.s2),
          AkTextField(controller: _desc, label: 'Description'),
          const SizedBox(height: AkSpace.s2),
          AkAccountField(label: 'Compte de charge ou de produit', accounts: AccountSelection.accrualResults(accounts), onSelected: (a) => _account = a.id),
          const SizedBox(height: AkSpace.s2),
          AkAccountField(
            label: 'Compte de régularisation (défaut $defaultCounterpart)',
            accounts: AccountSelection.accrualCounterparts(accounts),
            selected: AccountSelection.accrualCounterparts(accounts).where((a) => a.code.startsWith(defaultCounterpart)).firstOrNull,
            onSelected: (a) => _counterpart = a.id,
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _total, label: 'Montant total', showCurrency: false),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _from, label: 'Période du'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _to, label: 'au'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Prorata au jour (base 360) calculé à la génération ; extourne automatique au 1er janvier N+1.',
            style: AkText.caption.copyWith(color: context.ak.textMuted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Ajouter',
          onPressed: () async {
            final counterpart = _counterpart ?? accounts.where((a) => a.code.startsWith(defaultCounterpart)).firstOrNull?.id;
            final form = InventoryForms.accrual(
              description: _desc.text,
              accountId: _account,
              counterpartAccountId: counterpart,
              total: _total.text,
              from: _from.text,
              to: _to.text,
            );
            if (form.error != null) {
              setState(() => _error = form.error);
              return;
            }
            final v = form.value!;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(inventoryServiceProvider)
                  .addAccrual(
                    cabinet!.id,
                    widget.entity.id,
                    widget.fy.id,
                    kind: _kind,
                    description: v.description,
                    accountId: _account!,
                    counterpartAccountId: v.counterpartAccountId,
                    totalAmount: v.totalAmount,
                    from: v.from,
                    to: v.to,
                  );
              ref.invalidate(accrualsProvider(widget.fy.id));
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
