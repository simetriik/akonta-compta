import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entry_models.dart';

/// Identifiant d'un brouillard enregistré seulement sur l'appareil : `local:<numéro de la file d'envoi>`.
const String localDraftPrefix = 'local:';

bool isLocalDraftId(String? id) => id != null && id.startsWith(localDraftPrefix);

int localDraftOutboxId(String id) => int.parse(id.substring(localDraftPrefix.length));

String localDraftId(int outboxId) => '$localDraftPrefix$outboxId';

/// Données d'un brouillard en attente d'envoi.
Map<String, dynamic> encodeEntryDraft({required String cabinetId, required String entityId, required EntryDraft draft}) => {
  'cabinet_id': cabinetId,
  'entity_id': entityId,
  'remote_id': isLocalDraftId(draft.id) ? null : draft.id,
  'journal_id': draft.journalId,
  'entry_date': draft.entryDate.toIso8601String(),
  'reference': draft.reference,
  'label': draft.label,
  'lines': [
    for (final l in draft.lines)
      {
        'account_id': l.accountId,
        'account_code': l.accountCode,
        'account_label': l.accountLabel,
        'is_collective': l.isCollective,
        'third_party_id': l.thirdPartyId,
        'third_party_code': l.thirdPartyCode,
        'label': l.label,
        'debit': l.debit,
        'credit': l.credit,
      },
  ],
};

EntryDraft decodeEntryDraft(Map<String, dynamic> p, {String? id}) => EntryDraft(
  id: id ?? p['remote_id'] as String?,
  journalId: p['journal_id'] as String?,
  date: DateTime.parse(p['entry_date'] as String),
  reference: (p['reference'] as String?) ?? '',
  label: (p['label'] as String?) ?? '',
  lines: [
    for (final l in (p['lines'] as List))
      DraftLine(
        accountId: (l as Map)['account_id'] as String?,
        accountCode: (l['account_code'] as String?) ?? '',
        accountLabel: (l['account_label'] as String?) ?? '',
        isCollective: (l['is_collective'] as bool?) ?? false,
        thirdPartyId: l['third_party_id'] as String?,
        thirdPartyCode: (l['third_party_code'] as String?) ?? '',
        label: (l['label'] as String?) ?? '',
        debit: (l['debit'] as num?)?.toInt() ?? 0,
        credit: (l['credit'] as num?)?.toInt() ?? 0,
      ),
  ],
);

/// Brouillard local présenté comme une écriture du journal (liste de saisie, éditeur) ; numéro absent, journal inconnu hors ligne.
EntryModel localDraftAsEntry(int outboxId, Map<String, dynamic> p) {
  final draft = decodeEntryDraft(p, id: localDraftId(outboxId));
  final lines = [
    for (var i = 0; i < draft.lines.length; i++)
      EntryLineModel(
        id: '${localDraftId(outboxId)}:$i',
        lineNo: i + 1,
        accountId: draft.lines[i].accountId ?? '',
        accountCode: draft.lines[i].accountCode,
        accountLabel: draft.lines[i].accountLabel,
        isCollective: draft.lines[i].isCollective,
        thirdPartyId: draft.lines[i].thirdPartyId,
        thirdPartyCode: draft.lines[i].thirdPartyCode,
        label: draft.lines[i].label,
        debit: draft.lines[i].debit,
        credit: draft.lines[i].credit,
      ),
  ];
  return EntryModel(
    id: localDraftId(outboxId),
    entityId: p['entity_id'] as String,
    journalId: draft.journalId ?? '',
    journalCode: '—',
    entryDate: draft.entryDate,
    reference: draft.reference.isEmpty ? null : draft.reference,
    label: draft.label,
    status: 'draft',
    reviewStatus: 'not_reviewed',
    isGenerated: false,
    totalDebit: lines.fold(0, (s, l) => s + l.debit),
    totalCredit: lines.fold(0, (s, l) => s + l.credit),
    lines: lines,
  );
}

/// Données d'une pièce en attente d'envoi (le fichier est conservé en base64).
Map<String, dynamic> encodeDocumentUpload({
  required String cabinetId,
  required String entityId,
  required String fileName,
  required Uint8List bytes,
  required String capturedVia,
  String? note,
}) => {'cabinet_id': cabinetId, 'entity_id': entityId, 'file_name': fileName, 'bytes': base64Encode(bytes), 'captured_via': capturedVia, 'note': note};
