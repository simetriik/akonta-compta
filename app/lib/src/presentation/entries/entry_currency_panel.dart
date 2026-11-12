import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/entry_models.dart';

/// Devises proposées pour une pièce étrangère ; l'euro est à parité fixe.
const _currencies = ['EUR', 'USD', 'GBP', 'CHF', 'CAD', 'NGN', 'GHS', 'MAD'];

/// Pièce en devise (AN-25) : devise, montant et cours ; affiche la contre-valeur en FCFA à saisir sur les lignes concernées.
class EntryCurrencyPanel extends StatefulWidget {
  const EntryCurrencyPanel({super.key, required this.draft, required this.readOnly, required this.onChanged});

  final EntryDraft draft;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  State<EntryCurrencyPanel> createState() => _EntryCurrencyPanelState();
}

class _EntryCurrencyPanelState extends State<EntryCurrencyPanel> {
  late bool _enabled = widget.draft.foreign != null;
  late String _currency = widget.draft.foreign?.currency ?? 'EUR';
  late final _amount = TextEditingController(text: widget.draft.foreign == null ? '' : '${widget.draft.foreign!.amount}'.replaceAll('.', ','));
  late final _rate = TextEditingController(text: widget.draft.foreign == null ? '' : '${widget.draft.foreign!.rate}'.replaceAll('.', ','));

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  /// Reporte la saisie dans le brouillard : `null` tant que le montant ou le cours n'est pas lisible.
  void _sync() {
    final amount = Fmt.parseDecimal(_amount.text);
    final rate = _currency == 'EUR' ? ForeignAmount.euroRate : Fmt.parseDecimal(_rate.text);
    widget.draft.foreign = !_enabled || amount == null || rate == null ? null : ForeignAmount(currency: _currency, amount: amount, rate: rate);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final fx = widget.draft.foreign;
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s2),
      child: AkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AkCheckbox(
              key: const Key('entry-foreign-toggle'),
              value: _enabled,
              label: 'Pièce en devise',
              onChanged: widget.readOnly
                  ? null
                  : (v) {
                      _enabled = v;
                      _sync();
                      setState(() {});
                    },
            ),
            if (_enabled) ...[
              const SizedBox(height: AkSpace.s2),
              Wrap(
                spacing: AkSpace.s3,
                runSpacing: AkSpace.s3,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 140,
                    child: AkDropdown<String>(
                      key: const Key('entry-foreign-currency'),
                      label: 'Devise',
                      value: _currency,
                      items: [for (final c in _currencies) AkOption(c, c)],
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              _currency = v ?? _currency;
                              if (_currency == 'EUR') _rate.text = '655,957';
                              _sync();
                              setState(() {});
                            },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: AkTextField(controller: _amount, key: const Key('entry-foreign-amount'), label: 'Montant en devise', enabled: !widget.readOnly, onChanged: (_) => _sync()),
                  ),
                  SizedBox(
                    width: 200,
                    child: AkTextField(
                      controller: _rate,
                      key: const Key('entry-foreign-rate'),
                      label: 'Cours (FCFA pour 1 $_currency)',
                      enabled: !widget.readOnly && _currency != 'EUR',
                      onChanged: (_) => _sync(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AkSpace.s2),
              Text(
                fx == null
                    ? 'Saisissez le montant en devise et le cours.'
                    : 'Contre-valeur : ${Fmt.fcfa(fx.counterValue)} FCFA. Saisissez ce montant en FCFA sur les lignes de la pièce ; seules les lignes qui le portent sont enregistrées en devise.',
                key: const Key('entry-foreign-counter-value'),
                style: AkText.caption.copyWith(color: t.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
