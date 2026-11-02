import '../../domain/invoice_models.dart';

/// Taux de TVA du groupe B affiché à l'écran (la DGI renvoie le taux officiel à l'émission).
const int defaultVatRate = 18;

/// Aperçu des totaux : prix TTC, HT du groupe B = TTC ÷ (1 + taux) arrondi, TVA = TTC − HT (exemple de la spécification :
/// 3 600 TTC → HT 3 051, TVA 549).
InvoiceTotalsPreview previewTotals(List<InvoiceLine> lines, {int vatRate = defaultVatRate}) {
  var a = 0;
  var b = 0;
  for (final l in lines) {
    if (l.taxGroup == 'B') {
      b += l.amount;
    } else {
      a += l.amount;
    }
  }
  final ht = ((b * 100) + (100 + vatRate) ~/ 2) ~/ (100 + vatRate);
  return InvoiceTotalsPreview(totalA: a, totalB: b, htB: ht, vatB: b - ht);
}

/// Taux de l'AIB : A = 1 %, B = 5 %.
int aibRate(String? aib) => switch (aib) { 'A' => 1, 'B' => 5, _ => 0 };

/// Problèmes qui empêchent d'enregistrer ou d'émettre le brouillon (messages en français, vide si tout va bien).
List<String> draftProblems(InvoiceDraft d, {bool forIssue = false}) {
  final out = <String>[];
  if (d.operatorName.trim().isEmpty) out.add('Indiquez le nom de l\'opérateur.');
  final ifu = d.clientIfu?.trim() ?? '';
  if (ifu.isNotEmpty && ifu.length != 13) out.add('L\'IFU du client comporte 13 caractères.');
  if (d.type == 'FA' && (d.reference ?? '').length != 24) out.add('La référence de la facture d\'origine doit comporter 24 caractères.');
  if (forIssue || d.lines.isNotEmpty) {
    if (d.lines.isEmpty) out.add('Ajoutez au moins un article.');
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      final n = i + 1;
      if (l.name.trim().isEmpty) out.add('Article $n : le nom est obligatoire.');
      if (l.price <= 0) out.add('Article $n : le prix unitaire doit être supérieur à 0.');
      if (l.quantity <= 0) out.add('Article $n : la quantité doit être supérieure à 0.');
    }
  }
  return out;
}
