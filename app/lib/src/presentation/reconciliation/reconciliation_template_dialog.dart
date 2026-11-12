import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../domain/bank_models.dart';

/// Choix ou création d'un gabarit de colonnes (mémorisé par banque).
class ReconciliationTemplateDialog extends StatefulWidget {
  const ReconciliationTemplateDialog({super.key, required this.templates, required this.bankName});

  final List<StatementTemplate> templates;
  final String bankName;

  @override
  State<ReconciliationTemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<ReconciliationTemplateDialog> {
  StatementTemplate? _existing;
  bool _create = false;
  late final _bank = TextEditingController(text: widget.bankName);
  final _label = TextEditingController(text: 'Export CSV');
  final _delimiter = TextEditingController(text: ';');
  final _date = TextEditingController(text: '1');
  final _lib = TextEditingController(text: '2');
  final _debit = TextEditingController(text: '3');
  final _credit = TextEditingController(text: '4');
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _valueDate = TextEditingController();
  bool _header = true;
  String _dateFormat = 'DD/MM/YYYY';
  String _decimal = ',';
  bool _inverted = false;

  Widget _col(String label, TextEditingController c) => SizedBox(
    width: 140,
    child: AkTextField(controller: c, label: label, keyboardType: TextInputType.number),
  );

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Gabarit du relevé',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.templates.isNotEmpty && !_create)
            AkDropdown<String?>(
              label: 'Gabarit mémorisé',
              value: _existing?.id,
              items: [for (final t in widget.templates) AkOption<String?>(t.id, '${t.bankName} · ${t.label}')],
              onChanged: (v) => setState(() => _existing = widget.templates.where((t) => t.id == v).firstOrNull),
            ),
          AkButton.ghost(_create ? 'Utiliser un gabarit mémorisé' : 'Nouveau gabarit', onPressed: () => setState(() => _create = !_create)),
          if (_create || widget.templates.isEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkTextField(controller: _bank, label: 'Banque'),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _label, label: 'Nom du gabarit'),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  child: AkTextField(controller: _delimiter, label: 'Séparateur'),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkCheckbox(value: _header, onChanged: (v) => setState(() => _header = v), label: 'Ligne d\'en-tête'),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Text('Numéros de colonnes (1 = première)', style: AkText.caption.copyWith(color: context.ak.textMuted)),
            const SizedBox(height: AkSpace.s1),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                _col('Date', _date),
                _col('Libellé', _lib),
                _col('Débit', _debit),
                _col('Crédit', _credit),
                _col('Montant signé', _amount),
                _col('Référence', _ref),
                _col('Date valeur', _valueDate),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkDropdown<String>(
                    label: 'Format de date',
                    value: _dateFormat,
                    items: const [AkOption('DD/MM/YYYY', 'jj/mm/aaaa'), AkOption('YYYY-MM-DD', 'aaaa-mm-jj'), AkOption('MM/DD/YYYY', 'mm/jj/aaaa')],
                    onChanged: (v) => setState(() => _dateFormat = v ?? 'DD/MM/YYYY'),
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkDropdown<String>(
                    label: 'Décimale',
                    value: _decimal,
                    items: const [AkOption(',', 'virgule'), AkOption('.', 'point')],
                    onChanged: (v) => setState(() => _decimal = v ?? ','),
                  ),
                ),
              ],
            ),
            AkCheckbox(value: _inverted, onChanged: (v) => setState(() => _inverted = v), label: 'Montant signé : positif = sortie'),
          ],
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Continuer',
          onPressed: () {
            if (!_create && widget.templates.isNotEmpty) {
              if (_existing != null) Navigator.pop(context, _existing);
              return;
            }
            int? n(TextEditingController c) => int.tryParse(c.text.trim());
            final amount = n(_amount);
            if (n(_date) == null || n(_lib) == null || (amount == null && (n(_debit) == null || n(_credit) == null))) return;
            Navigator.pop(
              context,
              StatementTemplate(
                bankName: _bank.text.trim(),
                label: _label.text.trim(),
                delimiter: _delimiter.text.isEmpty ? ';' : _delimiter.text,
                hasHeader: _header,
                dateColumn: n(_date)!,
                labelColumn: n(_lib)!,
                debitColumn: amount == null ? n(_debit) : null,
                creditColumn: amount == null ? n(_credit) : null,
                amountColumn: amount,
                referenceColumn: n(_ref),
                valueDateColumn: n(_valueDate),
                dateFormat: _dateFormat,
                decimalSeparator: _decimal,
                amountSignInverted: _inverted,
              ),
            );
          },
        ),
      ],
    );
  }
}
