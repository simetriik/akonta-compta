import 'package:flutter/material.dart';

import '../tokens.dart';

/// Largeurs des colonnes de la grille de saisie (jetons `col-*`).
abstract final class AkEntryGridCols {
  static const index = AkSpace.colIndex;
  static const account = AkSpace.colAccount;
  static const thirdParty = AkSpace.colThirdParty;

  /// Colonne Tiers réduite tant qu'aucune ligne n'a de tiers.
  static const thirdPartyEmpty = 64.0; // assez large pour l'en-tête « Tiers » en entier
  static const amount = AkSpace.colAmount;
  static const remove = AkSpace.colAction;
  static const labelMin = AkSpace.colLabel;

  /// Largeur minimale de la grille ; en dessous, elle défile horizontalement.
  static double minWidth({required bool withThirdParty}) =>
      index + account + (withThirdParty ? thirdParty : thirdPartyEmpty) + labelMin + 2 * amount + remove + 5 * AkSpace.s2 + 2 * AkSpace.s2;
}

/// Thème des cellules de la grille de saisie : un tableur, pas un formulaire.
/// Cellules sans bordure ni fond ; la cellule active montre l'anneau de focus de 2 px, une cellule invalide un trait `danger`.
class AkEntryGridTheme extends StatelessWidget {
  const AkEntryGridTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final theme = Theme.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: AkRadius.smAll,
      borderSide: BorderSide(color: color, width: width),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: false,
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          disabledBorder: border(Colors.transparent),
          focusedBorder: border(t.focus, 2),
          errorBorder: border(t.danger, 2),
          focusedErrorBorder: border(t.danger, 2),
        ),
      ),
      child: child,
    );
  }
}
