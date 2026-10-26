import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';

/// Boîte de dialogue unique : titre, contenu défilant, actions alignées à droite (secondaire puis principale).
class AkDialog extends StatelessWidget {
  const AkDialog({super.key, required this.title, required this.content, this.actions = const [], this.width = 480});

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AlertDialog(
      title: Text(title, style: AkText.title.copyWith(color: t.text)),
      titlePadding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s6, AkSpace.s6, AkSpace.s3),
      contentPadding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
      actionsPadding: const EdgeInsets.all(AkSpace.s4),
      actionsOverflowButtonSpacing: AkSpace.s2,
      insetPadding: const EdgeInsets.all(AkSpace.s4),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: DefaultTextStyle.merge(
            style: AkText.body.copyWith(color: t.text),
            child: content,
          ),
        ),
      ),
      actions: [for (final a in actions) a],
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
