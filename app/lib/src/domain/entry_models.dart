/// Modèles du module 4 : écritures, lignes, brouillon de saisie, application des modèles.
library;

import 'reference_models.dart';

class EntryLineModel {
  const EntryLineModel({
    required this.id,
    required this.lineNo,
    required this.accountId,
    required this.accountCode,
    required this.accountLabel,
    this.thirdPartyId,
    this.thirdPartyCode,
    this.label,
    required this.debit,
    required this.credit,
    this.currencyCode = 'XOF',
    this.amountCurrency,
    this.exchangeRate,
    this.letterCode,
  });

  final String id;
  final int lineNo;
  final String accountId;
  final String accountCode;
  final String accountLabel;
  final String? thirdPartyId;
  final String? thirdPartyCode;
  final String? label;
  final int debit;
  final int credit;
  final String currencyCode;
  final double? amountCurrency;
  final double? exchangeRate;
  final String? letterCode;

  factory EntryLineModel.fromJson(Map<String, dynamic> j) => EntryLineModel(
        id: j['id'] as String,
        lineNo: (j['line_no'] as num).toInt(),
        accountId: j['account_id'] as String,
        accountCode: (j['accounts'] as Map)['code'] as String,
        accountLabel: (j['accounts'] as Map)['label'] as String,
        thirdPartyId: j['third_party_id'] as String?,
        thirdPartyCode: (j['third_parties'] as Map?)?['code'] as String?,
        label: j['label'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
        currencyCode: (j['currency_code'] as String?) ?? 'XOF',
        amountCurrency: j['amount_currency'] == null ? null : double.parse('${j['amount_currency']}'),
        exchangeRate: j['exchange_rate'] == null ? null : double.parse('${j['exchange_rate']}'),
        letterCode: j['letter_code'] as String?,
      );
}

class EntryModel {
  const EntryModel({
    required this.id,
    required this.entityId,
    required this.journalId,
    required this.journalCode,
    required this.entryDate,
    this.number,
    this.reference,
    required this.label,
    required this.status,
    required this.reviewStatus,
    this.reviewComment,
    required this.isGenerated,
    this.reversalOf,
    this.reversedBy,
    this.createdBy,
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.lines = const [],
  });

  final String id;
  final String entityId;
  final String journalId;
  final String journalCode;
  final DateTime entryDate;
  final int? number;
  final String? reference;
  final String label;
  final String status;
  final String reviewStatus;
  final String? reviewComment;
  final bool isGenerated;
  final String? reversalOf;
  final String? reversedBy;
  final String? createdBy;
  final int totalDebit;
  final int totalCredit;
  final List<EntryLineModel> lines;

  factory EntryModel.fromJson(Map<String, dynamic> j) {
    final lines = [for (final l in (j['entry_lines'] as List? ?? const [])) EntryLineModel.fromJson(l as Map<String, dynamic>)]..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    return EntryModel(
      id: j['id'] as String,
      entityId: j['entity_id'] as String,
      journalId: j['journal_id'] as String,
      journalCode: (j['journals'] as Map?)?['code'] as String? ?? '',
      entryDate: DateTime.parse(j['entry_date'] as String),
      number: (j['number'] as num?)?.toInt(),
      reference: j['reference'] as String?,
      label: j['label'] as String,
      status: j['status'] as String,
      reviewStatus: j['review_status'] as String,
      reviewComment: j['review_comment'] as String?,
      isGenerated: (j['is_generated'] as bool?) ?? false,
      reversalOf: j['reversal_of'] as String?,
      reversedBy: j['reversed_by'] as String?,
      createdBy: j['created_by'] as String?,
      totalDebit: lines.fold(0, (s, l) => s + l.debit),
      totalCredit: lines.fold(0, (s, l) => s + l.credit),
      lines: lines,
    );
  }

  bool get isDraft => status == 'draft';
  String get numberLabel => number == null ? 'brouillon' : '$journalCode-$number';
}

/// Ligne en cours de saisie (grille ou formulaire).
class DraftLine {
  DraftLine({this.accountId, this.accountCode = '', this.accountLabel = '', this.isCollective = false, this.thirdPartyId, this.thirdPartyCode = '', this.label = '', this.debit = 0, this.credit = 0});

  String? accountId;
  String accountCode;
  String accountLabel;
  bool isCollective;
  String? thirdPartyId;
  String thirdPartyCode;
  String label;
  int debit;
  int credit;

  bool get isEmpty => accountId == null && debit == 0 && credit == 0 && label.isEmpty;

  /// Contrôles de la conception §10.4, appliqués avant l'envoi (la base les impose aussi).
  String? validate() {
    if (accountId == null) return 'Compte requis';
    if (debit < 0 || credit < 0) return 'Montant négatif interdit';
    if (debit > 0 && credit > 0) return 'Débit ou crédit, pas les deux';
    if (debit == 0 && credit == 0) return 'Montant strictement positif requis';
    if (isCollective && thirdPartyId == null) return 'Tiers requis sur un compte collectif';
    return null;
  }

