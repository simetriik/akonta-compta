import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/entities_repository.dart';
import '../widgets/async_view.dart';

/// Liste des dossiers (entités) du cabinet accessibles à l'utilisateur ; création via l'assistant.
class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(entitiesListProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-entity'),
        onPressed: () => context.go('/dossiers/nouveau'),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Nouveau dossier'),
      ),
      body: AsyncView(
        value: list,
        onRetry: () => ref.invalidate(entitiesListProvider),
        builder: (entities) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Dossiers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final e in entities)
                    ListTile(
                      leading: Icon(e.isActive ? Icons.folder_outlined : Icons.folder_off_outlined),
                      title: Text(e.name),
                      subtitle: Text([if (e.legalForm != null) e.legalForm!, if (e.taxId != null) 'IFU ${e.taxId}', '${e.accountLength} chiffres'].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/dossiers/${e.id}'),
                    ),
                  if (entities.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucun dossier. Créez le premier avec l\'assistant d\'ouverture.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
