import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../domain/entity_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/session_providers.dart';
import '../dashboard/dashboard_screen.dart' show FiscalYearBadge;

/// Liste des dossiers (entités) du cabinet accessibles à l'utilisateur ; création via l'assistant.
class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(entitiesListProvider);
    // Exercice en cours de chaque dossier ; absent tant que le tableau de bord n'est pas chargé.
    final summaries = {for (final s in ref.watch(entityDashboardProvider).value ?? const []) s.id: s};
    final t = context.ak;
    final pad = akPageMargin(context);
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
              AkButton.primary(
                'Nouveau dossier',
                key: const Key('new-entity'),
                icon: Icons.create_new_folder_outlined,
                onPressed: () => context.go('/dossiers/nouveau'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          if (entities.isEmpty)
            const AkEmptyState('Aucun dossier. Créez le premier avec l\'assistant d\'ouverture.', icon: Icons.folder_off_outlined)
          else
            AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: AkTable<EntityDetail>(
                rows: entities,
                minWidth: 720,
                rowHeight: AkSpace.rowComfort + 8,
                onRowTap: (e) => context.go('/dossiers/${e.id}'),
                columns: [
                  AkColumn<EntityDetail>(
                    label: 'Dossier',
                    flex: 3,
                    cell: (context, e) => Row(
                      children: [
                        Icon(e.isActive ? Icons.folder_outlined : Icons.folder_off_outlined, size: 20, color: t.textMuted),
                        const SizedBox(width: AkSpace.s2),
                        Expanded(
                          child: Text(
                            e.name,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.bodyStrong.copyWith(color: t.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AkColumn<EntityDetail>.text(label: 'Forme juridique', flex: 2, text: (e) => e.legalForm ?? ''),
                  AkColumn<EntityDetail>.text(label: 'IFU', flex: 2, text: (e) => e.taxId ?? ''),
                  AkColumn<EntityDetail>(
                    label: 'Exercice',
                    flex: 3,
                    cell: (context, e) {
                      final s = summaries[e.id];
                      if (s?.fiscalYearStatus == null) return Text('—', style: AkText.table.copyWith(color: t.textMuted));
                      return Wrap(
                        spacing: AkSpace.s2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (s!.fiscalYearLabel != null) Text(s.fiscalYearLabel!, style: AkText.table.copyWith(color: t.text)),
                          FiscalYearBadge(status: s.fiscalYearStatus!),
                        ],
                      );
                    },
                  ),
                  AkColumn<EntityDetail>.text(label: 'Longueur des comptes', flex: 2, text: (e) => '${e.accountLength} chiffres'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
