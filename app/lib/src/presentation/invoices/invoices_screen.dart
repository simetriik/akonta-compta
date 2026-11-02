import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../core/formatting.dart';
import '../../domain/invoice_models.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import 'emcf_devices_dialog.dart';
import 'invoice_settings_dialog.dart';
import 'invoice_status_badge.dart';

/// Factures normalisées e-MECeF du dossier courant : liste, nouvelle facture, gestion des e-MCF (D-043).
class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _InvoicesBody(entity: entity));
}

class _InvoicesBody extends ConsumerWidget {
  const _InvoicesBody({required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canIssue = perms.has('invoices.issue', entityId: entity.id);
    final canManageDevices = perms.has('emcf.manage', entityId: entity.id);
    final canSetAccounts = perms.has('references.manage', entityId: entity.id);
    final invoices = ref.watch(invoicesProvider(entity.id));
    final devices = ref.watch(emcfDevicesProvider(entity.id)).value;
    final hasDevice = devices?.any((d) => d.isActive) ?? false;

    return AkPage(
      children: [
        AkPageHead(
          title: 'Factures',
          subtitle: 'Factures normalisées e-MECeF · ${entity.name}',
          actions: [
            if (canManageDevices)
              AkButton.secondary('e-MCF', key: const Key('manage-devices'), icon: Icons.settings_input_antenna, onPressed: () => showEmcfDevicesDialog(context, entity)),
            if (canSetAccounts)
              AkButton.secondary('Comptabilité', key: const Key('invoice-settings'), icon: Icons.account_tree_outlined, onPressed: () => showInvoiceSettingsDialog(context, entity)),
            if (canIssue)
              AkButton.primary('Nouvelle facture', key: const Key('new-invoice'), icon: Icons.add, onPressed: hasDevice ? () => context.go('/factures/nouvelle') : null),
          ],
        ),
        const SizedBox(height: AkSpace.s4),
        if (devices != null && !hasDevice)
          AkBanner(
            kind: AkBannerKind.warning,
            child: Text(canManageDevices
                ? 'Aucun e-MCF actif pour ce dossier. Déclarez le point de vente (NIM) et enregistrez son jeton avec le bouton « e-MCF ».'
                : 'Aucun e-MCF actif pour ce dossier. Demandez à un associé de déclarer le point de vente et son jeton.'),
          ),
        const SizedBox(height: AkSpace.s3),
        AsyncView<List<Invoice>>(
          value: invoices,
          onRetry: () => ref.invalidate(invoicesProvider(entity.id)),
          builder: (list) {
            if (list.isEmpty) return const AkEmptyState('Aucune facture pour ce dossier.', icon: Icons.receipt_long_outlined);
            return AkCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, inv) in list.indexed) ...[
                    if (i > 0) Divider(height: 1, color: t.border),
                    AkListRow(
                      key: Key('invoice-${inv.id}'),
                      onTap: () => context.go('/factures/${inv.id}'),
                      title: Row(children: [
                        Flexible(child: Text('${inv.typeLabel}${inv.clientName == null ? '' : ' · ${inv.clientName}'}', overflow: TextOverflow.ellipsis)),
                      ]),
                      subtitle: Text(_subtitle(inv)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (inv.isTest) ...[const TestBadge(), const SizedBox(width: AkSpace.s2)],
                        InvoiceStatusBadge(inv.status),
                        const SizedBox(width: AkSpace.s3),
                        AkAmountText(Fmt.fcfa(inv.total ?? _lineTotal(inv), showZero: true), bold: true),
                      ]),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static int _lineTotal(Invoice inv) => inv.lines.fold(0, (s, l) => s + l.amount);

  static String _subtitle(Invoice inv) {
    final date = Fmt.date(inv.issuedAt ?? inv.createdAt);
    return inv.codeMecef == null ? date : '$date · ${inv.codeMecef}';
  }
}
