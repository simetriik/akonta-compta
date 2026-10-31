import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

Widget consultationText(BuildContext context, String s, {bool bold = false, bool muted = false}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.table.copyWith(color: muted ? context.ak.textMuted : context.ak.text, fontWeight: bold ? FontWeight.w600 : null),
);

Widget consultationCode(BuildContext context, String s, {bool bold = false}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.code.copyWith(color: context.ak.text, fontWeight: bold ? FontWeight.w600 : null),
);

Widget consultationAmount(String s, {bool bold = false}) => AkAmountText(s, bold: bold);

/// Libellé de classe SYSCOHADA pour les lignes de section de la balance.
String accountClassLabel(int c) => switch (c) {
  1 => 'Ressources durables',
  2 => 'Actif immobilisé',
  3 => 'Stocks',
  4 => 'Tiers',
  5 => 'Trésorerie',
  6 => 'Charges des activités ordinaires',
  7 => 'Produits des activités ordinaires',
  8 => 'Autres charges et produits',
  _ => '',
};

Widget consultationSection(BuildContext context, String s) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AkText.bodyStrong.copyWith(color: context.ak.text),
);

const balanceGroups = <(String, int)>[('', 2), ('Ouverture', 2), ('Mouvements', 2), ('Clôture', 2)];
