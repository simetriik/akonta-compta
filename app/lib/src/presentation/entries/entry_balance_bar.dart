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
    this.incomplete = false,
    required this.onSave,
    required this.onValidate,
  });

  final int debit;
  final int credit;
  final int balance;
  final bool readOnly;
  final bool busy;
  final bool canValidate;

  /// Une ligne n'a pas de compte : l'équilibre affiché ne suffit pas à valider.
  final bool incomplete;
  final VoidCallback onSave;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final balanced = balance == 0;
    final warn = balanced && incomplete;
    final color = balanced && !warn ? t.success : (warn ? t.warning : t.danger);
    final mobile = akIsCompact(context);
    Widget total(String label, int v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AkText.caption.copyWith(color: t.textMuted)),
        Text(Fmt.fcfa(v, showZero: true), style: AkText.amountTotal.copyWith(color: t.textStrong)),
      ],
    );
    final chip = Container(
      key: const Key('balance-chip'),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s1),
      decoration: BoxDecoration(color: warn ? t.warningTint : (balanced ? t.successTint : t.dangerTint), borderRadius: AkRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(warn ? Icons.warning_amber : (balanced ? Icons.check_circle_outline : Icons.error_outline), size: AkSpace.iconMd, color: color),
          const SizedBox(width: AkSpace.s2),
          Flexible(
            child: Text(
              balanced
                  ? (warn ? 'Équilibrée · une ligne sans compte' : 'Équilibrée')
                  : 'Écart ${Fmt.fcfa(balance.abs())} · ${balance > 0 ? 'débit' : 'crédit'} supérieur',
              style: AkText.bodyStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    final saveButton = AkButton.secondary(
      mobile ? 'Enregistrer' : 'Enregistrer le brouillard',
      key: const Key('save-draft'),
      expand: mobile,
      onPressed: busy ? null : onSave,
    );
    final validateButton = AkButton.primary(
      mobile ? 'Valider' : 'Valider l\'écriture',
      key: const Key('validate-entry'),
      expand: mobile,
      onPressed: busy || !balanced ? null : onValidate,
    );
    final actions = Row(
      children: [
        Expanded(child: saveButton),
        if (canValidate) ...[const SizedBox(width: AkSpace.s2), Expanded(child: validateButton)],
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: akPageMargin(context), vertical: AkSpace.s3),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chip,
                if (!readOnly) ...[const SizedBox(height: AkSpace.s2), actions],
              ],
            )
          : Wrap(
              spacing: AkSpace.s4,
              runSpacing: AkSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
              children: [
                if (!mobile) ...[total('Débit', debit), total('Crédit', credit)],
                chip,
                if (!readOnly) ...[saveButton, if (canValidate) validateButton],
              ],
            ),
    );
  }
}
