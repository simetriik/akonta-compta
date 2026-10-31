import 'package:flutter/foundation.dart';

import 'error_mapper.dart';

/// Branche les erreurs non rattrapées (framework et zone asynchrone) sur le journal technique : elles reçoivent une référence
/// et ne sont plus perdues. Le comportement par défaut de Flutter (affichage en console) est conservé.
void installErrorHooks() {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    humanizeError(details.exception, details.stack);
    previousFlutterHandler?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    humanizeError(error, stack);
    return false; // laisse l'erreur remonter comme avant
  };
}
