import 'package:akonta/src/domain/closing_models.dart';
import 'package:akonta/src/domain/lettering_models.dart';
import 'package:akonta/src/domain/repositories/closing_repository.dart';
import 'package:akonta/src/domain/repositories/lettering_repository.dart';

/// Dépôt de lettrage fictif : lignes d'un compte clients, une proposition et un lettrage en cours.
class FakeLetteringRepository implements LetteringRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Méthode non prévue dans les tests golden : ${invocation.memberName}');

  @override
  Future<List<UnletteredLine>> unlettered(String entityId, String accountId, {String? thirdPartyId}) async => [
    UnletteredLine(
      lineId: 'l1',
      entryId: 'en1',
      entryDate: DateTime(2026, 9, 14),
      journalCode: 'VT',
      number: 1000041,
      label: 'Facture F-2026-041 CHU',
      thirdPartyCode: 'CHU',
      debit: 1180000,
      credit: 0,
    ),
    UnletteredLine(
      lineId: 'l2',
      entryId: 'en2',
      entryDate: DateTime(2026, 9, 30),
      journalCode: 'VT',
      number: 1000052,
      label: 'Facture F-2026-052 SOBEBRA',
      thirdPartyCode: 'SOBEBRA',
      debit: 560000,
      credit: 0,
    ),
    UnletteredLine(
      lineId: 'l3',
      entryId: 'en3',
      entryDate: DateTime(2026, 10, 12),
      journalCode: 'VT',
      number: 1000063,
      label: 'Facture F-2026-063 CHU',
      thirdPartyCode: 'CHU',
      debit: 240000,
      credit: 0,
    ),
    UnletteredLine(
      lineId: 'l4',
      entryId: 'en4',
      entryDate: DateTime(2026, 10, 8),
      journalCode: 'BQ',
      number: 1000117,
      label: 'Règlement virement CHU',
      thirdPartyCode: 'CHU',
      debit: 0,
      credit: 1180000,
    ),
    UnletteredLine(
      lineId: 'l5',
      entryId: 'en5',
      entryDate: DateTime(2026, 10, 15),
      journalCode: 'BQ',
      number: 1000121,
      label: 'Acompte SOBEBRA',
      thirdPartyCode: 'SOBEBRA',
      debit: 0,
      credit: 300000,
    ),
  ];

  @override
  Future<List<LetteringProposal>> proposals(String entityId, String accountId, {String? thirdPartyId}) async => const [
    LetteringProposal(debitLineId: 'l1', creditLineIds: ['l4'], thirdPartyCode: 'CHU', amount: 1180000, rule: 'same_amount'),
  ];

  @override
  Future<List<LetteringGroup>> groups(String entityId, String accountId, {String? thirdPartyId}) async => [
    LetteringGroup(id: 'g1', code: 'AA', isPartial: false, totalDebit: 720000, totalCredit: 720000, createdAt: DateTime(2026, 10, 2)),
    LetteringGroup(id: 'g2', code: 'AB', isPartial: true, totalDebit: 900000, totalCredit: 400000, createdAt: DateTime(2026, 10, 9)),
  ];
}

/// Dépôt de clôture fictif : contrôles de clôture variés (conforme, bloquant, alerte, levé).
class FakeClosingRepository implements ClosingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Méthode non prévue dans les tests golden : ${invocation.memberName}');

  @override
  Future<List<ClosingCheck>> runChecks(String entityId, String fyId) async => const [
    ClosingCheck(code: 'balanced', label: 'Équilibre débit / crédit du grand livre', severity: 'blocking', status: 'passed', details: {}),
    ClosingCheck(code: 'no_draft', label: 'Aucune écriture en brouillard', severity: 'blocking', status: 'failed', details: {'count': 6}),
    ClosingCheck(code: 'bank_rec', label: 'Rapprochement bancaire à jour au 31/12', severity: 'warning', status: 'failed', details: {'count': 2}),
    ClosingCheck(code: 'lettering', label: 'Comptes de tiers lettrés', severity: 'warning', status: 'waived', details: {}),
    ClosingCheck(code: 'inventory', label: 'Travaux d\'inventaire générés', severity: 'blocking', status: 'passed', details: {}),
  ];
}
