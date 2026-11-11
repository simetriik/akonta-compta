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
    this.isCollective = false,
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

  /// Compte collectif : la ligne exige un tiers (sans quoi le champ Tiers n'apparaîtrait pas à la réouverture d'un brouillard).
  final bool isCollective;
  final String? thirdPartyId;
  final String? thirdPartyCode;
  final String? label;
  final int debit;
  final int credit;
  final String currencyCode;
  final double? amountCurrency;
  final double? exchangeRate;
  final String? letterCode;
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
    this.returnedComment,
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

  /// Motif renvoyé par le comptable sur un brouillard de client (D-044).
  final String? returnedComment;
  final bool isGenerated;
  final String? reversalOf;
  final String? reversedBy;
  final String? createdBy;
  final int totalDebit;
  final int totalCredit;
  final List<EntryLineModel> lines;

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
}

/// Montant d'une pièce en devise : seules les lignes qui portent la contre-valeur en FCFA sont enregistrées en devise (AN-25).
class ForeignAmount {
  const ForeignAmount({required this.currency, required this.amount, required this.rate});

  final String currency;
  final double amount;
  final double rate;

  /// Parité fixe de l'euro au FCFA.
  static const euroRate = 655.957;

  /// Contre-valeur en FCFA, arrondie à l'unité comme le calcule la base.
  int get counterValue => (amount * rate).round();

  /// Vrai si la ligne porte cette contre-valeur (au débit ou au crédit) et s'enregistre donc en devise.
  bool carries(DraftLine l) => (l.debit == counterValue && l.debit > 0) || (l.credit == counterValue && l.credit > 0);

  String? validate() {
    if (amount <= 0) return 'Montant en devise requis';
    if (rate <= 0) return 'Cours requis';
    if (currency == 'EUR' && (rate - euroRate).abs() > 0.0000001) return 'L\'euro est à parité fixe : 655,957';
    return null;
  }
}

class EntryDraft {
  EntryDraft({this.id, this.journalId, DateTime? date, this.reference = '', this.label = '', this.foreign, List<DraftLine>? lines})
      : entryDate = date ?? DateTime.now(),
        lines = lines ?? [DraftLine(), DraftLine()];

  String? id;
  String? journalId;
  DateTime entryDate;
  String reference;
  String label;
  final List<DraftLine> lines;

  /// Pièce en devise, ou `null` pour une écriture en FCFA.
  ForeignAmount? foreign;

  int get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  int get totalCredit => lines.fold(0, (s, l) => s + l.credit);
  int get balance => totalDebit - totalCredit;
  bool get isBalanced => balance == 0 && nonEmptyLines.length >= 2;

  /// Une ligne porte un montant ou un libellé sans compte : l'écriture ne pourra pas être validée.
  bool get hasLineWithoutAccount => lines.any((l) => !l.isEmpty && l.accountId == null);
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
    final fx = foreign;
    if (fx != null) {
      final problem = fx.validate();
      if (problem != null) {
        errors.add('Devise : $problem');
      } else if (!active.any(fx.carries)) {
        errors.add('Devise : aucune ligne ne porte la contre-valeur de ${fx.amount} ${fx.currency} (${fx.counterValue} FCFA)');
      }
    }
    return errors;
  }

  factory EntryDraft.fromEntry(EntryModel e) => EntryDraft(
        id: e.id,
        journalId: e.journalId,
        date: e.entryDate,
        reference: e.reference ?? '',
        label: e.label,
        foreign: e.lines.where((l) => l.currencyCode != 'XOF' && l.amountCurrency != null && l.exchangeRate != null).map((l) => ForeignAmount(currency: l.currencyCode, amount: l.amountCurrency!, rate: l.exchangeRate!)).firstOrNull,
        lines: [
          for (final l in e.lines)
            DraftLine(accountId: l.accountId, accountCode: l.accountCode, accountLabel: l.accountLabel, isCollective: l.isCollective, thirdPartyId: l.thirdPartyId, thirdPartyCode: l.thirdPartyCode ?? '', label: l.label ?? '', debit: l.debit, credit: l.credit),
        ],
      );
}

/// Application d'un modèle d'écriture : montants calculés depuis la saisie de base, les taux et le solde.
/// `resolveAccount` fait correspondre le numéro de référence du modèle (ex. 4452) au compte de l'entité.
/// [thirdParty] : tiers choisi à l'appel, placé sur les lignes du modèle marquées « tiers » (comptes collectifs génériques).
List<DraftLine> applyTemplate(EntryTemplate template, {required int baseAmount, required double? Function(String code) rateOf, required Account? Function(String referenceCode) resolveAccount, ThirdParty? thirdParty}) {
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
      thirdPartyId: l.usesThirdParty ? thirdParty?.id : null,
      thirdPartyCode: l.usesThirdParty ? (thirdParty?.code ?? '') : '',
      label: l.label ?? template.label,
      debit: side == 'debit' ? amount : 0,
      credit: side == 'credit' ? amount : 0,
    ));
  }
  return result;
}

class EntryFilter {
  const EntryFilter({this.journalId, this.month, this.status, this.reviewStatus, this.search, this.toReviewOnly = false});

  final String? journalId;
  final DateTime? month; // premier jour du mois
  final String? status;
  final String? reviewStatus;
  final String? search;
  final bool toReviewOnly;

  EntryFilter copyWith({String? journalId, DateTime? month, String? status, String? reviewStatus, String? search, bool? toReviewOnly, bool clearJournal = false, bool clearMonth = false, bool clearStatus = false}) =>
      EntryFilter(
        journalId: clearJournal ? null : (journalId ?? this.journalId),
        month: clearMonth ? null : (month ?? this.month),
        status: clearStatus ? null : (status ?? this.status),
        reviewStatus: reviewStatus ?? this.reviewStatus,
        search: search ?? this.search,
        toReviewOnly: toReviewOnly ?? this.toReviewOnly,
      );
}
