import '../../domain/reference_models.dart';

/// Règles de choix des comptes proposés dans les formulaires (immobilisations, stocks, trésorerie, régularisations…).
/// Elles vivaient dans les écrans ; les regrouper permet de les tester et de les faire évoluer en un seul endroit.
class AccountSelection {
  const AccountSelection._();

  static bool _usable(Account a) => a.allowPosting && a.isActive;

  /// Comptes sur lesquels on peut imputer : imputables et actifs.
  static List<Account> postable(List<Account> all) => all.where(_usable).toList();

  /// Immobilisations : classe 2, hors amortissements (28) et dépréciations (29).
  static List<Account> fixedAssets(List<Account> all) =>
      all.where((a) => a.classNo == 2 && _usable(a) && !a.code.startsWith('28') && !a.code.startsWith('29')).toList();

  /// Comptes de stock : classe 3, hors dépréciations (39).
  static List<Account> stocks(List<Account> all) => all.where((a) => a.classNo == 3 && _usable(a) && !a.code.startsWith('39')).toList();

  /// Comptes de variation de stock : 603 (SYSCOHADA) ou 73 (variation de production).
  static List<Account> stockVariation(List<Account> all) => all.where((a) => _usable(a) && (a.code.startsWith('603') || a.code.startsWith('73'))).toList();

  /// Contrepartie d'une cession : créances sur cessions (485), trésorerie (classe 5) ou clients (411).
  static List<Account> disposalCounterparts(List<Account> all) =>
      all.where((a) => _usable(a) && (a.code.startsWith('485') || a.classNo == 5 || a.code.startsWith('411'))).toList();

  /// Comptes de trésorerie (classe 5).
  static List<Account> treasury(List<Account> all) => all.where((a) => a.classNo == 5 && _usable(a)).toList();

  /// Comptes collectifs de tiers sur lesquels une écriture peut être passée.
  static List<Account> collectives(List<Account> all) => all.where((a) => a.isCollective && _usable(a)).toList();

  /// Compte collectif proposé par défaut pour un type de tiers (clients 411, fournisseurs 401, salariés 421, associés 46…).
  static Account? defaultCollective(List<Account> collectives, String type) {
    final prefix = switch (type) {
      'customer' => '411',
      'supplier' => '401',
      'employee' => '421',
      'partner' => '46',
      _ => '',
    };
    return collectives.where((a) => prefix.isNotEmpty && a.code.startsWith(prefix)).firstOrNull ?? collectives.firstOrNull;
  }

  /// Contrepartie d'une écriture générée depuis un relevé : tout compte imputable hors trésorerie.
  static List<Account> statementCounterparts(List<Account> all) => all.where((a) => _usable(a) && a.classNo != 5).toList();

  /// Charges et produits d'une régularisation (classes 6 et 7).
  static List<Account> accrualResults(List<Account> all) => all.where((a) => _usable(a) && (a.classNo == 6 || a.classNo == 7)).toList();

  /// Comptes de régularisation (classe 4).
  static List<Account> accrualCounterparts(List<Account> all) => all.where((a) => _usable(a) && a.classNo == 4).toList();

  /// Préfixe du compte de régularisation par défaut selon le type de régularisation.
  static String accrualDefaultPrefix(String kind) => switch (kind) {
    'cap' => '408',
    'par' => '418',
    'cca' => '476',
    _ => '477',
  };

  /// Plan de comptes : filtre par classe puis par numéro (début) ou intitulé (contient), [search] déjà en minuscules.
  static List<Account> filterPlan(List<Account> all, {String search = '', int? classNo}) => all
      .where((a) => (classNo == null || a.classNo == classNo) && (search.isEmpty || a.code.startsWith(search) || a.label.toLowerCase().contains(search)))
      .toList();

  /// Tiers : filtre sur le code ou le nom (contient), [search] déjà en minuscules.
  static List<ThirdParty> filterThirdParties(List<ThirdParty> all, String search) =>
      all.where((p) => search.isEmpty || p.code.toLowerCase().contains(search) || p.name.toLowerCase().contains(search)).toList();
}
