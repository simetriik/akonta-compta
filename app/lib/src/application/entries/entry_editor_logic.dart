import '../../domain/entry_models.dart';
import '../../domain/reference_models.dart';
import '../../domain/suggestion_models.dart';

/// Règles de l'éditeur d'écriture, sans dépendance à Flutter : contrôles avant enregistrement, application d'un modèle,
/// reprise d'une suggestion, contrepartie. L'écran ne garde que l'affichage et la navigation.
class EntryEditorLogic {
  const EntryEditorLogic._();

  /// Erreurs bloquantes : complètes pour une validation, minimales pour un simple enregistrement en brouillard.
  static List<String> errors(EntryDraft draft, {required bool validate}) {
    if (validate) return draft.validationErrors();
    return [
      if (draft.journalId == null) 'Journal requis',
      if (draft.label.trim().isEmpty) 'Libellé requis',
      if (draft.nonEmptyLines.any((l) => l.accountId == null)) 'Chaque ligne saisie doit avoir un compte',
    ];
  }

  /// Vrai si la grille contient déjà un compte ou un montant (la remplacer demande confirmation).
  static bool hasContent(EntryDraft draft) => draft.lines.any((l) => l.accountId != null || l.debit > 0 || l.credit > 0);

  /// Taux en vigueur à la date donnée pour le code d'un taux de taxe, ou `null` s'il n'y en a pas.
  static double? rateOn(List<TaxRate> rates, String code, DateTime on) {
    final r = rates.where((r) => r.code == code && !r.validFrom.isAfter(on) && (r.validTo == null || !r.validTo!.isBefore(on))).firstOrNull;
    return r?.rate;
  }

  /// Remplace les lignes par celles du modèle calculées sur le montant de base ; une ligne vide termine la grille.
  static void applyTemplateTo(
    EntryDraft draft,
    EntryTemplate template, {
    required int baseAmount,
    required List<Account> accounts,
    required List<TaxRate> rates,
    required DateTime today,
    ThirdParty? thirdParty,
  }) {
    final length = accounts.isEmpty ? 0 : accounts.first.code.length;
    Account? resolve(String code) => accounts.where((a) => a.code == padAccountCode(code, length)).firstOrNull;
    draft.lines
      ..clear()
      ..addAll(applyTemplate(template, baseAmount: baseAmount, rateOf: (code) => rateOn(rates, code, today), resolveAccount: resolve, thirdParty: thirdParty))
      ..add(DraftLine());
  }

  /// Lignes d'un modèle tirées de l'écriture en cours (« Enregistrer comme modèle ») : comptes génériques (zéros de
  /// complément retirés, ils sont recomplétés à la longueur du dossier à l'appel), tiers à choisir à l'appel, montant libre.
  static List<TemplateLine> templateLinesFrom(EntryDraft draft) {
    final lines = <TemplateLine>[];
    for (final l in draft.nonEmptyLines.where((l) => l.accountCode.isNotEmpty)) {
      final generic = l.accountCode.replaceFirst(RegExp(r'0+$'), '');
      lines.add(
        TemplateLine(
          lineNo: lines.length + 1,
          accountCode: generic.isEmpty ? l.accountCode : generic,
          usesThirdParty: l.isCollective || l.thirdPartyId != null,
          side: l.debit > 0 ? 'debit' : 'credit',
          formula: 'input',
          label: l.label.trim().isEmpty ? null : l.label.trim(),
        ),
      );
    }
    return lines;
  }

  /// Reprend les comptes, tiers et libellés d'une écriture passée, sans les montants.
  static void useSuggestedEntry(EntryDraft draft, EntrySuggestion s, List<Account> accounts) {
    draft.lines
      ..clear()
      ..addAll([
        for (final l in s.lines)
          DraftLine(
            accountId: l.accountId,
            accountCode: l.accountCode,
            accountLabel: l.accountLabel,
            isCollective: accounts.where((a) => a.id == l.accountId).firstOrNull?.isCollective ?? l.thirdPartyId != null,
            thirdPartyId: l.thirdPartyId,
            thirdPartyCode: l.thirdPartyCode ?? '',
            label: l.label ?? '',
          ),
      ])
      ..add(DraftLine());
  }

  /// Place le compte proposé sur la première ligne sans compte (une ligne est ajoutée si toutes en ont un).
  static void useSuggestedAccount(EntryDraft draft, AccountSuggestion s, List<Account> accounts) {
    final account = accounts.where((a) => a.id == s.accountId).firstOrNull;
    var line = draft.lines.where((l) => l.accountId == null).firstOrNull;
    if (line == null) {
      line = DraftLine();
      draft.lines.add(line);
    }
    line
      ..accountId = s.accountId
      ..accountCode = s.accountCode
      ..accountLabel = s.accountLabel
      ..isCollective = account?.isCollective ?? false;
  }

  /// Ajoute une ligne en fin de grille ; si l'écriture est déséquilibrée, la contrepartie est déjà proposée.
  static DraftLine appendLine(EntryDraft draft) {
    final line = DraftLine();
    final gap = draft.balance;
    if (gap > 0) line.credit = gap;
    if (gap < 0) line.debit = -gap;
    draft.lines.add(line);
    return line;
  }
}
