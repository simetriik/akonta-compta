import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Choisissez un dossier dans la barre supérieure pour continuer.', textAlign: TextAlign.center),
        ),
      );
    }
    return builder(entity);
  }
}
