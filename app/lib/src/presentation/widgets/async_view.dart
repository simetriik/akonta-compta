import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_display.dart';

/// Affichage uniforme d'une valeur asynchrone : chargement, erreur avec relance, contenu.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const AkLoading(),
      error: (e, stack) {
        final app = humanizeError(e, stack);
        return AkErrorMessage(app.display, onRetry: app.retryable || app.kind == AppErrorKind.unknown ? onRetry : null);
      },
      data: builder,
    );
  }
}
