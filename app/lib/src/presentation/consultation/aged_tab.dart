import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../widgets/async_view.dart';
import '../../application/providers/consultation_providers.dart';
import '../../domain/consultation_models.dart';
import 'consultation_widgets.dart';

class AgedTab extends ConsumerWidget {
  const AgedTab({super.key, required this.params, required this.side, required this.onSide});

  final ConsultationParams params;
  final String side;
  final ValueChanged<String> onSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final rows = ref.watch(agedBalanceProvider(params));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s3),
          child: Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AkSegmented<String>(
                options: const [AkOption('debit', 'Clients (débiteurs)'), AkOption('credit', 'Fournisseurs (créditeurs)')],
                selected: side,
                onChanged: onSide,
              ),
              Text('À la date du ${Fmt.date(params.to)} · lignes non lettrées', style: AkText.caption.copyWith(color: t.textMuted)),
            ],
          ),
        ),
        Divider(height: 1, color: t.border),
        Expanded(
          child: AsyncView(
            value: rows,
            onRetry: () => ref.invalidate(agedBalanceProvider(params)),
            builder: (list) {
              if (list.isEmpty) return const AkEmptyState('Aucune ligne non lettrée à cette date.');
              AkColumn<AgedRow> amount(String label, int Function(AgedRow) f, {double w = 110, bool bold = false}) => AkColumn(
                label: label,
                width: w,
                numeric: true,
                cell: (c, r) => consultationAmount(Fmt.fcfa(f(r), showZero: bold), bold: bold),
              );
              return SingleChildScrollView(
                child: AkTable<AgedRow>(
                  bare: true,
                  minWidth: 960,
                  rows: list,
                  columns: [
                    AkColumn(label: 'Compte', width: 100, cell: (c, r) => consultationCode(c, r.accountCode)),
                    AkColumn(label: 'Tiers', width: 96, cell: (c, r) => consultationCode(c, r.thirdPartyCode)),
                    AkColumn(label: 'Nom', flex: 1, cell: (c, r) => consultationText(c, r.thirdPartyName)),
                    amount('0-30 j', (r) => r.d0_30),
                    amount('31-60 j', (r) => r.d31_60),
                    amount('61-90 j', (r) => r.d61_90),
                    amount('91-180 j', (r) => r.d91_180),
                    amount('> 180 j', (r) => r.over180),
                    amount('Total', (r) => r.total, w: 130, bold: true),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
