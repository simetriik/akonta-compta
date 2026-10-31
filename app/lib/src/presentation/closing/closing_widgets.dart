import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

/// Marge des corps d'étape : latérale selon la taille d'écran, 16 px en haut et en bas.
EdgeInsets closingBodyPadding(BuildContext context) => EdgeInsets.symmetric(horizontal: akPageMargin(context), vertical: AkSpace.s4);

/// Liste de lignes séparées par des filets, dans une carte sans marge interne.
Widget closingRowsCard(BuildContext context, List<Widget> rows) {
  final t = context.ak;
  return AkCard(
    padding: EdgeInsets.zero,
    clip: true,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(height: 1, color: t.border), rows[i]],
      ],
    ),
  );
}

/// Dialogue à un seul champ texte obligatoire (commentaire de levée d'alerte, motif de réouverture).
/// Renvoie le texte saisi, ou null si l'utilisateur annule.
Future<String?> askText(BuildContext context, {required String title, required String label, required String confirmLabel}) => showDialog<String>(
  context: context,
  builder: (_) => TextPromptDialog(title: title, label: label, confirmLabel: confirmLabel),
);

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({super.key, required this.title, required this.label, required this.confirmLabel});

  final String title;
  final String label;
  final String confirmLabel;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: widget.title,
      content: AkTextField(controller: _ctrl, autofocus: true, label: widget.label),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(widget.confirmLabel, onPressed: () => Navigator.pop(context, _ctrl.text)),
      ],
    );
  }
}
