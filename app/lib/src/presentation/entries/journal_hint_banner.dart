import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../application/rules/journal_hint.dart';
import '../../domain/entry_models.dart';
import '../../domain/reference_models.dart';

/// Avertissement quand une écriture touche un compte de trésorerie hors du journal de banque ou de caisse (AN-09).
class JournalHintBanner extends StatelessWidget {
  const JournalHintBanner({super.key, required this.journals, required this.journalId, required this.lines});

  final List<Journal> journals;
  final String? journalId;
  final List<DraftLine> lines;

  @override
  Widget build(BuildContext context) {
    final hint = JournalHint.treasuryMismatch(journals: journals, journalId: journalId, lineAccountIds: lines.map((l) => l.accountId));
    if (hint == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s3),
      child: AkBanner(kind: AkBannerKind.warning, child: Text(hint)),
    );
  }
}
