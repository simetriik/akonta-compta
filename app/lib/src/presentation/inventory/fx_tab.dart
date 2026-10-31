import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import 'inventory_widgets.dart';

class FxTab extends ConsumerStatefulWidget {
  const FxTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<FxTab> createState() => _FxTabState();
}

class _FxTabState extends ConsumerState<FxTab> {
  final _currency = TextEditingController(text: 'USD');
  final _rate = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkPage(
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Cours de clôture'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Cours de clôture (l\'euro est à parité fixe 655,957). Les créances et dettes en devises non lettrées sont réévaluées au cours de clôture : écarts 478 / 479 et provision pour pertes de change, extournés au 1er janvier.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              Wrap(
                spacing: AkSpace.s2,
                runSpacing: AkSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 120,
                    child: AkTextField(
                      controller: _currency,
                      label: 'Devise',
                      mono: true,
                      inputFormatters: [TextInputFormatter.withFunction((old, v) => v.copyWith(text: v.text.toUpperCase()))],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: AkTextField(
                      controller: _rate,
                      label: 'Cours de clôture (FCFA)',
                      mono: true,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  AkButton.secondary(
                    'Enregistrer le cours',
                    onPressed: () async {
                      final r = double.tryParse(_rate.text.replaceAll(',', '.'));
                      if (r == null || _currency.text.trim().length != 3) return;
                      final cabinet = await ref.read(currentCabinetProvider.future);
                      await ref.read(inventoryServiceProvider).setClosingRate(cabinet!.id, _currency.text.trim().toUpperCase(), widget.fy.endDate, r);
                      if (context.mounted) showAkToast(context, 'Cours enregistré.');
                    },
                  ),
                  AkButton.primary(
                    'Générer les écarts',
                    icon: Icons.auto_awesome,
                    onPressed: () => runGeneration(
                      context,
                      ref,
                      () => ref.read(inventoryServiceProvider).generateFxRevaluation(widget.entity.id, widget.fy.id),
                      'Écarts de conversion',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
