import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:akonta/design/design.dart';

import 'copy_text_stub.dart' if (dart.library.js_interop) 'copy_text_web.dart';

/// Copie [text] dans le presse-papiers ; renvoie `false` si la copie a échoué.
/// Sur le web, la copie « classique » passe d'abord : l'API moderne du navigateur est absente d'une page servie en
/// HTTP hors `localhost` (recette en réseau local), et Flutter n'y signale alors aucune erreur.
Future<bool> copyText(String text) async {
  if (legacyCopy(text)) return true;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } on PlatformException {
    return false;
  }
}

/// Copie puis informe l'utilisateur : « copié » seulement si la copie a réellement réussi.
Future<void> copyWithFeedback(BuildContext context, String text, {required String successMessage}) async {
  final ok = await copyText(text);
  if (!context.mounted) return;
  showAkToast(context, ok ? successMessage : 'Copie impossible : sélectionnez le texte et copiez-le à la main.');
}
