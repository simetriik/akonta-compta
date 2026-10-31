import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../widgets/async_view.dart';
import '../../application/providers/consultation_providers.dart';
import '../../domain/consultation_models.dart';
import 'consultation_widgets.dart';

class AuxiliaryTab extends ConsumerWidget {
  const AuxiliaryTab({super.key, required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(auxiliaryBalanceProvider(params));
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(auxiliaryBalanceProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucun mouvement de tiers sur la période.');
        AkColumn<BalanceRow> code(String label, String Function(BalanceRow) f, double w) =>
            AkColumn(label: label, width: w, cell: (c, r) => consultationCode(c, f(r)));
        AkColumn<BalanceRow> amount(String label, int Function(BalanceRow) f) =>
            AkColumn(label: label, width: 112, numeric: true, cell: (c, r) => consultationAmount(Fmt.fcfa(f(r))));
        return SingleChildScrollView(
          child: AkTable<BalanceRow>(
            bare: true,
            minWidth: 1100,
            rows: list,
            columns: [
              code('Collectif', (r) => r.accountCode, 100),
              code('Tiers', (r) => r.thirdPartyCode ?? '', 96),
              AkColumn(label: 'Nom', flex: 1, cell: (c, r) => consultationText(c, r.thirdPartyName ?? '')),
              amount('Ouverture débit', (r) => r.openingDebit),
              amount('Ouverture crédit', (r) => r.openingCredit),
              amount('Mouvements débit', (r) => r.periodDebit),
              amount('Mouvements crédit', (r) => r.periodCredit),
              amount('Clôture débit', (r) => r.closingDebit),
              amount('Clôture crédit', (r) => r.closingCredit),
            ],
          ),
        );
      },
    );
  }
}
