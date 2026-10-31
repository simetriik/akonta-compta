import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bank_models.dart';
import '../../domain/reference_models.dart';
import 'services.dart';
import 'reconciliation_providers.dart';

/// État de l'écran de rapprochement : journal et date choisis, lignes à pointer, propositions, sélection en cours.
class ReconciliationView {
  const ReconciliationView({
    required this.until,
    this.journal,
    this.bank = const [],
    this.book = const [],
    this.proposals = const [],
    this.state,
    this.selBank = const {},
    this.selBook = const {},
    this.busy = false,
  });

  final DateTime until;
  final Journal? journal;
  final List<StatementLine> bank;
  final List<BookLine> book;
  final List<ReconciliationProposalModel> proposals;
  final ReconciliationStateModel? state;
  final Set<int> selBank;
  final Set<String> selBook;
  final bool busy;

  /// Total net des lignes de relevé sélectionnées (côté banque).
  int get selBankNet => bank.where((l) => selBank.contains(l.id)).fold(0, (s, l) => s + l.net);

  /// Total net des lignes comptables sélectionnées (côté entreprise).
  int get selBookNet => book.where((l) => selBook.contains(l.id)).fold(0, (s, l) => s + l.net);

  /// Le pointage n'est possible que des deux côtés, à montants égaux.
  bool get canMatch => selBank.isNotEmpty && selBook.isNotEmpty && selBankNet == selBookNet;

  ReconciliationView copyWith({
    DateTime? until,
    Journal? journal,
    bool clearJournal = false,
    List<StatementLine>? bank,
    List<BookLine>? book,
    List<ReconciliationProposalModel>? proposals,
    ReconciliationStateModel? state,
    bool clearState = false,
    Set<int>? selBank,
    Set<String>? selBook,
    bool? busy,
  }) => ReconciliationView(
    until: until ?? this.until,
    journal: clearJournal ? null : (journal ?? this.journal),
    bank: bank ?? this.bank,
    book: book ?? this.book,
    proposals: proposals ?? this.proposals,
    state: clearState ? null : (state ?? this.state),
    selBank: selBank ?? this.selBank,
    selBook: selBook ?? this.selBook,
    busy: busy ?? this.busy,
  );
}

/// Dernier jour du mois de la date donnée.
DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

final reconciliationControllerProvider = NotifierProvider.autoDispose<ReconciliationController, ReconciliationView>(ReconciliationController.new);

/// Chargement, sélection et pointage du rapprochement bancaire. Les actions laissent remonter les erreurs
/// (l'écran les affiche) et rechargent toujours les listes ensuite.
class ReconciliationController extends Notifier<ReconciliationView> {
  @override
  ReconciliationView build() => ReconciliationView(until: endOfMonth(DateTime.now()));

  Future<void> setJournal(Journal? journal) {
    state = ReconciliationView(until: state.until, journal: journal);
    return reload();
  }

  Future<void> setUntil(DateTime until) {
    state = state.copyWith(until: until);
    return reload();
  }

  /// Recharge relevé, comptabilité, propositions et état ; vide la sélection.
  Future<void> reload() async {
    final j = state.journal;
    if (j == null) return;
    state = state.copyWith(busy: true);
    final service = ref.read(reconciliationServiceProvider);
    final until = state.until;
    try {
      final bank = await service.unmatchedStatementLines(j.id, until: until);
      final book = await service.unmatchedBookLines(j.id, until: until);
      final proposals = await service.proposals(j.id, until: until);
      final st = await service.state(j.id, until);
      if (!ref.mounted) return;
      state = state.copyWith(bank: bank, book: book, proposals: proposals, state: st, selBank: {}, selBook: {});
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  void toggleBank(int id) => state = state.copyWith(selBank: state.selBank.contains(id) ? ({...state.selBank}..remove(id)) : {...state.selBank, id});

  void toggleBook(String id) => state = state.copyWith(selBook: state.selBook.contains(id) ? ({...state.selBook}..remove(id)) : {...state.selBook, id});

  /// Sélectionne les deux lignes de la première proposition.
  void selectFirstProposal() {
    if (state.proposals.isEmpty) return;
    final p = state.proposals.first;
    state = state.copyWith(selBank: {p.statementLineId}, selBook: {p.entryLineId});
  }

  /// Pointe la sélection courante.
  Future<void> matchSelected() async {
    try {
      await ref.read(reconciliationServiceProvider).match(state.journal!.id, state.selBank.toList(), state.selBook.toList());
    } finally {
      await reload();
    }
  }

  /// Accepte toutes les propositions ; une proposition refusée est ignorée. Renvoie le nombre de pointages faits.
  Future<int> acceptAllProposals() async {
    final service = ref.read(reconciliationServiceProvider);
    var n = 0;
    for (final p in state.proposals) {
      try {
        await service.match(state.journal!.id, [p.statementLineId], [p.entryLineId], note: 'proposition');
        n++;
      } catch (_) {
        // Une proposition qui ne passe plus (ligne déjà pointée) n'empêche pas les suivantes.
      }
    }
    await reload();
    return n;
  }

  /// Crée et valide l'écriture d'une ligne de relevé.
  Future<void> createEntryFromLine(int lineId, {required String accountId, String? thirdPartyId, String? label, DateTime? entryDate}) async {
    try {
      await ref.read(reconciliationServiceProvider).entryFromLine(lineId, accountId: accountId, thirdPartyId: thirdPartyId, label: label, entryDate: entryDate, validate: true);
    } finally {
      await reload();
    }
  }

  /// Fige l'état de rapprochement du mois.
  Future<void> finalizeMonth() async {
    try {
      await ref.read(reconciliationServiceProvider).finalize(state.journal!.id, state.until);
    } finally {
      await reload();
    }
  }

  /// Importe un relevé déjà lu ; enregistre d'abord le modèle de colonnes s'il est nouveau.
  Future<void> importStatement({
    required String cabinetId,
    required StatementTemplate template,
    required List<ParsedStatementLine> lines,
    required DateTime from,
    required DateTime to,
    int? opening,
    int? closing,
    String? fileName,
  }) async {
    final service = ref.read(reconciliationServiceProvider);
    try {
      var templateId = template.id;
      if (templateId == null) {
        templateId = (await service.saveTemplate(cabinetId, template)).id;
        ref.invalidate(statementTemplatesProvider);
      }
      await service.importStatement(journalId: state.journal!.id, from: from, to: to, lines: lines, opening: opening, closing: closing, templateId: templateId, fileName: fileName);
    } finally {
      await reload();
    }
  }
}
