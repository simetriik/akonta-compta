import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../domain/models.dart';
import '../../application/providers/session_providers.dart';

/// Les modules de tenue exigent un dossier courant : invite à le choisir sinon.
class RequireEntity extends ConsumerWidget {
  const RequireEntity({super.key, required this.builder});

  final Widget Function(EntitySummary entity) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(currentEntityProvider);
    if (entity == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AkSpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const AkEmptyState('Choisissez un dossier dans la barre supérieure pour continuer.', icon: Icons.folder_open),
          ),
        ),
      );
    }
    return builder(entity);
  }
}
