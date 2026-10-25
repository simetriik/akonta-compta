import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Statut coloré d'une écriture : brouillard, validée, revue, à corriger (conception §12.3).
enum EntryStatusKind { draft, validated, reviewed, toCorrect }

class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key});

  final EntryStatusKind kind;

  static EntryStatusKind of({required String status, required String reviewStatus}) {
    if (status == 'draft') return EntryStatusKind.draft;
    return switch (reviewStatus) {
      'reviewed' => EntryStatusKind.reviewed,
      'to_correct' => EntryStatusKind.toCorrect,
      _ => EntryStatusKind.validated,
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      EntryStatusKind.draft => ('Brouillard', AkColors.draft),
      EntryStatusKind.validated => ('Validée', AkColors.validated),
      EntryStatusKind.reviewed => ('Revue', AkColors.reviewed),
      EntryStatusKind.toCorrect => ('À corriger', AkColors.toCorrect),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
