import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/inventory_providers.dart';
import '../../domain/inventory_models.dart';
import '../../application/providers/services.dart';
import 'inventory_widgets.dart';
import '../../application/rules/inventory_forms.dart';

class ProvisionsTab extends ConsumerStatefulWidget {
  const ProvisionsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<ProvisionsTab> createState() => _ProvisionsTabState();
}

class _ProvisionsTabState extends ConsumerState<ProvisionsTab> {
  final _r91 = TextEditingController(text: '25');
  final _r180 = TextEditingController(text: '50');

  @override
  Widget build(BuildContext context) {
    final provisions = ref.watch(provisionsProvider(widget.fy.id));
    final t = context.ak;
    return AsyncView(
      value: provisions,
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer dotations / reprises',
                icon: Icons.auto_awesome,
                onPressed: () => runGeneration(
                  context,
                  ref,
                  () => ref.read(inventoryServiceProvider).generateProvisionEntries(widget.entity.id, widget.fy.id),
                  'Provisions',
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkCard(
            child: Wrap(
              spacing: AkSpace.s3,
              runSpacing: AkSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AkSpace.s2),
                  child: Text('Créances douteuses depuis la balance âgée :', style: AkText.body.copyWith(color: t.text)),
                ),
                SizedBox(
                  width: 140,
                  child: AkTextField(controller: _r91, label: '91-180 j (%)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                SizedBox(
                  width: 140,
                  child: AkTextField(controller: _r180, label: '> 180 j (%)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                AkButton.secondary(
                  'Proposer',
                  onPressed: () async {
                    final form = InventoryForms.provisionRates(r91: _r91.text, r180: _r180.text);
                    if (form.error != null) {
                      showErrorSnack(context, form.error!);
                      return;
                    }
                    try {
                      final n = await ref
                          .read(inventoryServiceProvider)
                          .proposeReceivableProvisions(
                            widget.entity.id,
                            widget.fy.id,
                            rate91to180: form.value!.rate91to180,
                            rateOver180: form.value!.rateOver180,
                          );
                      ref.invalidate(provisionsProvider(widget.fy.id));
                      if (context.mounted) showAkToast(context, '$n provision(s) proposée(s).');
                    } catch (e) {
                      if (context.mounted) showErrorSnack(context, errorText(e));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          AkTable<ProvisionRow>(
            rows: list,
            minWidth: 760,
            emptyMessage: 'Aucune provision pour cet exercice.',
            columns: [
              AkColumn<ProvisionRow>(
                label: 'Provision',
                flex: 3,
                cell: (context, p) => Text(
                  '${p.kind == 'receivable' ? 'Créance' : 'Risque'} · ${p.thirdPartyCode ?? ''} · base ${Fmt.fcfa(p.baseAmount, showZero: true)}${p.rate != null ? ' × ${(p.rate! * 100).toStringAsFixed(0)} %' : ''}',
                  style: AkText.body.copyWith(color: t.text),
                ),
              ),
              AkColumn<ProvisionRow>(
                label: 'Détail',
                flex: 4,
                cell: (context, p) => Text(
                  'Provision N-1 ${Fmt.fcfa(p.previousAmount, showZero: true)} → N ${Fmt.fcfa(p.amount, showZero: true)} · ${p.amount - p.previousAmount >= 0 ? 'dotation' : 'reprise'} ${Fmt.fcfa((p.amount - p.previousAmount).abs(), showZero: true)}${p.note != null ? ' · ${p.note}' : ''}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ),
              AkColumn<ProvisionRow>(
                label: '',
                width: 48,
                cell: (context, p) => p.entryId != null
                    ? Icon(Icons.check_circle_outline, color: t.success)
                    : AkIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Modifier le montant',
                        dense: true,
                        onPressed: () async {
                          final c = TextEditingController(text: '${p.amount}');
                          final v = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AkDialog(
                              title: 'Montant de la provision',
                              content: AkAmountField(controller: c, autofocus: true),
                              actions: [
                                AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx)),
                                AkButton.primary('Valider', onPressed: () => Navigator.pop(ctx, c.text)),
                              ],
                            ),
                          );
                          final n = v == null ? null : Fmt.parseAmount(v);
                          if (n == null) return;
                          await ref.read(inventoryServiceProvider).updateProvisionAmount(p.id, n);
                          ref.invalidate(provisionsProvider(widget.fy.id));
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
