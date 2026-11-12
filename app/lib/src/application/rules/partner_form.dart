import '../../core/formatting.dart';
import 'inventory_forms.dart';

/// Associé d'un exercice : nom et part du capital en pourcentage.
class PartnerValues {
  const PartnerValues({required this.name, required this.sharePercent});

  final String name;
  final double sharePercent;
}

class PartnerForm {
  const PartnerForm._();

  /// Contrôle la saisie d'un associé ; [alreadyAllocated] : somme des parts déjà enregistrées (le total ne dépasse pas 100 %).
  static FormResult<PartnerValues> build({required String name, required String percent, required double alreadyAllocated}) {
    final cleanName = name.trim();
    if (cleanName.length < 2) return const FormResult.error('Nom de l\'associé requis.');
    final share = Fmt.parseDecimal(percent);
    if (share == null || share <= 0 || share > 100) return const FormResult.error('La part doit être comprise entre 0 et 100 %.');
    if (alreadyAllocated + share > 100.0001) {
      return FormResult.error('Le total des parts dépasserait 100 % (déjà réparti : ${alreadyAllocated.toStringAsFixed(2).replaceAll('.', ',')} %).');
    }
    return FormResult.ok(PartnerValues(name: cleanName, sharePercent: share));
  }
}
