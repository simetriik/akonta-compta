import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/closing_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';
import '../../application/closing/tax_worksheet.dart';
import '../../application/providers/closing_providers.dart';
import '../widgets/async_view.dart';

class TaxStep extends ConsumerStatefulWidget {
  const TaxStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<TaxStep> createState() => _TaxStepState();
}

class _TaxStepState extends ConsumerState<TaxStep> {
  /// Dernier calcul fait depuis cet écran ; à défaut, celui déjà enregistré pour l'exercice.
  TaxComputation? _computed;
  bool _busy = false;
  final _amountControllers = <TaxAdjustment, TextEditingController>{};

  ClosingKey get _key => (entityId: widget.entity.id, fyId: widget.fy.id);

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: ref.watch(taxWorksheetProvider(_key)),
      onRetry: () => ref.invalidate(taxWorksheetProvider(_key)),
      builder: (sheet) => _content(context, sheet),
    );
  }

  Widget _content(BuildContext context, TaxWorksheet sheet) {
    final t = context.ak;
    final adj = sheet.adjustments;
    final result = _computed ?? sheet.computation;
    return ListView(
      padding: closingBodyPadding(context),
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Tableau de passage du résultat comptable au résultat fiscal'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Résultat comptable avant impôt : ${Fmt.fcfa(sheet.accountingResult, showZero: true)} FCFA',
                style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text),
              ),
              const SizedBox(height: AkSpace.s2),
              for (final a in adj)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: a.kind == 'add_back'
                              ? AkBadge(label: 'Réintégration', color: t.warning, tint: t.warningTint, icon: Icons.add)
                              : AkBadge(label: 'Déduction', color: t.success, tint: t.successTint, icon: Icons.remove),
                        ),
                      ),
                      Expanded(
                        child: Text(a.label, style: AkText.body.copyWith(color: t.text)),
                      ),
                      SizedBox(
                        width: 160,
                        child: AkAmountField(
                          controller: _amountControllers.putIfAbsent(a, () => TextEditingController(text: a.amount == 0 ? '' : Fmt.fcfa(a.amount))),
                          dense: true,
                          showCurrency: false,
                          onChanged: (v) => setState(() => a.amount = v),
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: AkSpace.s6, color: t.border),
              Text(
                'Résultat fiscal : ${Fmt.fcfa(sheet.taxableResult, showZero: true)} FCFA',
                style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text),
              ),
              const SizedBox(height: AkSpace.s3),
              AkButton.primary(
                'Calculer l\'IS et générer l\'écriture (brouillard)',
                icon: Icons.calculate_outlined,
                loading: _busy,
                onPressed: () async {
                  setState(() => _busy = true);
                  try {
                    final r = await ref.read(closingServiceProvider).computeTax(widget.entity.id, widget.fy.id, adj);
                    setState(() => _computed = r);
                    ref.invalidate(entityDashboardProvider);
                  } catch (e) {
                    if (context.mounted) showErrorSnack(context, errorText(e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ],
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: AkSpace.s3),
          AkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AkSectionTitle('Impôt sur les sociétés'),
                const SizedBox(height: AkSpace.s2),
                Text(
                  'IS au taux de ${(result.isRate * 100).toStringAsFixed(0)} % : ${Fmt.fcfa(result.computedTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'Minimum d\'impôt (sur CA ${Fmt.fcfa(result.revenue, showZero: true)}, plancher 250 000) : ${Fmt.fcfa(result.minimumTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'IS dû : ${Fmt.fcfa(result.taxDue, showZero: true)} · acomptes 4492 : ${Fmt.fcfa(result.prepayments, showZero: true)} · solde à payer : ${Fmt.fcfa(result.balanceDue, showZero: true)}',
                  style: AkText.bodyStrong.copyWith(color: t.text),
                ),
                if (result.entryId != null) AkButton.ghost('Ouvrir l\'écriture d\'IS', onPressed: () => context.go('/saisie/${result.entryId}')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
