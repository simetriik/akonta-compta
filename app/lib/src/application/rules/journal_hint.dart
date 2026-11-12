import '../../domain/reference_models.dart';

/// Contrôle de cohérence entre le journal choisi et les comptes de trésorerie saisis (AN-09).
class JournalHint {
  const JournalHint._();

  /// Message d'avertissement quand une ligne porte le compte de trésorerie d'un journal de banque ou de caisse
  /// alors que le journal choisi n'est pas celui-là ; `null` si tout est cohérent.
  static String? treasuryMismatch({required List<Journal> journals, required String? journalId, required Iterable<String?> lineAccountIds}) {
    final accountIds = lineAccountIds.whereType<String>().toSet();
    if (accountIds.isEmpty) return null;
    final treasury = journals.where((j) => j.isActive && j.isTreasury && j.treasuryAccountId != null && accountIds.contains(j.treasuryAccountId)).toList();
    if (treasury.isEmpty || treasury.any((j) => j.id == journalId)) return null;
    final target = treasury.first;
    return 'Cette écriture touche le compte ${target.treasuryAccountCode ?? ''} : utilisez le journal ${target.code} '
        'pour qu\'elle apparaisse au rapprochement bancaire et dans la numérotation de ${target.code}.';
  }
}
