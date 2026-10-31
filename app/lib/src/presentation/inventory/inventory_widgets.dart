import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../application/providers/session_providers.dart';

/// Marge latérale de page : 24 px sur desktop, 16 px sur mobile (< 600 px).
EdgeInsets akPagePadding(BuildContext context) => EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? AkSpace.s4 : AkSpace.s6);

/// Message d'erreur sous forme de toast.
void showErrorSnack(BuildContext context, String message) {
  showAkToast(context, message, kind: AkToastKind.danger);
}

/// Liste de lignes séparées par des filets, dans une carte sans marge interne.
Widget akRowsCard(BuildContext context, List<Widget> rows) {
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

/// Message de liste vide, dans une carte.
Widget akEmptyRow(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.all(AkSpace.s4),
  child: Text(text, style: AkText.body.copyWith(color: context.ak.textMuted)),
);

Future<void> runGeneration(BuildContext context, WidgetRef ref, Future<String?> Function() action, String successLabel) async {
  try {
    final id = await action();
    ref.invalidate(entityDashboardProvider);
    if (!context.mounted) return;
    // Avec un bouton d'action, un message reste affiché tant que la navigation accessible est active :
    // on le borne dans le temps et on permet de le fermer.
    showAkToast(
      context,
      id == null ? 'Rien à générer.' : '$successLabel : brouillard créé.',
      kind: id == null ? AkToastKind.info : AkToastKind.success,
      actionLabel: id == null ? null : 'Ouvrir',
      onAction: id == null ? null : () => context.go('/saisie/$id'),
    );
  } catch (e) {
    if (context.mounted) showErrorSnack(context, errorText(e));
  }
}
