import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../widgets/async_view.dart';
import '../../application/providers/consultation_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../domain/consultation_models.dart';
import 'consultation_widgets.dart';

class CentralizationTab extends ConsumerWidget {
  const CentralizationTab({super.key, required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (params.fiscalYearId == null) {
      return Padding(
        padding: const EdgeInsets.all(AkSpace.s4),
        child: Align(
          alignment: Alignment.topLeft,
          child: AkBanner(kind: AkBannerKind.warning, child: const Text('Aucun exercice ne contient la date de début.')),
        ),
      );
    }
    final rows = ref.watch(centralizationProvider(params));
    final journals = ref.watch(journalsProvider(params.entityId)).value ?? const [];
    return AsyncView(
      value: rows,
      onRetry: () => ref.invalidate(centralizationProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucune écriture validée sur cet exercice.');
        final byJournal = <String, List<CentralizationRow>>{};
        for (final r in list) {
          byJournal.putIfAbsent(r.journalCode, () => []).add(r);
        }
        final grid = <AkGridRow>[];
        for (final e in byJournal.entries) {
          final label = journals.where((j) => j.code == e.key).firstOrNull?.label ?? e.value.first.journalLabel;
          grid.add(
            AkGridRow.section(
              Row(
                children: [
                  consultationCode(context, e.key, bold: true),
                  const SizedBox(width: AkSpace.s2),
                  Flexible(child: consultationSection(context, '— $label')),
                ],
              ),
            ),
          );
          for (final r in e.value) {
            grid.add(
              AkGridRow([
                consultationText(context, Fmt.month(r.monthStart)),
                consultationText(context, '${r.entriesCount} écr.', muted: true),
                consultationAmount(Fmt.fcfa(r.totalDebit, showZero: true)),
                consultationAmount(Fmt.fcfa(r.totalCredit, showZero: true)),
              ]),
            );
          }
          grid.add(
            AkGridRow([
              consultationText(context, 'Total journal', bold: true),
              const SizedBox.shrink(),
              consultationAmount(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalDebit), showZero: true), bold: true),
              consultationAmount(Fmt.fcfa(e.value.fold<int>(0, (s, r) => s + r.totalCredit), showZero: true), bold: true),
            ], kind: AkGridRowKind.total),
          );
        }
        return AkGrid(
          columns: const [
            AkGridColumn('Mois', 200, grow: true),
            AkGridColumn('Écritures', 100),
            AkGridColumn('Débit', 140, numeric: true),
            AkGridColumn('Crédit', 140, numeric: true),
          ],
          rows: grid,
        );
      },
    );
  }
}
