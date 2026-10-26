import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'ak_widgets.dart';

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
    final t = context.ak;
    final (label, color, tint, icon) = switch (kind) {
      EntryStatusKind.draft => ('Brouillard', t.statusDraft, t.statusDraftTint, Icons.edit_outlined),
      EntryStatusKind.validated => ('Validée', t.statusValid, t.statusValidTint, Icons.check_circle_outline),
      EntryStatusKind.reviewed => ('Revue', t.statusReview, t.statusReviewTint, Icons.fact_check_outlined),
      EntryStatusKind.toCorrect => ('À corriger', t.statusFix, t.statusFixTint, Icons.error_outline),
    };
    return AkBadge(label: label, color: color, tint: tint, icon: icon);
  }
}
