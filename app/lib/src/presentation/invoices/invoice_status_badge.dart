import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';

import '../../domain/invoice_models.dart';

/// Statut d'une facture normalisée, avec la mention TEST pour l'environnement d'essai de la DGI.
class InvoiceStatusBadge extends StatelessWidget {
  const InvoiceStatusBadge(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (label, color, tint, icon) = switch (status) {
      InvoiceStatus.draft => ('Brouillon', t.statusDraft, t.statusDraftTint, Icons.edit_outlined),
      InvoiceStatus.pending => ('En cours', t.statusReview, t.statusReviewTint, Icons.hourglass_top_outlined),
      InvoiceStatus.confirmed => ('Normalisée', t.statusValid, t.statusValidTint, Icons.verified_outlined),
      InvoiceStatus.cancelled => ('Annulée', t.statusFix, t.statusFixTint, Icons.cancel_outlined),
    };
    return AkBadge(label: label, color: color, tint: tint, icon: icon);
  }
}

class TestBadge extends StatelessWidget {
  const TestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkBadge(label: 'TEST', color: t.statusFix, tint: t.statusFixTint, outlined: true);
  }
}
