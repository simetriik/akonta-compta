
class ImportBatch {
  const ImportBatch({required this.id, required this.kind, required this.status, this.sourceFileName, this.sourceJournal, this.periodFrom, this.periodTo, this.targetJournalId, required this.report, required this.createdAt});

  final String id;
  final String kind;
  final String status;
  final String? sourceFileName;
  final String? sourceJournal;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String? targetJournalId;
  final Map<String, dynamic> report;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'created' => 'Créé',
        'parsed' => 'Analysé',
        'mapped' => 'Correspondances proposées',
        'dry_run' => 'Essai effectué',
        'applied' => 'Appliqué',
        'cancelled' => 'Annulé',
        _ => status,
      };
}

class AccountMapping {
  const AccountMapping({required this.id, required this.rawAccount, this.accountCode, this.thirdPartyCode, this.thirdPartyName, required this.createThirdParty, this.note});

  final String id;
  final String rawAccount;
  final String? accountCode;
  final String? thirdPartyCode;
  final String? thirdPartyName;
  final bool createThirdParty;
  final String? note;
}
