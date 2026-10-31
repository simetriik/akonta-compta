import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/reference_models.dart';

class EntryTemplatePicker extends StatefulWidget {
  const EntryTemplatePicker({super.key, required this.templates, this.initial});

  final List<EntryTemplate> templates;
  final EntryTemplate? initial;

  @override
  State<EntryTemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<EntryTemplatePicker> {
  late EntryTemplate? _template = widget.initial;
  final _amount = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final amount = Fmt.parseAmount(_amount.text);
    return AkDialog(
      title: 'Appliquer un modèle',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AkDropdown<EntryTemplate>(
            label: 'Modèle',
            value: _template,
            items: [for (final t in widget.templates) AkOption(t, '${t.code} — ${t.label}')],
            onChanged: (v) => setState(() => _template = v),
          ),
          const SizedBox(height: AkSpace.s3),
          AkAmountField(controller: _amount, label: 'Montant de base', onChanged: (_) => setState(() {})),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Appliquer',
          onPressed: _template == null || amount == null || amount <= 0 ? null : () => Navigator.pop(context, (_template!, amount)),
        ),
      ],
    );
  }
}
