import 'package:intl/intl.dart';

/// Formats français : FCFA entiers (séparateur de milliers insécable), dates jj/mm/aaaa.
abstract final class Fmt {
  static final NumberFormat _amount = NumberFormat('#,##0', 'fr_FR');
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final DateFormat _month = DateFormat('MMMM yyyy', 'fr_FR');

  /// Montant FCFA ; chaîne vide pour zéro (colonnes débit / crédit).
  static String fcfa(int? amount, {bool showZero = false}) {
    if (amount == null || (amount == 0 && !showZero)) return '';
    return _amount.format(amount);
  }

  /// Solde signé (débit − crédit) sans signe moins : « 1 250 000 D », « 340 000 C », « 0 » s'il est nul.
  static String balance(int signed) {
    if (signed == 0) return '0';
    return '${_amount.format(signed.abs())} ${signed > 0 ? 'D' : 'C'}';
  }

  static String date(DateTime? d) => d == null ? '' : _date.format(d);

  static String month(DateTime d) => _month.format(d);

  /// Analyse un montant saisi (espaces, points ou espaces insécables tolérés) ; null si invalide.
  static int? parseAmount(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s  .]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Analyse un nombre décimal saisi avec virgule ou point (« 2,5 » ou « 2.5 ») ; null si illisible.
  static double? parseDecimal(String input) => double.tryParse(input.trim().replaceAll(',', '.'));

  /// Analyse une date jj/mm/aaaa ; null si invalide.
  static DateTime? parseDate(String input) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(input.trim());
    if (m == null) return null;
    final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.day != d || date.month != mo) return null;
    return date;
  }
}
