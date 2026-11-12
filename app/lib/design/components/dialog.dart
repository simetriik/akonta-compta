import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';

/// Largeur d'un dialogue : trois tailles, rien d'autre (jetons `dialog-s`, `dialog-m`, `dialog-l`).
enum AkDialogSize {
  s(AkSpace.dialogS),
  m(AkSpace.dialogM),
  l(AkSpace.dialogL);

  const AkDialogSize(this.width);
  final double width;
}

/// Boîte de dialogue unique : titre, contenu défilant, actions alignées à droite (secondaire puis principale).
class AkDialog extends StatelessWidget {
  const AkDialog({super.key, required this.title, required this.content, this.actions = const [], this.size = AkDialogSize.m});

  final String title;
  final Widget content;
  final List<Widget> actions;
  final AkDialogSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    // Un dialogue ouvert depuis un contexte au thème local (cellule de la grille de saisie : champs sans bordure) en
    // hérite par `showDialog`. On revient au thème de l'application, celui du navigateur racine.
    final appTheme = Theme.of(Navigator.of(context, rootNavigator: true).context);
    return Theme(
      data: appTheme,
      child: AlertDialog(
        title: Text(title, style: AkText.heading.copyWith(color: t.textStrong)),
        titlePadding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s6, AkSpace.s6, AkSpace.s3),
        contentPadding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
        actionsPadding: const EdgeInsets.all(AkSpace.s4),
        actionsOverflowButtonSpacing: AkSpace.s2,
        insetPadding: const EdgeInsets.all(AkSpace.s4),
        elevation: 0,
        content: SizedBox(
          width: size.width,
          child: SingleChildScrollView(
            child: DefaultTextStyle.merge(
              style: AkText.body.copyWith(color: t.text),
              child: content,
            ),
          ),
        ),
        actions: [for (final a in actions) a],
      ),
    );
  }
}

/// Dialogue de confirmation : renvoie true si l'utilisateur confirme. [danger] met le bouton en cramoisi.
Future<bool> showAkConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AkDialog(
      title: title,
      content: Text(message),
      actions: [
        AkButton.secondary(cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
        if (danger)
          AkButton.danger(confirmLabel, onPressed: () => Navigator.pop(ctx, true))
        else
          AkButton.primary(confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return ok ?? false;
}
