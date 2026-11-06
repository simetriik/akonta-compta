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

  /// Code proposé pour un modèle à partir de son libellé : majuscules, chiffres et « _ », 20 caractères au plus, unique
  /// parmi [existing] (suffixe numérique si besoin). Valide pour la contrainte `^[A-Z0-9_]{2,20}$` de la base.
  static String suggestCode(String label, Iterable<String> existing) {
    const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaceeeeiiiinooooouuuuyy';
    final folded = label.toLowerCase().split('').map((c) {
      final i = from.indexOf(c);
      return i < 0 ? c : to[i];
    }).join();
    var base = folded.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '').toUpperCase();
    if (base.length > 18) base = base.substring(0, 18).replaceAll(RegExp(r'_+$'), '');
    if (base.length < 2) base = 'MODELE';
    final taken = existing.map((c) => c.toUpperCase()).toSet();
    if (!taken.contains(base)) return base;
    for (var n = 2; n < 1000; n++) {
      final candidate = '$base$n';
      if (!taken.contains(candidate)) return candidate;
    }
    return base;
  }

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
