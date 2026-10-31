import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';

import '../../core/errors/errors.dart';

export '../../core/errors/errors.dart' show AppError, AppErrorKind, errorText, humanizeError;

/// Toast d'erreur uniforme : message en français sans détail technique, précédé s'il y a lieu de l'action tentée.
/// À préférer à tout affichage direct d'une exception.
void showError(BuildContext context, Object error, {String? action}) {
  showAkToast(context, errorText(error, action: action), kind: AkToastKind.danger);
}

/// Une nouvelle tentative a-t-elle un sens pour cette erreur ? (réseau, délai, service indisponible, erreur inattendue)
bool canRetry(Object error) {
  final e = humanizeError(error);
  return e.retryable || e.kind == AppErrorKind.unknown;
}
