import '../../../domain/reference_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

Account accountFromJson(Map<String, dynamic> j) => Account(
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

ThirdParty thirdPartyFromJson(Map<String, dynamic> j) => ThirdParty(
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

Journal journalFromJson(Map<String, dynamic> j) => Journal(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        type: j['type'] as String,
        treasuryAccountId: j['treasury_account_id'] as String?,
        treasuryAccountCode: (j['accounts'] as Map?)?['code'] as String?,
        isActive: j['is_active'] as bool,
      );

TemplateLine templateLineFromJson(Map<String, dynamic> j) => TemplateLine(
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

EntryTemplate entryTemplateFromJson(Map<String, dynamic> j) => EntryTemplate(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        journalType: j['journal_type'] as String?,
        description: j['description'] as String?,
        isCabinetLevel: j['entity_id'] == null,
        lines: [for (final l in (j['entry_template_lines'] as List? ?? const [])) templateLineFromJson(l as Map<String, dynamic>)]..sort((a, b) => a.lineNo.compareTo(b.lineNo)),
      );

TaxRate taxRateFromJson(Map<String, dynamic> j) => TaxRate(
        id: j['id'] as String,
        code: j['code'] as String,
        label: j['label'] as String,
        rate: double.parse('${j['rate']}'),
        validFrom: DateTime.parse(j['valid_from'] as String),
        validTo: j['valid_to'] == null ? null : DateTime.parse(j['valid_to'] as String),
      );

extension TemplateLineJson on TemplateLine {
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
}
