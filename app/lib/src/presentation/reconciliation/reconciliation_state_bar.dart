import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/bank_models.dart';

class ReconciliationStateBar extends StatelessWidget {
  const ReconciliationStateBar({super.key, required this.state});

  final ReconciliationStateModel state;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final ok = state.difference == 0;
    Widget cell(String label, int v) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
      child: AkCard(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AkText.caption.copyWith(color: t.textMuted)),
            Text(
              Fmt.fcfa(v, showZero: true),
              style: AkText.heading.copyWith(fontFamily: AkFonts.mono, fontFeatures: const [FontFeature.tabularFigures()], color: t.text),
            ),
          ],
        ),
      ),
    );
    return Wrap(
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s3,
      children: [
        cell('Solde comptable', state.bookBalance),
        cell('Solde banque', state.bankBalance),
        cell('+ Encaissements non crédités', state.depositsInTransit),
        cell('- Décaissements non débités', state.outstandingPayments),
        cell('+ Débits banque non comptabilisés', state.unmatchedBankDebits),
        cell('- Crédits banque non comptabilisés', state.unmatchedBankCredits),
        AkCard(
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Écart après rapprochement', style: AkText.caption.copyWith(color: t.textMuted)),
              const SizedBox(height: AkSpace.s1),
              AkBadge(
                key: const Key('recon-diff'),
                label: ok ? 'Écart 0 : rapproché' : 'Écart ${Fmt.fcfa(state.difference, showZero: true)}',
                color: ok ? t.success : t.danger,
                tint: ok ? t.successTint : t.dangerTint,
                icon: ok ? Icons.check_circle_outline : Icons.error_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
