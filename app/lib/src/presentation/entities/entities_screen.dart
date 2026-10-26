import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/entities_repository.dart';
import '../widgets/ak_widgets.dart';
import '../widgets/async_view.dart';

/// Liste des dossiers (entités) du cabinet accessibles à l'utilisateur ; création via l'assistant.
class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(entitiesListProvider);
    final t = context.ak;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return AsyncView(
      value: list,
      onRetry: () => ref.invalidate(entitiesListProvider),
      builder: (entities) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          AkPageHead(
            title: 'Dossiers',
            subtitle: '${entities.length} dossier${entities.length > 1 ? 's' : ''}',
            actions: [
              FilledButton.icon(
                key: const Key('new-entity'),
                onPressed: () => context.go('/dossiers/nouveau'),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Nouveau dossier'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
              children: [
                for (var i = 0; i < entities.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(entities[i].isActive ? Icons.folder_outlined : Icons.folder_off_outlined, color: t.textMuted),
                    title: Text(entities[i].name, style: AkText.bodyStrong.copyWith(color: t.text)),
                    subtitle: Text(
                      [if (entities[i].legalForm != null) entities[i].legalForm!, if (entities[i].taxId != null) 'IFU ${entities[i].taxId}', '${entities[i].accountLength} chiffres'].join(' · '),
                      style: AkText.caption.copyWith(color: t.textMuted),
                    ),
                    trailing: Icon(Icons.chevron_right, color: t.textMuted),
                    onTap: () => context.go('/dossiers/${entities[i].id}'),
                  ),
                ],
                if (entities.isEmpty) const Padding(padding: EdgeInsets.all(AkSpace.s4), child: Text('Aucun dossier. Créez le premier avec l\'assistant d\'ouverture.')),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
