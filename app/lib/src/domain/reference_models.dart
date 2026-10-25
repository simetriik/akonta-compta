/// Modèles du module 3 : comptes, tiers, journaux, modèles d'écritures, taux.
library;

/// Compte dont le code correspond exactement au texte saisi, ou au texte complété par des zéros
/// à la longueur du plan de l'entité (saisie clavier : « 6318 » désigne 6318000).
Account? matchAccountCode(Iterable<Account> accounts, String input) {
  final q = input.trim();
  if (q.isEmpty || !RegExp(r'^\d+$').hasMatch(q)) return null;
  final length = accounts.isEmpty ? q.length : accounts.first.code.length;
  final code = q.length < length ? q.padRight(length, '0') : q;
  return accounts.where((a) => a.code == code).firstOrNull;
}

class Account {
  const Account({required this.id, required this.code, required this.label, required this.classNo, required this.normalSide, required this.isCollective, required this.isLetterable, required this.allowPosting, required this.isActive, this.parentId});

  final String id;
  final String code;
  final String label;
  final int classNo;
  final String normalSide;
  final bool isCollective;
  final bool isLetterable;
  final bool allowPosting;
  final bool isActive;
  final String? parentId;

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        classNo: (j['class'] as num).toInt(),
        normalSide: j['normal_side'] as String,
        isCollective: j['is_collective'] as bool,
        isLetterable: j['is_letterable'] as bool,
        allowPosting: j['allow_posting'] as bool,
        isActive: j['is_active'] as bool,
        parentId: j['parent_id'] as String?,
      );

  /// Chiffres significatifs (sans les zéros de complément).
  String get significant => code.replaceAll(RegExp(r'0+$'), '');
}

/// Complète un numéro saisi à la longueur fixe de l'entité (ex. « 4011 » → « 4011000 » pour 7).
/// Renvoie null si le numéro est invalide (non numérique, commence par 0, trop long).
String? padAccountCode(String input, int length) {
  final s = input.trim();
  if (!RegExp(r'^[1-9][0-9]*$').hasMatch(s) || s.length > length) return null;
  return s.padRight(length, '0');
}

String? validateThirdPartyCode(String? v) {
  final s = (v ?? '').trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(s)) return 'Code : 2 à 10 lettres majuscules ou chiffres';
  return null;
}

String? validateJournalCode(String? v) {
  final s = (v ?? '').trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{2,6}$').hasMatch(s)) return 'Code : 2 à 6 lettres majuscules ou chiffres';
  return null;
}

class ThirdParty {
  const ThirdParty({required this.id, required this.code, required this.name, required this.type, this.taxId, this.address, this.phone, this.email, required this.isActive, this.collectiveCodes = const []});

  final String id;
  final String code;
  final String name;
  final String type;
  final String? taxId;
  final String? address;
  final String? phone;
  final String? email;
  final bool isActive;
  final List<String> collectiveCodes;

  factory ThirdParty.fromJson(Map<String, dynamic> j) => ThirdParty(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        taxId: j['tax_id'] as String?,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        isActive: j['is_active'] as bool,
        collectiveCodes: [for (final l in (j['third_party_accounts'] as List? ?? const [])) (l['accounts'] as Map)['code'] as String],
      );

  static const typeLabels = {'customer': 'Client', 'supplier': 'Fournisseur', 'employee': 'Salarié', 'partner': 'Associé', 'other': 'Autre'};
}

class Journal {
  const Journal({required this.id, required this.code, required this.label, required this.type, this.treasuryAccountId, this.treasuryAccountCode, required this.isActive});

  final String id;
  final String code;
  final String label;
  final String type;
  final String? treasuryAccountId;
  final String? treasuryAccountCode;
  final bool isActive;

  factory Journal.fromJson(Map<String, dynamic> j) => Journal(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        type: j['type'] as String,
        treasuryAccountId: j['treasury_account_id'] as String?,
        treasuryAccountCode: (j['accounts'] as Map?)?['code'] as String?,
        isActive: j['is_active'] as bool,
      );

  static const typeLabels = {'purchases': 'Achats', 'sales': 'Ventes', 'bank': 'Banque', 'cash': 'Caisse', 'misc': 'Opérations diverses', 'opening': 'À-nouveaux', 'payroll': 'Paie'};
  bool get isTreasury => type == 'bank' || type == 'cash';
}

class TemplateLine {
  const TemplateLine({required this.lineNo, required this.accountCode, required this.usesThirdParty, required this.side, required this.formula, this.refLineNo, this.percent, this.taxRateCode, this.label});

  final int lineNo;
  final String accountCode;
  final bool usesThirdParty;
  final String side;
  final String formula;
  final int? refLineNo;
  final double? percent;
  final String? taxRateCode;
  final String? label;

  factory TemplateLine.fromJson(Map<String, dynamic> j) => TemplateLine(
        lineNo: (j['line_no'] as num).toInt(),
        accountCode: j['account_code'] as String,
        usesThirdParty: j['uses_third_party'] as bool,
        side: j['side'] as String,
        formula: j['formula'] as String,
        refLineNo: (j['ref_line_no'] as num?)?.toInt(),
        percent: j['percent'] == null ? null : double.parse('${j['percent']}'),
        taxRateCode: j['tax_rate_code'] as String?,
        label: j['label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'line_no': lineNo,
        'account_code': accountCode,
        'uses_third_party': usesThirdParty,
        'side': side,
        'formula': formula,
        'ref_line_no': refLineNo,
        'percent': percent,
        'tax_rate_code': taxRateCode,
        'label': label,
      };

  String get formulaLabel => switch (formula) {
        'input' => 'saisie',
        'percent_of' => '${taxRateCode ?? '${((percent ?? 0) * 100).toStringAsFixed(2)} %'} de la ligne $refLineNo',
        'balance' => 'solde',
        _ => formula,
      };
}

class EntryTemplate {
  const EntryTemplate({required this.id, required this.code, required this.label, this.journalType, this.description, required this.isCabinetLevel, required this.lines});

  final String id;
  final String code;
  final String label;
  final String? journalType;
  final String? description;
  final bool isCabinetLevel;
  final List<TemplateLine> lines;

  factory EntryTemplate.fromJson(Map<String, dynamic> j) => EntryTemplate(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        journalType: j['journal_type'] as String?,
        description: j['description'] as String?,
        isCabinetLevel: j['entity_id'] == null,
        lines: [for (final l in (j['entry_template_lines'] as List? ?? const [])) TemplateLine.fromJson(l as Map<String, dynamic>)]..sort((a, b) => a.lineNo.compareTo(b.lineNo)),
      );
}

class TaxRate {
  const TaxRate({required this.id, required this.code, required this.label, required this.rate, required this.validFrom, this.validTo});

  final String id;
  final String code;
  final String label;
  final double rate;
  final DateTime validFrom;
  final DateTime? validTo;

  factory TaxRate.fromJson(Map<String, dynamic> j) => TaxRate(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        rate: double.parse('${j['rate']}'),
        validFrom: DateTime.parse(j['valid_from'] as String),
        validTo: j['valid_to'] == null ? null : DateTime.parse(j['valid_to'] as String),
      );

  String get percentLabel => '${(rate * 100).toStringAsFixed(rate * 100 == (rate * 100).roundToDouble() ? 0 : 2)} %';
}
