import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'ak_widgets.dart';

/// Vrai sur les écrans étroits (< 600 px) : contrôles tactiles de 44 px, marge de 16 px.
bool akIsCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// Marge latérale des écrans : 24 px sur ordinateur, 16 px sur mobile.
double akPageMargin(BuildContext context) => akIsCompact(context) ? AkSpace.s4 : AkSpace.s6;

/// Hauteur d'un contrôle : 32 px sur ordinateur, 44 px sur mobile.
double akControlHeight(BuildContext context) => akIsCompact(context) ? AkSpace.controlTouch : AkSpace.controlCompact;

/// État vide : icône discrète et message, centrés.
class AkEmptyState extends StatelessWidget {
  const AkEmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AkSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: t.textMuted),
            const SizedBox(height: AkSpace.s2),
            Text(message, textAlign: TextAlign.center, style: AkText.body.copyWith(color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Affichage uniforme d'une valeur asynchrone : chargement, erreur avec relance, contenu.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(akPageMargin(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AkBanner(
              kind: AkBannerKind.danger,
              action: onRetry == null ? null : TextButton(onPressed: onRetry, child: const Text('Réessayer')),
              child: Text('Erreur : $e'),
            ),
          ),
        ),
      ),
      data: builder,
    );
  }
}
