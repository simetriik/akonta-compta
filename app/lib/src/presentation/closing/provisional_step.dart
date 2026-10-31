import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';

class ProvisionalStep extends ConsumerWidget {
  const ProvisionalStep({super.key, required this.entity, required this.fy, required this.onChanged});

  final EntitySummary entity;
  final FiscalYear fy;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(closingServiceProvider);
    final t = context.ak;
    return ListView(
      padding: closingBodyPadding(context),
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkSectionTitle('Exercice ${fy.label} · ${fy.statusLabel}'),
              const SizedBox(height: AkSpace.s2),
              Text(
                '1. Générer et valider l\'écriture de détermination du résultat (soldes des classes 6, 7, 8 vers 131 / 139).\n2. Clôture provisoire : tous les contrôles bloquants conformes, alertes levées avec commentaire ; les périodes sont verrouillées.\n3. Réouverture possible avec motif tant que l\'arrêté définitif n\'est pas prononcé.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              Wrap(
                spacing: AkSpace.s3,
                runSpacing: AkSpace.s2,
                children: [
                  AkButton.secondary(
                    'Écriture de résultat',
                    icon: Icons.functions,
                    onPressed: () => runGeneration(context, ref, () => repo.generateResultEntry(entity.id, fy.id), 'Détermination du résultat'),
                  ),
                  AkButton.primary(
                    'Clôture provisoire',
                    icon: Icons.lock_outline,
                    onPressed: fy.status != 'open'
                        ? null
                        : () async {
                            try {
                              await repo.closeProvisional(entity.id, fy.id);
                              onChanged();
                              if (context.mounted) showAkToast(context, 'Clôture provisoire prononcée.');
                            } catch (e) {
                              if (context.mounted) showErrorSnack(context, errorText(e));
                            }
                          },
                  ),
                  AkButton.secondary(
                    'Réouvrir (motif)',
                    icon: Icons.lock_open,
                    onPressed: fy.status != 'closing'
                        ? null
                        : () async {
                            final reason = await askText(context, title: 'Réouvrir l\'exercice', label: 'Motif (obligatoire)', confirmLabel: 'Réouvrir');
                            if (reason == null || reason.trim().isEmpty) return;
                            try {
                              await repo.reopen(entity.id, fy.id, reason.trim());
                              onChanged();
                            } catch (e) {
                              if (context.mounted) showErrorSnack(context, errorText(e));
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
