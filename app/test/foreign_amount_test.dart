import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/offline/outbox_codec.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/infrastructure/supabase/mappers/entry_models_mappers.dart';

DraftLine line({int debit = 0, int credit = 0}) => DraftLine(accountId: 'a', debit: debit, credit: credit);

void main() {
  const eur = ForeignAmount(currency: 'EUR', amount: 3000, rate: 655.957);
  const usd = ForeignAmount(currency: 'USD', amount: 2000, rate: 612.5);

  test('contre-valeur arrondie à l\'unité, comme la base (3 000 EUR = 1 967 871 FCFA, 2 000 USD = 1 225 000 FCFA)', () {
    expect(eur.counterValue, 1967871);
    expect(usd.counterValue, 1225000);
  });

  test('seules les lignes qui portent la contre-valeur partent en devise', () {
    final foreign = line(debit: 1967871).toJson(1, foreign: eur);
    expect((foreign['currency_code'], foreign['amount_currency'], foreign['exchange_rate']), ('EUR', 3000.0, 655.957));
    expect(line(debit: 354, credit: 0).toJson(2, foreign: eur).containsKey('currency_code'), isFalse);
    expect(line(credit: 1967871).toJson(3).containsKey('currency_code'), isFalse, reason: 'écriture en FCFA : rien en devise');
  });

  test('l\'euro est à parité fixe, la devise exige montant et cours', () {
    expect(const ForeignAmount(currency: 'EUR', amount: 10, rate: 600).validate(), contains('655,957'));
    expect(const ForeignAmount(currency: 'USD', amount: 0, rate: 612.5).validate(), isNotNull);
    expect(usd.validate(), isNull);
  });

  test('validation : une ligne doit porter la contre-valeur', () {
    EntryDraft draft(int amount) => EntryDraft(journalId: 'j', label: 'Achat', foreign: usd, lines: [line(debit: amount), line(credit: amount)]);
    expect(draft(1225000).validationErrors(), isEmpty);
    expect(draft(1000000).validationErrors().single, contains('contre-valeur'));
  });

  test('le brouillard hors ligne conserve la devise', () {
    final d = EntryDraft(journalId: 'j', label: 'Achat', foreign: usd, lines: [line(debit: 1225000), line(credit: 1225000)]);
    final back = decodeEntryDraft(encodeEntryDraft(cabinetId: 'c', entityId: 'e', draft: d));
    expect((back.foreign!.currency, back.foreign!.amount, back.foreign!.rate), ('USD', 2000.0, 612.5));
  });
}
