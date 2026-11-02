import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/services.dart';
import '../../domain/entry_models.dart';
import '../widgets/error_display.dart';

/// Renvoie un brouillard de client avec un motif obligatoire ; renvoie true si le brouillard a été renvoyé.
Future<bool> showReturnDraftDialog(BuildContext context, WidgetRef ref, String entryId) async {
  final comment = await showDialog<String>(context: context, builder: (_) => const _ReturnDraftDialog());
  if (comment == null || !context.mounted) return false;
  if (comment.trim().isEmpty) {
    showAkToast(context, 'Le motif est obligatoire.', kind: AkToastKind.warning);
    return false;
  }
  try {
    await ref.read(clientAccessServiceProvider).returnDraft(entryId, comment);
    if (context.mounted) showAkToast(context, 'Brouillard renvoyé au client');
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e, action: 'Le renvoi');
    return false;
  }
}

/// La boîte possède son champ de saisie : il n'est libéré qu'une fois la boîte refermée.
class _ReturnDraftDialog extends StatefulWidget {
  const _ReturnDraftDialog();

  @override
  State<_ReturnDraftDialog> createState() => _ReturnDraftDialogState();
}

class _ReturnDraftDialogState extends State<_ReturnDraftDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Renvoyer au client',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Le client verra ce motif sur son brouillard et sera notifié. L\'écriture reste en brouillard.'),
          const SizedBox(height: AkSpace.s3),
          AkTextField(key: const Key('return-comment'), controller: _controller, label: 'Motif', minLines: 2, maxLines: 4, autofocus: true),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Renvoyer', key: const Key('return-submit'), onPressed: () => Navigator.pop(context, _controller.text)),
      ],
    );
  }
}

/// Sous l'en-tête d'une écriture : le motif renvoyé par le cabinet (côté client) et le bouton « Renvoyer au client » (côté cabinet).
class DraftReturnArea extends StatelessWidget {
  const DraftReturnArea({super.key, required this.entry, required this.canReturn, required this.onReturn});

  final EntryModel? entry;
  final bool canReturn;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.returnedComment != null)
          Padding(padding: const EdgeInsets.only(top: AkSpace.s3), child: AkBanner(kind: AkBannerKind.warning, child: Text('À corriger : ${e.returnedComment}'))),
        if (e.isDraft && canReturn)
          Padding(
            padding: const EdgeInsets.only(top: AkSpace.s3),
            child: Align(alignment: Alignment.centerLeft, child: AkButton.secondary('Renvoyer au client', key: const Key('return-draft'), onPressed: onReturn)),
          ),
      ],
    );
  }
}
