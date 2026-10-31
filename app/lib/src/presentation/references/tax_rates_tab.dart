import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import 'references_widgets.dart';

class TaxRatesTab extends ConsumerWidget {
  const TaxRatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final rates = ref.watch(taxRatesProvider);
    final canEdit = ref.watch(permissionsProvider).value?.has('cabinet.settings') ?? false;
    return Column(
      children: [
        if (canEdit)
          ListToolbar(
            action: AkButton.primary(
              'Nouveau taux',
              icon: Icons.add,
              dense: true,
              onPressed: () => showDialog(context: context, builder: (_) => const TaxRateDialog()),
            ),
          ),
        Expanded(
          child: AsyncView(
            value: rates,
            onRetry: () => ref.invalidate(taxRatesProvider),
            builder: (list) => SingleChildScrollView(
              padding: EdgeInsets.all(akPageMargin(context)),
              child: AkTable<TaxRate>(
                minWidth: 560,
                rows: list,
                emptyMessage: 'Aucun taux.',
                columns: [
                  AkColumn<TaxRate>(
                    label: 'Code',
                    width: 120,
                    cell: (context, r) => Text(r.code, style: AkText.code.copyWith(color: t.text)),
                  ),
                  AkColumn<TaxRate>.text(label: 'Libellé', text: (r) => r.label, flex: 3),
                  AkColumn<TaxRate>(label: 'Taux', width: 80, numeric: true, cell: (context, r) => AkAmountText(r.percentLabel)),
                  AkColumn<TaxRate>.text(label: 'Valide du', text: (r) => Fmt.date(r.validFrom), width: 110),
                  AkColumn<TaxRate>.text(label: 'au', text: (r) => r.validTo == null ? '—' : Fmt.date(r.validTo), width: 110),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TaxRateDialog extends ConsumerStatefulWidget {
  const TaxRateDialog({super.key});

  @override
  ConsumerState<TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends ConsumerState<TaxRateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  final _rate = TextEditingController();
  final _from = TextEditingController(text: Fmt.date(DateTime.now()));
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Nouveau taux (ou nouvelle valeur d\'un taux existant)',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(controller: _code, label: 'Code (ex. TVA, AIB1)', mono: true, textCapitalization: TextCapitalization.characters),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _label, label: 'Libellé'),
          const SizedBox(height: AkSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkTextField(controller: _rate, label: 'Taux en % (ex. 18)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _from, label: 'Valide à partir du'),
              ),
            ],
          ),
          if (_error != null) formError(_error!),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: () async {
            final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
            final from = Fmt.parseDate(_from.text);
            if (!RegExp(r'^[A-Z0-9_]{2,20}$').hasMatch(_code.text.trim().toUpperCase()) ||
                _label.text.trim().isEmpty ||
                rate == null ||
                rate < 0 ||
                rate > 100 ||
                from == null) {
              setState(() => _error = 'Code, libellé, taux (0-100) et date valides requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesServiceProvider).addTaxRate(cabinet!.id, code: _code.text, label: _label.text, rate: rate / 100, validFrom: from);
              ref.invalidate(taxRatesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
        ),
      ],
    );
  }
}
