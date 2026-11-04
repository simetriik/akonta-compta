import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';

import '../../domain/reference_models.dart';

/// Mobile : journal et libellé en pleine largeur, date et référence côte à côte, statut en dessous.
class EntryMobileHeaderFields extends StatelessWidget {
  const EntryMobileHeaderFields({
    super.key,
    required this.journals,
    required this.journalId,
    required this.onJournal,
    required this.date,
    required this.reference,
    required this.label,
    required this.readOnly,
    required this.status,
  });

  final List<Journal> journals;
  final String? journalId;
  final ValueChanged<String?> onJournal;
  final TextEditingController date;
  final TextEditingController reference;
  final TextEditingController label;
  final bool readOnly;
  final AkEntryStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkDropdown<String>(
          key: const Key('entry-journal'),
          label: 'Journal',
          value: journalId,
          items: [for (final j in journals) AkOption(j.id, '${j.code} · ${j.label}')],
          onChanged: readOnly ? null : onJournal,
        ),
        const SizedBox(height: AkSpace.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AkDateField(key: const Key('entry-date'), controller: date, label: 'Date', enabled: !readOnly),
            ),
            const SizedBox(width: AkSpace.s3),
            Expanded(
              child: AkTextField(controller: reference, label: 'Référence pièce', enabled: !readOnly, mono: true),
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s3),
        AkTextField(key: const Key('entry-label'), controller: label, label: 'Libellé', enabled: !readOnly),
        const SizedBox(height: AkSpace.s3),
        Align(alignment: Alignment.centerLeft, child: AkStatusBadge(status)),
      ],
    );
  }
}

/// Mobile : actions d'en-tête sur une ligne dédiée, libellés courts, sans raccourci clavier.
class EntryMobileActions extends StatelessWidget {
  const EntryMobileActions({super.key, required this.onTemplate, required this.onBalance, required this.canDelete, this.onDelete});

  final VoidCallback onTemplate;
  final VoidCallback onBalance;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s2),
      child: Wrap(
        spacing: AkSpace.s2,
        runSpacing: AkSpace.s2,
        children: [
          AkButton.secondary('Modèle', dense: true, icon: Icons.auto_fix_high_outlined, onPressed: onTemplate),
          AkButton.secondary('Contrepartie', dense: true, icon: Icons.balance, onPressed: onBalance),
          if (canDelete) AkButton.dangerOutline('Supprimer', dense: true, icon: Icons.delete_outline, onPressed: onDelete),
        ],
      ),
    );
  }
}
