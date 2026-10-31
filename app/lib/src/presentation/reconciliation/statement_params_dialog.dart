import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';

class StatementParamsDialog extends StatefulWidget {
  const StatementParamsDialog({super.key, required this.from, required this.to, required this.count, required this.errors});

  final DateTime from;
  final DateTime to;
  final int count;
  final List<String> errors;

  @override
  State<StatementParamsDialog> createState() => _StatementParamsDialogState();
}

class _StatementParamsDialogState extends State<StatementParamsDialog> {
  late final _from = TextEditingController(text: Fmt.date(widget.from));
  late final _to = TextEditingController(text: Fmt.date(widget.to));
  final _opening = TextEditingController();
  final _closing = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Relevé : ${widget.count} lignes lues',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkDateField(controller: _from, label: 'Du'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _to, label: 'Au'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _opening, label: 'Solde début (facultatif)'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkAmountField(controller: _closing, label: 'Solde fin (facultatif)'),
              ),
            ],
          ),
          if (widget.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: Text(
                '${widget.errors.length} ligne(s) ignorée(s) : ${widget.errors.take(3).join(' · ')}',
                style: AkText.caption.copyWith(color: context.ak.danger),
              ),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Importer',
          onPressed: () {
            final f = Fmt.parseDate(_from.text), t = Fmt.parseDate(_to.text);
            if (f == null || t == null) return;
            Navigator.pop(context, (f, t, Fmt.parseAmount(_opening.text), Fmt.parseAmount(_closing.text)));
          },
        ),
      ],
    );
  }
}
