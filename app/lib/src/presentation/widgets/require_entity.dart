import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../data/supabase_providers.dart';
import '../../domain/models.dart';

/// Les modules de tenue exigent un dossier courant : invite à le choisir sinon.
class RequireEntity extends ConsumerWidget {
  const RequireEntity({super.key, required this.builder});

  final Widget Function(EntitySummary entity) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(currentEntityProvider);
    if (entity == null) {
      final t = context.ak;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AkSpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AkCard(
              padding: const EdgeInsets.all(AkSpace.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 32, color: t.brand),
                  const SizedBox(height: AkSpace.s3),
                  Text('Choisissez un dossier dans la barre supérieure pour continuer.', textAlign: TextAlign.center, style: AkText.body.copyWith(color: t.text)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return builder(entity);
  }
}
