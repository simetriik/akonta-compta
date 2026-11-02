import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../domain/invoice_models.dart';
import '../../domain/models.dart';
import '../widgets/error_display.dart';

Future<void> showEmcfDevicesDialog(BuildContext context, EntitySummary entity) => showDialog<void>(context: context, builder: (_) => EmcfDevicesDialog(entity: entity));

/// e-MCF du dossier : un NIM et un jeton par point de vente (réservé à qui détient emcf.manage).
class EmcfDevicesDialog extends ConsumerStatefulWidget {
  const EmcfDevicesDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<EmcfDevicesDialog> createState() => _EmcfDevicesDialogState();
}

class _EmcfDevicesDialogState extends ConsumerState<EmcfDevicesDialog> {
  final _nim = TextEditingController();
  final _label = TextEditingController();
  String _mode = 'test';
  bool _busy = false;

  @override
  void dispose() {
    _nim.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_nim.text.trim().length != 10 || _label.text.trim().isEmpty) {
      showAkToast(context, 'Le NIM comporte 10 caractères et le point de vente doit avoir un nom.', kind: AkToastKind.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      await ref.read(invoicesServiceProvider).createDevice(
          cabinetId: profile!.cabinetId, entityId: widget.entity.id, nim: _nim.text, label: _label.text, mode: _mode);
      _nim.clear();
      _label.clear();
      ref.invalidate(emcfDevicesProvider(widget.entity.id));
    } catch (e) {
      if (mounted) showError(context, e, action: 'La déclaration de l\'e-MCF');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setToken(EmcfDevice d) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AkDialog(
        title: 'Jeton de ${d.label}',
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collez le jeton fourni par la DGI pour le NIM ${d.nim}. Il est vérifié auprès de la DGI puis gardé côté serveur : personne ne pourra le relire.'),
          const SizedBox(height: AkSpace.s3),
          AkTextField(key: const Key('token-field'), controller: controller, label: 'Jeton', obscureText: true, autofocus: true),
        ]),
        actions: [
          AkButton.ghost('Annuler', onPressed: () => Navigator.pop(ctx)),
          AkButton.primary('Vérifier et enregistrer', key: const Key('save-token'), onPressed: () => Navigator.pop(ctx, controller.text)),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(invoicesServiceProvider).setToken(d.id, token);
      if (mounted) showAkToast(context, 'Jeton vérifié auprès de la DGI et enregistré.');
    } catch (e) {
      if (mounted) showError(context, e, action: 'L\'enregistrement du jeton');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(EmcfDevice d, bool active) async {
    try {
      await ref.read(invoicesServiceProvider).setDeviceActive(d.id, active);
      ref.invalidate(emcfDevicesProvider(widget.entity.id));
    } catch (e) {
      if (mounted) showError(context, e, action: 'La modification de l\'e-MCF');
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(emcfDevicesProvider(widget.entity.id));
    return AkDialog(
      title: 'e-MCF · ${widget.entity.name}',
      size: AkDialogSize.l,
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          devices.when(
            loading: () => const AkLoading(),
            error: (e, _) => Text(errorText(e)),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.only(bottom: AkSpace.s3), child: Text('Aucun point de vente déclaré.'))
                : Column(children: [
                    for (final d in list)
                      AkListRow(
                        key: Key('device-${d.nim}'),
                        title: Text('${d.label} · ${d.nim}'),
                        subtitle: Text(d.isTest ? 'Environnement de test de la DGI' : 'Production'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          AkButton.secondary('Jeton', dense: true, icon: Icons.key_outlined, onPressed: _busy ? null : () => _setToken(d)),
                          const SizedBox(width: AkSpace.s2),
                          AkSwitch(value: d.isActive, onChanged: (v) => _toggle(d, v)),
                        ]),
                      ),
                  ]),
          ),
          const Divider(),
          const AkSectionTitle('Déclarer un point de vente'),
          const SizedBox(height: AkSpace.s2),
          Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s3, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: 160, child: AkTextField(key: const Key('device-nim'), controller: _nim, label: 'NIM', hint: 'XX01000001', maxLength: 10, mono: true, textCapitalization: TextCapitalization.characters)),
            SizedBox(width: 240, child: AkTextField(key: const Key('device-label'), controller: _label, label: 'Point de vente', hint: 'Boutique principale')),
            SizedBox(
              width: 200,
              child: AkDropdown<String>(
                label: 'Environnement',
                value: _mode,
                items: const [AkOption('test', 'Test (DGI)'), AkOption('production', 'Production')],
                onChanged: (v) => setState(() => _mode = v ?? 'test'),
              ),
            ),
            AkButton.primary('Ajouter', key: const Key('add-device'), icon: Icons.add, loading: _busy, onPressed: _busy ? null : _add),
          ]),
        ]),
      ),
      actions: [AkButton.ghost('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}
