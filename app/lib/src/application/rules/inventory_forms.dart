import '../../core/formatting.dart';

/// Résultat du contrôle d'un formulaire : la valeur prête à envoyer, ou le message à afficher.
class FormResult<T> {
  const FormResult.ok(T this.value) : error = null;
  const FormResult.error(String this.error) : value = null;

  final T? value;
  final String? error;
}

/// Régularisation (charge à payer, produit à recevoir, charge ou produit constaté d'avance) saisie à l'écran.
class AccrualValues {
  const AccrualValues({required this.description, required this.counterpartAccountId, required this.totalAmount, required this.from, required this.to});

  final String description;
  final String counterpartAccountId;
  final int totalAmount;
  final DateTime from;
  final DateTime to;
}

/// Cession ou mise au rebut d'une immobilisation.
class DisposalValues {
  const DisposalValues({required this.date, required this.price});

  final DateTime date;
  final int price;
}

/// Cours de clôture d'une devise.
class FxRateValues {
  const FxRateValues({required this.currency, required this.rate});

  final String currency;
  final double rate;
}

/// Taux de provision des créances douteuses (fractions entre 0 et 1).
class ProvisionRates {
  const ProvisionRates({required this.rate91to180, required this.rateOver180});

  final double rate91to180;
  final double rateOver180;
}

/// Contrôles des formulaires de l'inventaire : mêmes règles pour tous les écrans, testables sans interface.
class InventoryForms {
  const InventoryForms._();

  static FormResult<AccrualValues> accrual({
    required String description,
    required String? accountId,
    required String? counterpartAccountId,
    required String total,
    required String from,
    required String to,
  }) {
    final amount = Fmt.parseAmount(total);
    final start = Fmt.parseDate(from);
    final end = Fmt.parseDate(to);
    if (description.trim().isEmpty ||
        accountId == null ||
        counterpartAccountId == null ||
        amount == null ||
        amount <= 0 ||
        start == null ||
        end == null ||
        end.isBefore(start)) {
      return const FormResult.error('Description, comptes, montant et période requis');
    }
    return FormResult.ok(AccrualValues(description: description.trim(), counterpartAccountId: counterpartAccountId, totalAmount: amount, from: start, to: end));
  }

  static FormResult<DisposalValues> disposal({required String date, required String price}) {
    final d = Fmt.parseDate(date);
    if (d == null) return const FormResult.error('Date invalide (jj/mm/aaaa)');
    final amount = price.trim().isEmpty ? 0 : Fmt.parseAmount(price);
    if (amount == null || amount < 0) return const FormResult.error('Prix de cession invalide');
    return FormResult.ok(DisposalValues(date: d, price: amount));
  }

  static FormResult<FxRateValues> fxRate({required String currency, required String rate}) {
    final code = currency.trim().toUpperCase();
    if (code.length != 3) return const FormResult.error('Code devise sur 3 lettres requis (ex. EUR)');
    final r = Fmt.parseDecimal(rate);
    if (r == null || r <= 0) return const FormResult.error('Cours invalide');
    return FormResult.ok(FxRateValues(currency: code, rate: r));
  }

  static FormResult<int> stockValue({required String closing, required String? variationAccountId}) {
    final value = Fmt.parseAmount(closing);
    if (value == null || value < 0) return const FormResult.error('Stock final invalide');
    if (variationAccountId == null) return const FormResult.error('Compte de variation requis');
    return FormResult.ok(value);
  }

  /// Pourcentages saisis (« 25 », « 2,5 »), un champ vide valant 0 ; refuse tout texte illisible ou hors de 0 à 100.
  static FormResult<ProvisionRates> provisionRates({required String r91, required String r180}) {
    double? percent(String s) => s.trim().isEmpty ? 0 : Fmt.parseDecimal(s);
    final a = percent(r91);
    final b = percent(r180);
    if (a == null || b == null || a < 0 || a > 100 || b < 0 || b > 100) return const FormResult.error('Les taux sont des pourcentages entre 0 et 100');
    return FormResult.ok(ProvisionRates(rate91to180: a / 100, rateOver180: b / 100));
  }
}