  Map<String, dynamic> toJson(int lineNo) => {
        'line_no': lineNo,
        'account_id': accountId,
        'third_party_id': thirdPartyId,
        'label': label.trim().isEmpty ? null : label.trim(),
        'debit': debit,
        'credit': credit,
      };
}

class EntryDraft {
  EntryDraft({this.id, this.journalId, DateTime? date, this.reference = '', this.label = '', List<DraftLine>? lines})
      : entryDate = date ?? DateTime.now(),
        lines = lines ?? [DraftLine(), DraftLine()];

  String? id;
  String? journalId;
  DateTime entryDate;
  String reference;
  String label;
  final List<DraftLine> lines;

  int get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  int get totalCredit => lines.fold(0, (s, l) => s + l.credit);
  int get balance => totalDebit - totalCredit;
  bool get isBalanced => balance == 0 && nonEmptyLines.length >= 2;
  List<DraftLine> get nonEmptyLines => lines.where((l) => !l.isEmpty).toList();

  /// Contrepartie automatique : place le solde sur la première ligne vide (ou une nouvelle).
  void autoBalance() {
    if (balance == 0) return;
    final target = lines.firstWhere((l) => l.debit == 0 && l.credit == 0, orElse: () {
      final l = DraftLine();
      lines.add(l);
      return l;
    });
    if (balance > 0) {
      target.credit = balance;
      target.debit = 0;
    } else {
      target.debit = -balance;
      target.credit = 0;
    }
  }

  /// Erreurs bloquantes avant validation ; liste vide = prêt à valider.
  List<String> validationErrors() {
    final errors = <String>[];
    if (journalId == null) errors.add('Journal requis');
    if (label.trim().isEmpty) errors.add('Libellé requis');
    final active = nonEmptyLines;
    if (active.length < 2) errors.add('Au moins deux lignes');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].isEmpty) continue;
      final e = lines[i].validate();
      if (e != null) errors.add('Ligne ${i + 1} : $e');
    }
    if (active.isNotEmpty && totalDebit != totalCredit) errors.add('Écriture déséquilibrée : ${totalDebit - totalCredit}');
    return errors;
  }

  factory EntryDraft.fromEntry(EntryModel e) => EntryDraft(
        id: e.id,
        journalId: e.journalId,
        date: e.entryDate,
        reference: e.reference ?? '',
        label: e.label,
        lines: [
          for (final l in e.lines)
            DraftLine(accountId: l.accountId, accountCode: l.accountCode, accountLabel: l.accountLabel, thirdPartyId: l.thirdPartyId, thirdPartyCode: l.thirdPartyCode ?? '', label: l.label ?? '', debit: l.debit, credit: l.credit),
        ],
      );
}

/// Application d'un modèle d'écriture : montants calculés depuis la saisie de base, les taux et le solde.
/// `resolveAccount` fait correspondre le numéro de référence du modèle (ex. 4452) au compte de l'entité.
List<DraftLine> applyTemplate(EntryTemplate template, {required int baseAmount, required double? Function(String code) rateOf, required Account? Function(String referenceCode) resolveAccount}) {
  final amounts = <int, int>{};
  final result = <DraftLine>[];
  // Première passe : saisie et pourcentages (dans l'ordre des lignes)
  for (final l in template.lines) {
    switch (l.formula) {
      case 'input':
        amounts[l.lineNo] = baseAmount;
      case 'percent_of':
        final base = amounts[l.refLineNo ?? 0] ?? 0;
        final rate = l.taxRateCode != null ? (rateOf(l.taxRateCode!) ?? 0) : (l.percent ?? 0);
        amounts[l.lineNo] = (base * rate).round();
      case 'balance':
        amounts[l.lineNo] = 0;
    }
  }
  // Deuxième passe : les lignes « solde » équilibrent l'écriture
  var debit = 0, credit = 0;
  for (final l in template.lines.where((l) => l.formula != 'balance')) {
    if (l.side == 'debit') {
      debit += amounts[l.lineNo]!;
    } else {
      credit += amounts[l.lineNo]!;
    }
  }
  final balanceLines = template.lines.where((l) => l.formula == 'balance').toList();
  if (balanceLines.isNotEmpty) {
    final diff = debit - credit;
    final first = balanceLines.first;
    amounts[first.lineNo] = diff.abs();
  }
  for (final l in template.lines) {
    final account = resolveAccount(l.accountCode);
    final amount = amounts[l.lineNo] ?? 0;
    final isBalance = l.formula == 'balance';
    final side = isBalance ? ((debit - credit) > 0 ? 'credit' : 'debit') : l.side;
    result.add(DraftLine(
      accountId: account?.id,
      accountCode: account?.code ?? l.accountCode,
      accountLabel: account?.label ?? '',
      isCollective: account?.isCollective ?? l.usesThirdParty,
      label: l.label ?? template.label,
      debit: side == 'debit' ? amount : 0,
      credit: side == 'credit' ? amount : 0,
    ));
  }
  return result;
}
