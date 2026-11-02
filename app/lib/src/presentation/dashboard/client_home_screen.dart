import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../core/errors/errors.dart';
import '../../domain/models.dart';

/// Accueil d'un client du cabinet (D-044) : son brouillard, ses retours « à corriger », ses factures et ses pièces.
/// Rien sur la comptabilité validée : la base ne la lui montre pas, l'écran ne la mentionne pas non plus.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(entityDashboardProvider);
    final pad = akPageMargin(context);
    return data.when(
      loading: () => const AkLoading(),
      error: (e, _) => AkErrorMessage(errorText(e, action: 'Chargement impossible'), onRetry: () => ref.invalidate(entityDashboardProvider)),
      data: (entities) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(entityDashboardProvider),
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: entities.isEmpty
              ? const [AkBanner(kind: AkBannerKind.info, child: Text('Aucun dossier ouvert pour le moment. Votre cabinet doit activer votre accès.'))]
              : [
                  for (final e in entities) ...[_EntityHome(entity: e), const SizedBox(height: AkSpace.s6)],
                ],
        ),
      ),
    );
  }
}

class _EntityHome extends ConsumerWidget {
  const _EntityHome({required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider(entity.id)).value;
    final suspended = entity.clientAccess == 'suspended';
    final stats = [
      ('Brouillards', '${entity.draftCount}', false, Icons.edit_outlined, '/saisie'),
      ('À corriger', '${entity.toCorrectCount}', entity.toCorrectCount > 0, Icons.error_outline, '/saisie'),
      ('Factures', invoices == null ? '–' : '${invoices.length}', false, Icons.receipt_outlined, '/factures'),
      ('Pièces', '', false, Icons.receipt_long_outlined, '/pieces'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AkPageHead(title: entity.name, subtitle: 'Espace client'),
        if (suspended) ...[
          const SizedBox(height: AkSpace.s3),
          const AkBanner(
            kind: AkBannerKind.warning,
            child: Text('Votre accès est suspendu par le cabinet : vous pouvez consulter vos données, mais plus saisir ni émettre.'),
          ),
        ],
        if (entity.toCorrectCount > 0) ...[
          const SizedBox(height: AkSpace.s3),
          AkBanner(
            kind: AkBannerKind.warning,
            child: Text(
              '${entity.toCorrectCount} brouillard${entity.toCorrectCount > 1 ? 's' : ''} renvoyé${entity.toCorrectCount > 1 ? 's' : ''} par le cabinet : ouvrez-le pour lire le motif.',
            ),
          ),
        ],
        const SizedBox(height: AkSpace.s4),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 720 ? 4 : 2;
            const gap = AkSpace.s3;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (label, value, problem, icon, route) in stats)
                  SizedBox(
                    width: w,
                    child: AkStat(label: label, value: value.isEmpty ? 'Déposer' : value, icon: icon, problem: problem, onTap: () => context.go(route)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
