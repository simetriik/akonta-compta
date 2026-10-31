import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/bank_models.dart';
import '../../domain/reference_models.dart';

class EntryFromLineDialog extends StatefulWidget {
  const EntryFromLineDialog({super.key, required this.line, required this.accounts, required this.thirdParties});

  final StatementLine line;
  final List<Account> accounts;
  final List<ThirdParty> thirdParties;

  @override
  State<EntryFromLineDialog> createState() => _EntryFromLineDialogState();
}

class _EntryFromLineDialogState extends State<EntryFromLineDialog> {
  Account? _account;
  ThirdParty? _tp;
  late final _label = TextEditingController(text: widget.line.label);
  late final _date = TextEditingController(text: Fmt.date(widget.line.date));

  @override
  void dispose() {
    _label.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return AkDialog(
      title: 'Créer l\'écriture depuis le relevé',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${Fmt.date(l.date)} · ${l.label} · ${l.debit > 0 ? 'sortie' : 'entrée'} de ${Fmt.fcfa(l.debit > 0 ? l.debit : l.credit)} FCFA'),
          const SizedBox(height: AkSpace.s3),
          AkAccountField(
            label: 'Compte de contrepartie (ex. 6318)',
            accounts: widget.accounts,
            selected: _account,
            onSelected: (a) => setState(() => _account = a),
            onCleared: () {
              if (_account != null) setState(() => _account = null);
            },
          ),
          const SizedBox(height: AkSpace.s2),
          AkDateField(
            key: const Key('entry-from-line-date'),
            controller: _date,
            label: 'Date de l\'écriture',
            helper: 'Date d\'opération par défaut ; à reporter si sa période est verrouillée.',
            onChanged: (_) => setState(() {}),
          ),
          if (_account?.isCollective ?? false) ...[
            const SizedBox(height: AkSpace.s2),
            AkThirdPartyField(label: 'Tiers', thirdParties: widget.thirdParties, onSelected: (t) => setState(() => _tp = t)),
          ],
          const SizedBox(height: AkSpace.s2),
          AkTextField(controller: _label, label: 'Libellé'),
          const SizedBox(height: AkSpace.s2),
          Text(
            'L\'écriture est validée dans le journal de banque et pointée avec la ligne du relevé.',
            style: AkText.caption.copyWith(color: context.ak.textMuted),
          ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Créer et pointer',
          onPressed: _account == null || ((_account!.isCollective) && _tp == null) || Fmt.parseDate(_date.text) == null
              ? null
              : () => Navigator.pop(context, (_account!, _tp, _label.text.trim(), Fmt.parseDate(_date.text)!)),
        ),
      ],
    );
  }
}
