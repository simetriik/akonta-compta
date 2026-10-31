import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';

/// Barre fixe en bas de l'écran : totaux, équilibre de l'écriture (toujours visible) et actions d'enregistrement.
class EntryBalanceBar extends StatelessWidget {
  const EntryBalanceBar({
    super.key,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.readOnly,
    required this.busy,
    required this.canValidate,
    required this.onSave,
    required this.onValidate,
  });

  final int debit;
  final int credit;
  final int balance;
  final bool readOnly;
  final bool busy;
  final bool canValidate;
  final VoidCallback onSave;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final balanced = balance == 0;
    final color = balanced ? t.success : t.danger;
    final mobile = akIsCompact(context);
    Widget total(String label, int v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AkText.caption.copyWith(color: t.textMuted)),
        Text(Fmt.fcfa(v, showZero: true), style: AkText.amountTotal.copyWith(color: t.textStrong)),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: akPageMargin(context), vertical: AkSpace.s3),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Wrap(
        spacing: AkSpace.s4,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
        children: [
          if (!mobile) ...[total('Débit', debit), total('Crédit', credit)],
          Container(
            key: const Key('balance-chip'),
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s1),
            decoration: BoxDecoration(color: balanced ? t.successTint : t.dangerTint, borderRadius: AkRadius.smAll),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(balanced ? Icons.check_circle_outline : Icons.error_outline, size: AkSpace.iconMd, color: color),
                const SizedBox(width: AkSpace.s2),
                Text(
                  balanced ? 'Équilibrée' : 'Écart ${Fmt.fcfa(balance.abs())} · ${balance > 0 ? 'débit' : 'crédit'} supérieur',
                  style: AkText.bodyStrong.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (!readOnly) ...[
            AkButton.secondary('Enregistrer le brouillard', key: const Key('save-draft'), onPressed: busy ? null : onSave),
            if (canValidate) AkButton.primary('Valider l\'écriture', key: const Key('validate-entry'), onPressed: busy || !balanced ? null : onValidate),
          ],
        ],
      ),
    );
  }
}
