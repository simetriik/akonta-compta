import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../widgets/async_view.dart';
import '../../application/providers/consultation_providers.dart';
import '../../domain/consultation_models.dart';
import 'consultation_widgets.dart';

class BalanceTab extends ConsumerWidget {
  const BalanceTab({super.key, required this.params, this.previous});

  final ConsultationParams params;
  final ConsultationParams? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(trialBalanceProvider(params));
    final prevRows = previous == null ? null : ref.watch(trialBalanceProvider(previous!)).value;
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(trialBalanceProvider(params)),
      builder: (list) {
        final prevByCode = {for (final r in prevRows ?? const <BalanceRow>[]) r.accountCode: r};
        int t(int Function(BalanceRow) f) => list.fold(0, (s, r) => s + f(r));
        final withPrev = previous != null;
        final grid = <AkGridRow>[];
        int? lastClass;
        for (final r in list) {
          final cls = r.accountCode.isEmpty ? null : int.tryParse(r.accountCode[0]);
          if (cls != null && cls != lastClass) {
            lastClass = cls;
            final label = accountClassLabel(cls);
            grid.add(AkGridRow.section(consultationSection(context, label.isEmpty ? 'Classe $cls' : 'Classe $cls · $label')));
          }
          final prev = prevByCode[r.accountCode];
          grid.add(
            AkGridRow([
              consultationCode(context, r.accountCode),
              consultationText(context, r.accountLabel),
              consultationAmount(Fmt.fcfa(r.openingDebit)),
              consultationAmount(Fmt.fcfa(r.openingCredit)),
              consultationAmount(Fmt.fcfa(r.periodDebit)),
              consultationAmount(Fmt.fcfa(r.periodCredit)),
              consultationAmount(Fmt.fcfa(r.closingDebit)),
              consultationAmount(Fmt.fcfa(r.closingCredit)),
              if (withPrev) consultationAmount(Fmt.balance((prev?.closingDebit ?? 0) - (prev?.closingCredit ?? 0))),
            ]),
          );
        }
        grid.add(
          AkGridRow([
            const SizedBox.shrink(),
            consultationText(context, 'Totaux', bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.openingDebit), showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.openingCredit), showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.periodDebit), showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.periodCredit), showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.closingDebit), showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(t((r) => r.closingCredit), showZero: true), bold: true),
            if (withPrev) const SizedBox.shrink(),
          ], kind: AkGridRowKind.total),
        );
        return AkGrid(
          groups: [...balanceGroups, if (withPrev) ('', 1)],
          columns: [
            const AkGridColumn('Compte', 110),
            const AkGridColumn('Intitulé', 260, grow: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            const AkGridColumn('Débit', 112, numeric: true),
            const AkGridColumn('Crédit', 112, numeric: true),
            if (withPrev) const AkGridColumn('Solde N-1', 120, numeric: true),
          ],
          rows: grid,
        );
      },
    );
  }
}
