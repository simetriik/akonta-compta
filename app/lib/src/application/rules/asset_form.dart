import '../../core/formatting.dart';

/// Saisie brute de la fiche d'une immobilisation, telle que tapée dans le formulaire.
class AssetInput {
  const AssetInput({
    required this.code,
    required this.designation,
    required this.accountId,
    required this.acquisition,
    required this.service,
    required this.gross,
    required this.salvage,
    required this.months,
    required this.method,
    required this.coefficient,
    required this.prior,
    required this.isNew,
  });

  final String code;
  final String designation;
  final String? accountId;
  final String acquisition;
  final String service;
  final String gross;
  final String salvage;
  final String months;
  final String method;
  final String coefficient;
  final String prior;

  /// Création (code et compte à fournir) ou modification (ils ne changent plus).
  final bool isNew;
}

/// Résultat du contrôle de la fiche : les champs à enregistrer, ou le message à afficher.
class AssetBuild {
  const AssetBuild.ok(Map<String, dynamic> this.fields) : error = null;
  const AssetBuild.error(String this.error) : fields = null;

  final Map<String, dynamic>? fields;
  final String? error;
}

/// Contrôle la fiche d'immobilisation et prépare les champs envoyés au serveur.
class AssetForm {
  const AssetForm._();

  /// Coefficient dégressif par défaut quand la méthode est dégressive et le champ vide ou illisible.
  static const defaultDecliningCoefficient = 1.5;

  static AssetBuild build(AssetInput i) {
    final acq = Fmt.parseDate(i.acquisition);
    final svc = Fmt.parseDate(i.service);
    final gross = Fmt.parseAmount(i.gross);
    final months = int.tryParse(i.months.trim());
    if (i.code.trim().isEmpty ||
        i.designation.trim().isEmpty ||
        acq == null ||
        svc == null ||
        gross == null ||
        gross <= 0 ||
        months == null ||
        months <= 0 ||
        (i.isNew && i.accountId == null)) {
      return const AssetBuild.error('Code, désignation, compte, dates, valeur brute et durée requis');
    }
    if (svc.isBefore(acq)) return const AssetBuild.error('La mise en service ne peut pas précéder la date d\'acquisition : corrigez l\'une des deux dates.');
    return AssetBuild.ok({
      if (i.isNew) 'code': i.code.trim(),
      'designation': i.designation.trim(),
      if (i.isNew) 'asset_account_id': i.accountId,
      'acquisition_date': acq.toIso8601String().substring(0, 10),
      'service_date': svc.toIso8601String().substring(0, 10),
      'gross_value': gross,
      'salvage_value': Fmt.parseAmount(i.salvage) ?? 0,
      'duration_months': months,
      'method': i.method,
      'declining_coefficient': i.method == 'declining' ? double.tryParse(i.coefficient.replaceAll(',', '.')) ?? defaultDecliningCoefficient : null,
      'prior_depreciation': Fmt.parseAmount(i.prior) ?? 0,
    });
  }
}
