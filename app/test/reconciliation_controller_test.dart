import 'package:akonta/src/application/providers/reconciliation_controller.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/domain/bank_models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/domain/repositories/reconciliation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dépôt de rapprochement en mémoire : une ligne de relevé et une ligne comptable de même montant.
class _FakeReconciliation implements ReconciliationRepository {
  final matches = <(List<int>, List<String>, String?)>[];
  var failMatch = false;
  var loads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');

  @override
  Future<List<StatementLine>> unmatchedStatementLines(String journalId, {DateTime? until}) async {
    loads++;
    return [StatementLine(id: 1, statementId: 's', date: DateTime(2026, 9, 3), label: 'Virement', debit: 0, credit: 5000), StatementLine(id: 2, statementId: 's', date: DateTime(2026, 9, 4), label: 'Frais', debit: 300, credit: 0)];
  }

  @override
  Future<List<BookLine>> unmatchedBookLines(String journalId, {DateTime? until}) async => [
    BookLine(id: 'b1', entryId: 'e', date: DateTime(2026, 9, 3), number: 1, label: 'Encaissement', debit: 5000, credit: 0),
    BookLine(id: 'b2', entryId: 'e', date: DateTime(2026, 9, 5), number: 2, label: 'Autre', debit: 0, credit: 700),
  ];

  @override
  Future<List<ReconciliationProposalModel>> proposals(String journalId, {DateTime? until}) async => [const ReconciliationProposalModel(statementLineId: 1, entryLineId: 'b1', amount: 5000, dayGap: 0)];

  @override
  Future<ReconciliationStateModel> state(String journalId, DateTime asOf) async =>
      const ReconciliationStateModel(bookBalance: 0, bankBalance: 0, depositsInTransit: 0, outstandingPayments: 0, unmatchedBankCredits: 0, unmatchedBankDebits: 0, difference: 0);

  @override
  Future<String> match(String journalId, List<int> statementLineIds, List<String> entryLineIds, {String? note}) async {
    if (failMatch) throw Exception('refusé');
    matches.add((statementLineIds, entryLineIds, note));
    return 'm1';
  }
}

const journal = Journal(id: 'j1', code: 'BQ', label: 'Banque', type: 'bank', treasuryAccountId: 'a5', treasuryAccountCode: '5211000', isActive: true);

void main() {
  late _FakeReconciliation repo;
  late ProviderContainer container;
  ReconciliationView view() => container.read(reconciliationControllerProvider);
  ReconciliationController controller() => container.read(reconciliationControllerProvider.notifier);

  setUp(() {
    repo = _FakeReconciliation();
    container = ProviderContainer(overrides: [reconciliationRepositoryProvider.overrideWithValue(repo)]);
    container.listen(reconciliationControllerProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('sans journal, rien n\'est chargé', () async {
    await controller().reload();
    expect(repo.loads, 0);
    expect(view().journal, isNull);
  });

  test('choisir un journal charge relevé, comptabilité, propositions et état', () async {
    await controller().setJournal(journal);
    expect(view().bank.length, 2);
    expect(view().book.length, 2);
    expect(view().proposals.length, 1);
    expect(view().state, isNotNull);
    expect(view().busy, isFalse);
  });

  test('la date par défaut est la fin du mois courant', () {
    final now = DateTime.now();
    expect(view().until, DateTime(now.year, now.month + 1, 0));
  });

  test('le pointage exige des montants égaux des deux côtés', () async {
    await controller().setJournal(journal);
    controller().toggleBank(1);
    expect(view().canMatch, isFalse);
    controller().toggleBook('b1');
    expect(view().selBankNet, 5000);
    expect(view().selBookNet, 5000);
    expect(view().canMatch, isTrue);
    controller().toggleBook('b1');
    controller().toggleBook('b2');
    expect(view().canMatch, isFalse);
  });

  test('pointer envoie la sélection puis recharge et vide la sélection', () async {
    await controller().setJournal(journal);
    controller().toggleBank(1);
    controller().toggleBook('b1');
    final before = repo.loads;
    await controller().matchSelected();
    expect(repo.matches.single.$1, [1]);
    expect(repo.matches.single.$2, ['b1']);
    expect(repo.loads, before + 1);
    expect(view().selBank, isEmpty);
    expect(view().selBook, isEmpty);
  });

  test('un pointage refusé remonte l\'erreur et recharge quand même', () async {
    await controller().setJournal(journal);
    controller().toggleBank(1);
    controller().toggleBook('b1');
    repo.failMatch = true;
    final before = repo.loads;
    await expectLater(controller().matchSelected(), throwsException);
    expect(repo.loads, before + 1);
    expect(view().busy, isFalse);
  });

  test('accepter les propositions compte les réussites et ignore les refus', () async {
    await controller().setJournal(journal);
    expect(await controller().acceptAllProposals(), 1);
    expect(repo.matches.single.$3, 'proposition');
    repo.failMatch = true;
    expect(await controller().acceptAllProposals(), 0);
  });

  test('sélectionner la première proposition coche les deux côtés', () async {
    await controller().setJournal(journal);
    controller().selectFirstProposal();
    expect(view().selBank, {1});
    expect(view().selBook, {'b1'});
  });

  test('changer de date recharge avec la nouvelle date', () async {
    await controller().setJournal(journal);
    final before = repo.loads;
    await controller().setUntil(DateTime(2026, 8, 31));
    expect(view().until, DateTime(2026, 8, 31));
    expect(repo.loads, before + 1);
  });
}
