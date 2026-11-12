import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../application/providers/closing_providers.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/rules/result_allocation.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';

class NextYearStep extends ConsumerStatefulWidget {
  const NextYearStep({super.key, required this.entity, required this.fy, this.next});

  final EntitySummary entity;
  final FiscalYear fy;
  final FiscalYear? next;

  @override
  ConsumerState<NextYearStep> createState() => _NextYearStepState();
}

class _NextYearStepState extends ConsumerState<NextYearStep> {
  final _legal = TextEditingController(text: '0');
  final _free = TextEditingController(text: '0');
  final _div = TextEditingController(text: '0');
  final _carry = TextEditingController(text: '0');
  final _date = TextEditingController(text: Fmt.date(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(closingServiceProvider);
    final next = widget.next;
    final t = context.ak;
    final pending = next == null ? (profit: 0, loss: 0) : (ref.watch(pendingResultsProvider((entityId: widget.entity.id, fyId: next.id))).value ?? (profit: 0, loss: 0));
    final showAllocation = pending.profit > 0 || pending.loss == 0;
    final nonProfit = ref.watch(entityProvider(widget.entity.id)).value?.accountingSystem == 'sycebnl';
    return ListView(
      padding: closingBodyPadding(context),
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Exercice suivant'),
              const SizedBox(height: AkSpace.s2),
              if (next == null)
                AkBanner(
                  kind: AkBannerKind.warning,
                  action: AkButton.ghost('Ouvrir le dossier', dense: true, onPressed: () => context.go('/dossiers/${widget.entity.id}')),
                  child: const Text('Créez l\'exercice suivant dans Dossiers → Exercices avant de générer les à-nouveaux.'),
                ),
              if (next != null) ...[
                Text(
                  'À-nouveaux de ${next.label} : soldes de bilan à la clôture de ${widget.fy.label}, détaillés par tiers ; résultat repris en 1300. Recalculables tant que ${widget.fy.label} n\'est pas arrêté (brouillard remplacé).',
                  style: AkText.body.copyWith(color: t.textMuted),
                ),
                const SizedBox(height: AkSpace.s2),
                AkButton.primary(
                  'Générer les à-nouveaux ${next.label}',
                  icon: Icons.auto_awesome,
                  onPressed: () => runGeneration(context, ref, () => repo.generateOpeningBalances(widget.entity.id, widget.fy.id), 'À-nouveaux ${next.label}')
                      .whenComplete(() => ref.invalidate(pendingResultsProvider)),
                ),
                Divider(height: AkSpace.s6, color: t.border),
                Text('Affectation du résultat de ${widget.fy.label} (en ${next.label})', style: AkText.bodyStrong.copyWith(color: t.text)),
                const SizedBox(height: AkSpace.s2),
                if (pending.profit > 0)
                  AkBanner(kind: AkBannerKind.info, child: Text('Bénéfice en instance : ${Fmt.fcfa(pending.profit, showZero: true)}, à répartir en totalité.')),
                if (pending.loss > 0) ...[
                  if (pending.profit > 0) const SizedBox(height: AkSpace.s2),
                  AkBanner(
                    kind: AkBannerKind.warning,
                    child: Text('Perte en instance : ${Fmt.fcfa(pending.loss, showZero: true)}. Elle se reporte à nouveau (compte 129), sans réserve ni dividende, et sans être compensée avec le bénéfice.'),
                  ),
                ],
                if (pending.profit == 0 && pending.loss == 0)
                  AkBanner(kind: AkBannerKind.info, child: Text('Aucun résultat en instance : générez puis validez les à-nouveaux ${next.label} avant l\'affectation.')),
                const SizedBox(height: AkSpace.s2),
                if (showAllocation) Wrap(
                  spacing: AkSpace.s2,
                  runSpacing: AkSpace.s2,
                  children: [
                    SizedBox(
                      width: 200,
                      child: AkAmountField(
                        controller: _legal,
                        label: nonProfit ? 'Réserves statutaires ou contractuelles (112)' : 'Réserve légale (111)',
                        showCurrency: false,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: AkAmountField(controller: _free, label: nonProfit ? 'Autres réserves (118)' : 'Réserves libres (118)', showCurrency: false),
                    ),
                    if (!nonProfit)
                      SizedBox(
                        width: 200,
                        child: AkAmountField(controller: _div, label: 'Dividendes (465)', showCurrency: false),
                      ),
                    SizedBox(
                      width: 200,
                      child: AkAmountField(
                        controller: _carry,
                        label: nonProfit ? 'Report à nouveau des excédents (121)' : 'Report à nouveau (121)',
                        showCurrency: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AkSpace.s2),
                SizedBox(width: 160, child: AkDateField(controller: _date, label: 'Date')),
                const SizedBox(height: AkSpace.s2),
                if (showAllocation) AkButton.secondary(
                  'Générer l\'écriture d\'affectation',
                  icon: Icons.call_split,
                  onPressed: () {
                    final d = Fmt.parseDate(_date.text);
                    if (d == null) return;
                    final legal = Fmt.parseAmount(_legal.text) ?? 0, free = Fmt.parseAmount(_free.text) ?? 0;
                    final dividends = Fmt.parseAmount(_div.text) ?? 0, carry = Fmt.parseAmount(_carry.text) ?? 0;
                    final problem = ResultAllocation.check(pending.profit, legal: legal, free: free, dividends: dividends, carry: carry);
                    if (problem != null) {
                      showErrorSnack(context, problem);
                      return;
                    }
                    runGeneration(
                      context,
                      ref,
                      () => repo.allocateResult(widget.entity.id, next.id, d, legalReserve: legal, freeReserve: free, dividends: dividends, carryForward: carry),
                      'Affectation du résultat',
                    ).whenComplete(() => ref.invalidate(pendingResultsProvider));
                  },
                ),
                if (pending.loss > 0) ...[
                  if (showAllocation) const SizedBox(height: AkSpace.s2),
                  AkButton.secondary(
                    'Reporter la perte à nouveau',
                    icon: Icons.south_east,
                    onPressed: () {
                      final d = Fmt.parseDate(_date.text);
                      if (d == null) return;
                      runGeneration(context, ref, () => repo.carryForwardLoss(widget.entity.id, next.id, d), 'Report à nouveau de la perte')
                          .whenComplete(() => ref.invalidate(pendingResultsProvider));
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
