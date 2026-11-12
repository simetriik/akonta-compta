import 'package:flutter/material.dart';

import '../../domain/entry_models.dart';
import '../../domain/reference_models.dart';
import 'entry_currency_panel.dart';
import 'journal_hint_banner.dart';

/// Compléments du bandeau de l'écriture : avertissement de journal (AN-09) et pièce en devise (AN-25).
class EntryHeaderExtras extends StatelessWidget {
  const EntryHeaderExtras({super.key, required this.draft, required this.journals, required this.readOnly, required this.onChanged});

  final EntryDraft draft;
  final List<Journal> journals;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // Le compte de trésorerie du journal choisi sert à la contrepartie automatique (AN-10).
    final journal = journals.where((j) => j.id == draft.journalId && j.isTreasury && j.treasuryAccountId != null).firstOrNull;
    draft.treasuryAccount = journal == null ? null : (id: journal.treasuryAccountId!, code: journal.treasuryAccountCode ?? '');
    return _content();
  }

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      JournalHintBanner(journals: journals, journalId: draft.journalId, lines: draft.lines),
      EntryCurrencyPanel(draft: draft, readOnly: readOnly, onChanged: onChanged),
    ],
  );
}
