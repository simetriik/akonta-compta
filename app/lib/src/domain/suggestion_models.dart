/// Suggestions de saisie sans modèle (palier 0) : écritures proches, comptes habituels, modèles proches, doublons.
library;

/// Ligne d'une écriture proposée : compte, tiers et sens, sans montant.
class SuggestedLine {
  const SuggestedLine({
    required this.accountId,
    required this.accountCode,
    required this.accountLabel,
    this.thirdPartyId,
    this.thirdPartyCode,
    required this.side,
    this.label,
  });

  final String accountId;
  final String accountCode;
  final String accountLabel;
  final String? thirdPartyId;
  final String? thirdPartyCode;

  /// `debit` ou `credit`.
  final String side;
  final String? label;
}

/// Écriture passée proche du libellé saisi.
class EntrySuggestion {
  const EntrySuggestion({
    required this.entryId,
    required this.entryDate,
    required this.journalCode,
    required this.label,
    this.reference,
    required this.similarity,
    required this.lines,
  });

  final String entryId;
  final DateTime entryDate;
  final String journalCode;
  final String label;
  final String? reference;
  final double similarity;
  final List<SuggestedLine> lines;
}

/// Compte déjà employé pour ce tiers (`third_party`) ou pour un libellé proche (`label`).
class AccountSuggestion {
  const AccountSuggestion({
    required this.accountId,
    required this.accountCode,
    required this.accountLabel,
    required this.source,
    required this.uses,
    this.lastUsed,
  });

  final String accountId;
  final String accountCode;
  final String accountLabel;
  final String source;
  final int uses;
  final DateTime? lastUsed;

  bool get fromThirdParty => source == 'third_party';
}

/// Modèle d'écriture proche du libellé saisi.
class TemplateSuggestion {
  const TemplateSuggestion({required this.templateId, required this.code, required this.label});

  final String templateId;
  final String code;
  final String label;
}

/// Écriture existante qui ressemble à un doublon (même référence de pièce, même montant, même tiers).
class DuplicateEntry {
  const DuplicateEntry({required this.entryId, this.number, required this.journalCode, required this.entryDate, required this.status, required this.label});

  final String entryId;
  final int? number;
  final String journalCode;
  final DateTime entryDate;
  final String status;
  final String label;

  String get numberLabel => number == null ? 'brouillon $journalCode' : '$journalCode-$number';
}
