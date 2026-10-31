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

class TaxStep extends ConsumerStatefulWidget {
  const TaxStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<TaxStep> createState() => _TaxStepState();
}

class _TaxStepState extends ConsumerState<TaxStep> {
  List<TaxAdjustment>? _adjustments;
  TaxComputation? _result;
  int? _accounting;
  bool _busy = false;
  final _amountControllers = <TaxAdjustment, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(closingServiceProvider);
    final adj = await repo.proposeAdjustments(widget.entity.id, widget.fy.id);
    final acc = await repo.accountingResult(widget.entity.id, widget.fy.id);
    final res = await repo.taxComputation(widget.fy.id);
    if (!mounted) return;
    setState(() {
      _adjustments = adj;
      _accounting = acc;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final adj = _adjustments;
    if (adj == null) return const AkLoading();
    final addBacks = adj.where((a) => a.kind == 'add_back').fold<int>(0, (s, a) => s + a.amount);
    final deductions = adj.where((a) => a.kind == 'deduction').fold<int>(0, (s, a) => s + a.amount);
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
                'Résultat comptable avant impôt : ${Fmt.fcfa(_accounting, showZero: true)} FCFA',
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
                'Résultat fiscal : ${Fmt.fcfa((_accounting ?? 0) + addBacks - deductions, showZero: true)} FCFA',
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
                    setState(() => _result = r);
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
        if (_result != null) ...[
          const SizedBox(height: AkSpace.s3),
          AkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AkSectionTitle('Impôt sur les sociétés'),
                const SizedBox(height: AkSpace.s2),
                Text(
                  'IS au taux de ${(_result!.isRate * 100).toStringAsFixed(0)} % : ${Fmt.fcfa(_result!.computedTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'Minimum d\'impôt (sur CA ${Fmt.fcfa(_result!.revenue, showZero: true)}, plancher 250 000) : ${Fmt.fcfa(_result!.minimumTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'IS dû : ${Fmt.fcfa(_result!.taxDue, showZero: true)} · acomptes 4492 : ${Fmt.fcfa(_result!.prepayments, showZero: true)} · solde à payer : ${Fmt.fcfa(_result!.balanceDue, showZero: true)}',
                  style: AkText.bodyStrong.copyWith(color: t.text),
                ),
                if (_result!.entryId != null) AkButton.ghost('Ouvrir l\'écriture d\'IS', onPressed: () => context.go('/saisie/${_result!.entryId}')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
