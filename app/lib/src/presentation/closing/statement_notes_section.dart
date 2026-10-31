import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/closing_models.dart';

/// Notes annexes calculables du SYCEBNL : choix de la note puis tableau « année N, année N-1, variation ».
/// Le commentaire de chaque note (date des délibérations, justification des variations…) reste à rédiger hors de l'application.
class StatementNotesSection extends StatefulWidget {
  const StatementNotesSection({super.key, required this.notes});

  final List<NoteLine> notes;

  @override
  State<StatementNotesSection> createState() => _StatementNotesSectionState();
}

class _StatementNotesSectionState extends State<StatementNotesSection> {
  String? _code;

  /// Codes de notes dans l'ordre du catalogue, avec leur titre.
  List<(String, String)> get _catalog {
    final seen = <String>{};
    return [
      for (final n in widget.notes)
        if (seen.add(n.noteCode)) (n.noteCode, n.noteTitle),
    ];
  }

  static String _percent(double? p) => p == null ? '' : '${p.toStringAsFixed(1).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    if (catalog.isEmpty) return const SizedBox.shrink();
    final code = _code ?? catalog.first.$1;
    final lines = widget.notes.where((n) => n.noteCode == code).toList();
    final hasPrevious = lines.any((n) => n.previous != null);
    final t = context.ak;
    return Column(
      key: const Key('notes-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AkSectionTitle('Notes annexes'),
        const SizedBox(height: AkSpace.s2),
        AkDropdown<String>(
          key: const Key('notes-select'),
          label: 'Note',
          value: code,
          items: [for (final (c, title) in catalog) AkOption(c, 'Note $c : $title')],
          onChanged: (v) => setState(() => _code = v),
        ),
        const SizedBox(height: AkSpace.s3),
        AkTable<NoteLine>(
          minWidth: 560,
          rows: lines,
          columns: [
            AkColumn(
              label: 'Libellé',
              cell: (_, n) => Text(n.label, style: (n.isTotal ? AkText.bodyStrong : AkText.table).copyWith(color: t.text)),
            ),
            AkColumn(label: 'Année N', width: 130, numeric: true, cell: (_, n) => AkAmountText(Fmt.fcfa(n.amount, showZero: n.isTotal), bold: n.isTotal)),
            if (hasPrevious) ...[
              AkColumn(label: 'Année N-1', width: 130, numeric: true, cell: (_, n) => AkAmountText(n.previous == null ? '' : Fmt.fcfa(n.previous!, showZero: n.isTotal), color: t.textMuted)),
              AkColumn(label: 'Variation', width: 130, numeric: true, cell: (_, n) => AkAmountText(n.variation == null ? '' : Fmt.fcfa(n.variation!, showZero: false), color: t.textMuted)),
              AkColumn(label: '%', width: 90, numeric: true, cell: (_, n) => AkAmountText(_percent(n.variationPercent), color: t.textMuted)),
            ],
          ],
        ),
        const SizedBox(height: AkSpace.s2),
        Text(
          'Le commentaire de la note (justification des variations, dates de délibération) est à rédiger dans le dossier de l\'exercice. '
          'Les colonnes d\'échéances et les notes à saisie libre ne sont pas produites.',
          key: const Key('notes-caption'),
          style: AkText.caption.copyWith(color: t.textMuted),
        ),
      ],
    );
  }
}
