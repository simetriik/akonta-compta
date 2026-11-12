import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entities_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/partner_form.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../widgets/error_display.dart';

/// Associés d'un exercice et répartition du capital (AN-04) : liste, total, ajout et retrait.
class FiscalYearPartnersSection extends ConsumerWidget {
  const FiscalYearPartnersSection({super.key, required this.entityId, required this.fiscalYear});

  final String entityId;
  final FiscalYear fiscalYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final partners = ref.watch(fiscalYearPartnersProvider(fiscalYear.id)).value ?? const <FiscalYearPartner>[];
    final canEdit = fiscalYear.status != 'closed' && (ref.watch(permissionsProvider).value ?? PermissionSet.empty).has('entities.manage', entityId: entityId);
    final total = partners.fold<double>(0, (sum, p) => sum + p.sharePercent);
    String pct(double v) => '${v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                partners.isEmpty ? 'Associés : aucun renseigné' : 'Associés · total réparti ${pct(total)}${(total - 100).abs() > 0.01 ? ' (≠ 100 %)' : ''}',
                style: AkText.caption.copyWith(color: (total - 100).abs() > 0.01 && partners.isNotEmpty ? t.warning : t.textMuted),
              ),
            ),
            if (canEdit) AkButton.ghost('Ajouter un associé', key: Key('add-partner-${fiscalYear.label}'), icon: Icons.person_add_alt_outlined, onPressed: () => _add(context, ref, total)),
          ],
        ),
        for (final p in partners)
          AkListRow(
            title: Text(p.name),
            subtitle: Text(pct(p.sharePercent)),
            trailing: canEdit ? AkIconButton(icon: Icons.delete_outline, tooltip: 'Retirer', dense: true, onPressed: () => _remove(context, ref, p)) : null,
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, double allocated) async {
    final values = await showDialog<PartnerValues>(context: context, builder: (_) => _PartnerDialog(allocated: allocated));
    if (values == null || !context.mounted) return;
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref.read(entitiesServiceProvider).addPartner(cabinet!.id, fiscalYear.id, name: values.name, sharePercent: values.sharePercent);
      ref.invalidate(fiscalYearPartnersProvider(fiscalYear.id));
    } catch (e) {
      if (context.mounted) showError(context, e, action: 'L\'ajout de l\'associé');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, FiscalYearPartner p) async {
    if (!await showAkConfirm(context, title: 'Retirer ${p.name} ?', message: 'L\'associé est retiré de la répartition du capital de cet exercice.', confirmLabel: 'Retirer', danger: true)) return;
    try {
      await ref.read(entitiesServiceProvider).removePartner(p.id);
      ref.invalidate(fiscalYearPartnersProvider(fiscalYear.id));
    } catch (e) {
      if (context.mounted) showError(context, e, action: 'Le retrait');
    }
  }
}

class _PartnerDialog extends StatefulWidget {
  const _PartnerDialog({required this.allocated});

  final double allocated;

  @override
  State<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends State<_PartnerDialog> {
  final _name = TextEditingController();
  final _percent = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Ajouter un associé',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(controller: _name, key: const Key('partner-name'), label: 'Nom de l\'associé', autofocus: true),
          const SizedBox(height: AkSpace.s3),
          AkTextField(controller: _percent, key: const Key('partner-percent'), label: 'Part du capital (%)', keyboardType: TextInputType.number),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: AkSpace.s3), child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!))),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Ajouter', key: const Key('partner-submit'), onPressed: () {
          final form = PartnerForm.build(name: _name.text, percent: _percent.text, alreadyAllocated: widget.allocated);
          if (form.error != null) {
            setState(() => _error = form.error);
          } else {
            Navigator.pop(context, form.value);
          }
        }),
      ],
    );
  }
}
