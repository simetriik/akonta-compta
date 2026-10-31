import '../../../domain/suggestion_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

SuggestedLine suggestedLineFromJson(Map<String, dynamic> j) => SuggestedLine(
    accountId: j['account_id'] as String,
    accountCode: j['account_code'] as String,
    accountLabel: j['account_label'] as String,
    thirdPartyId: j['third_party_id'] as String?,
    thirdPartyCode: j['third_party_code'] as String?,
    side: j['side'] as String,
    label: j['label'] as String?,
  );

EntrySuggestion entrySuggestionFromJson(Map<String, dynamic> j) => EntrySuggestion(
    entryId: j['entry_id'] as String,
    entryDate: DateTime.parse(j['entry_date'] as String),
    journalCode: j['journal_code'] as String,
    label: j['label'] as String,
    reference: j['reference'] as String?,
    similarity: (j['similarity'] as num).toDouble(),
    lines: [for (final l in (j['lines'] as List? ?? const [])) suggestedLineFromJson(Map<String, dynamic>.from(l as Map))],
  );

AccountSuggestion accountSuggestionFromJson(Map<String, dynamic> j) => AccountSuggestion(
    accountId: j['account_id'] as String,
    accountCode: j['account_code'] as String,
    accountLabel: j['account_label'] as String,
    source: j['source'] as String,
    uses: (j['uses'] as num).toInt(),
    lastUsed: j['last_used'] == null ? null : DateTime.parse(j['last_used'] as String),
  );

TemplateSuggestion templateSuggestionFromJson(Map<String, dynamic> j) =>
      TemplateSuggestion(templateId: j['template_id'] as String, code: j['code'] as String, label: j['label'] as String);

DuplicateEntry duplicateEntryFromJson(Map<String, dynamic> j) => DuplicateEntry(
    entryId: j['entry_id'] as String,
    number: (j['number'] as num?)?.toInt(),
    journalCode: j['journal_code'] as String,
    entryDate: DateTime.parse(j['entry_date'] as String),
    status: j['status'] as String,
    label: j['label'] as String,
  );
