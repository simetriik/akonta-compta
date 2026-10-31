import '../../domain/reference_models.dart';

/// Saisie brute d'une ligne de modèle d'écriture, telle que tapée dans le formulaire (textes non interprétés).
class TemplateLineInput {
  const TemplateLineInput({
    required this.account,
    required this.thirdParty,
    required this.side,
    required this.formula,
    this.refLine = '',
    this.percent = '',
    this.rateCode,
    this.label = '',
  });

  final String account;
  final bool thirdParty;
  final String side;
  final String formula;
  final String refLine;
  final String percent;
  final String? rateCode;
  final String label;
}

/// Résultat du contrôle d'un modèle : les lignes prêtes à enregistrer, ou le message à afficher.
class TemplateBuild {
  const TemplateBuild.ok(List<TemplateLine> this.lines) : error = null;
  const TemplateBuild.error(String this.error) : lines = null;

  final List<TemplateLine>? lines;
  final String? error;
}

/// Contrôle la saisie d'un modèle et construit ses lignes.
class TemplateBuilder {
  const TemplateBuilder._();

  static final _numericAccount = RegExp(r'^[1-9][0-9]*$');

  static TemplateBuild build({required String code, required String label, required List<TemplateLineInput> inputs}) {
    if (code.trim().isEmpty || label.trim().isEmpty) return const TemplateBuild.error('Code et libellé requis');
    final lines = <TemplateLine>[];
    for (var i = 0; i < inputs.length; i++) {
      final l = inputs[i];
      if (!_numericAccount.hasMatch(l.account.trim())) return TemplateBuild.error('Ligne ${i + 1} : compte numérique requis');
      final pct = l.percent.trim().isEmpty ? null : double.tryParse(l.percent.replaceAll(',', '.'));
      final percentOf = l.formula == 'percent_of';
      lines.add(
        TemplateLine(
          lineNo: i + 1,
          accountCode: l.account.trim(),
          usesThirdParty: l.thirdParty,
          side: l.side,
          formula: l.formula,
          refLineNo: percentOf ? int.tryParse(l.refLine.trim()) : null,
          percent: percentOf && l.rateCode == null && pct != null ? pct / 100 : null,
          taxRateCode: percentOf ? l.rateCode : null,
          label: l.label.trim().isEmpty ? null : l.label.trim(),
        ),
      );
    }
    return TemplateBuild.ok(lines);
  }
}
