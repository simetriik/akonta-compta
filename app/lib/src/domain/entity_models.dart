
/// Modèles du module 2 : entité (fiche R1-R3 + paramètres), dirigeants, exercices, associés, périodes.
library;

class EntityDetail {
  const EntityDetail({
    required this.id,
    required this.cabinetId,
    required this.name,
    this.acronym,
    this.legalForm,
    this.address,
    this.countryCode = 'BJ',
    this.taxId,
    this.tradeRegister,
    this.taxRegime,
    this.incorporationDate,
    this.establishmentsCount,
    this.controlType,
    this.controlOrigin,
    this.mainActivity,
    this.secondaryActivities = const [],
    this.activityCode,
    this.accountLength = 7,
    this.accountingSystem = 'normal',
    this.monthlyLockEnabled = false,
    this.isActive = true,
  });

  final String id;
  final String cabinetId;
  final String name;
  final String? acronym;
  final String? legalForm;
  final String? address;
  final String countryCode;
  final String? taxId;
  final String? tradeRegister;
  final String? taxRegime;
  final DateTime? incorporationDate;
  final int? establishmentsCount;
  final String? controlType;
  final String? controlOrigin;
  final String? mainActivity;
  final List<String> secondaryActivities;
  final String? activityCode;
  final int accountLength;

  /// Référentiel comptable choisi à la création, non modifiable : `normal` (SYSCOHADA) ou `sycebnl` (entités à but non lucratif).
  final String accountingSystem;
  final bool monthlyLockEnabled;
  final bool isActive;
}

/// Champs saisis dans le formulaire d'entité (création ou modification).
class EntityInput {
  const EntityInput({
    required this.name,
    this.acronym,
    this.legalForm,
    this.address,
    this.countryCode = 'BJ',
    this.taxId,
    this.tradeRegister,
    this.taxRegime,
    this.incorporationDate,
    this.establishmentsCount,
    this.controlType,
    this.controlOrigin,
    this.mainActivity,
    this.secondaryActivities = const [],
    this.activityCode,
    this.accountLength,
    this.accountingSystem,
    this.monthlyLockEnabled,
  });

  final String name;
  final String? acronym;
  final String? legalForm;
  final String? address;
  final String countryCode;
  final String? taxId;
  final String? tradeRegister;
  final String? taxRegime;
  final DateTime? incorporationDate;
  final int? establishmentsCount;
  final String? controlType;
  final String? controlOrigin;
  final String? mainActivity;
  final List<String> secondaryActivities;
  final String? activityCode;
  final int? accountLength;

  /// Renseigné à la création seulement : le référentiel ne se modifie plus ensuite.
  final String? accountingSystem;
  final bool? monthlyLockEnabled;

  /// Référentiel suggéré par la forme juridique saisie : `sycebnl` pour les associations, ONG, fondations,
  /// syndicats et autres entités à but non lucratif, `null` sinon (le choix reste à l'utilisateur).
  static String? suggestAccountingSystem(String? legalForm) {
    final s = ' ${(legalForm ?? '').toLowerCase()} ';
    const keywords = [' association', ' ong ', ' o.n.g', ' fondation', ' syndicat', 'but non lucratif'];
    return keywords.any(s.contains) ? 'sycebnl' : null;
  }

  /// Validation de la fiche : dénomination obligatoire, IFU béninois à 13 chiffres s'il est saisi.
  static String? validateName(String? v) => (v ?? '').trim().length < 2 ? 'Dénomination obligatoire' : null;

  static String? validateTaxId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d{13}$').hasMatch(s)) return 'IFU : 13 chiffres attendus';
    return null;
  }
}

class Director {
  const Director({required this.id, required this.fullName, required this.position, this.nationality, this.address, this.isBoardMember = false});

  final String id;
  final String fullName;
  final String position;
  final String? nationality;
  final String? address;
  final bool isBoardMember;
}

class FiscalYear {
  const FiscalYear({required this.id, required this.entityId, required this.label, required this.startDate, required this.endDate, required this.status, this.capital, this.headcount, this.finalClosedAt});

  final String id;
  final String entityId;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final int? capital;
  final int? headcount;
  /// Date de l'arrêté définitif (exercice intangible).
  final DateTime? finalClosedAt;

  String get statusLabel => switch (status) {
        'open' => 'Ouvert',
        'closing' => 'En clôture',
        'closed' => 'Clôturé',
        _ => status,
      };
}

/// Règles de dates d'un exercice (conception §3.2), vérifiées avant l'envoi (la base les impose aussi).
String? validateFiscalYearDates({required DateTime start, required DateTime end, required DateTime? previousEnd}) {
  if (!end.isAfter(start)) return 'La fin doit être après le début';
  if (end.month != 12 || end.day != 31) return 'Un exercice se termine un 31 décembre';
  if (previousEnd != null) {
    final expected = previousEnd.add(const Duration(days: 1));
    if (start != expected) return 'L\'exercice doit commencer le lendemain du précédent (${expected.day.toString().padLeft(2, '0')}/${expected.month.toString().padLeft(2, '0')}/${expected.year})';
    if (start.month != 1 || start.day != 1 || end.year != start.year) return 'Un exercice courant va du 1er janvier au 31 décembre';
  } else if (end.difference(start).inDays >= 730) {
    return 'Le premier exercice ne peut dépasser 24 mois';
  }
  return null;
}

class Period {
  const Period({required this.id, required this.fiscalYearId, required this.periodNo, required this.startDate, required this.endDate, required this.isLocked, this.unlockReason});

  final String id;
  final String fiscalYearId;
  final int periodNo;
  final DateTime startDate;
  final DateTime endDate;
  final bool isLocked;
  final String? unlockReason;
}

class FiscalYearPartner {
  const FiscalYearPartner({required this.id, required this.name, required this.sharePercent});

  final String id;
  final String name;
  final double sharePercent;
}

class JournalTemplate {
  const JournalTemplate({required this.code, required this.label, required this.type, required this.isDefaultChecked});

  final String code;
  final String label;
  final String type;
  final bool isDefaultChecked;

  bool get isTreasury => type == 'bank' || type == 'cash';
}

class AccountRef {
  const AccountRef({required this.id, required this.code, required this.label});

  final String id;
  final String code;
  final String label;
}

class EntityHistoryItem {
  const EntityHistoryItem({required this.changedAt, required this.changes, this.changedBy});

  final DateTime changedAt;
  final Map<String, dynamic> changes;
  final String? changedBy;
}
