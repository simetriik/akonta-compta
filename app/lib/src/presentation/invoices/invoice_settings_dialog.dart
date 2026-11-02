import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/invoice_rules.dart';
import '../../domain/invoice_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/error_display.dart';

Future<void> showInvoiceSettingsDialog(BuildContext context, EntitySummary entity) =>
    showDialog<void>(context: context, builder: (_) => InvoiceSettingsDialog(entity: entity));

/// Comptes de facturation du dossier : où comptabiliser le client, les ventes, la TVA et l'AIB d'une facture normalisée (D-043).
class InvoiceSettingsDialog extends ConsumerStatefulWidget {
  const InvoiceSettingsDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<InvoiceSettingsDialog> createState() => _InvoiceSettingsDialogState();
}

class _InvoiceSettingsDialogState extends ConsumerState<InvoiceSettingsDialog> {
  String? _client, _exempt, _taxable, _vat, _aib;
  bool _initialized = false;
  bool _busy = false;

  /// Valeurs de départ : paramètres en vigueur, sinon comptes usuels du SYSCOHADA (4111, 7011, 4431) s'ils existent dans le plan.
  void _init(List<Account> all, InvoiceAccountSettings? current) {
    if (_initialized) return;
    _initialized = true;
    if (current != null) {
      _client = current.clientAccountId;
      _exempt = current.salesExemptAccountId;
      _taxable = current.salesTaxableAccountId;
      _vat = current.vatAccountId;
      _aib = current.aibAccountId;
      return;
    }
    _client = InvoiceAccounts.byPrefix(InvoiceAccounts.clients(all), '4111')?.id;
    _exempt = _taxable = InvoiceAccounts.byPrefix(InvoiceAccounts.sales(all), '7011')?.id;
    _vat = InvoiceAccounts.byPrefix(InvoiceAccounts.vat(all), '4431')?.id;
  }

  Future<void> _save(InvoiceAccountSettings? current) async {
    if (_client == null || _exempt == null || _taxable == null || _vat == null) {
      showAkToast(context, 'Choisissez le compte client, les deux comptes de ventes et le compte de TVA.', kind: AkToastKind.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      await ref.read(invoicesServiceProvider).saveAccountSettings(
            profile!.cabinetId,
            InvoiceAccountSettings(
              entityId: widget.entity.id,
              validFrom: current?.validFrom ?? DateTime(2000, 1, 1),
              clientAccountId: _client!,
              salesExemptAccountId: _exempt!,
              salesTaxableAccountId: _taxable!,
              vatAccountId: _vat!,
              aibAccountId: _aib,
            ),
          );
      ref.invalidate(invoiceAccountSettingsProvider(widget.entity.id));
      if (mounted) {
        showAkToast(context, 'Comptes de facturation enregistrés.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e, action: 'L\'enregistrement des comptes de facturation');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Account? _find(List<Account> all, String? id) => id == null ? null : all.where((a) => a.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entity.id));
    final settings = ref.watch(invoiceAccountSettingsProvider(widget.entity.id));
    return AkDialog(
      title: 'Comptabilisation des factures · ${widget.entity.name}',
      size: AkDialogSize.l,
      content: accounts.when(
        loading: () => const AkLoading(),
        error: (e, _) => Text(errorText(e)),
        data: (all) => settings.when(
          loading: () => const AkLoading(),
          error: (e, _) => Text(errorText(e)),
          data: (current) {
            _init(all, current);
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Une facture confirmée par la DGI génère une écriture de vente en brouillard avec ces comptes ; le comptable la valide.'),
                const SizedBox(height: AkSpace.s3),
                AkAccountField(key: const Key('acc-client'), label: 'Client (TTC)', required: true, accounts: InvoiceAccounts.clients(all), selected: _find(all, _client), onSelected: (a) => setState(() => _client = a.id)),
                const SizedBox(height: AkSpace.s2),
                AkAccountField(key: const Key('acc-exempt'), label: 'Ventes exonérées (groupe A)', required: true, accounts: InvoiceAccounts.sales(all), selected: _find(all, _exempt), onSelected: (a) => setState(() => _exempt = a.id)),
                const SizedBox(height: AkSpace.s2),
                AkAccountField(key: const Key('acc-taxable'), label: 'Ventes taxables, hors taxe (groupe B)', required: true, accounts: InvoiceAccounts.sales(all), selected: _find(all, _taxable), onSelected: (a) => setState(() => _taxable = a.id)),
                const SizedBox(height: AkSpace.s2),
                AkAccountField(key: const Key('acc-vat'), label: 'TVA facturée', required: true, accounts: InvoiceAccounts.vat(all), selected: _find(all, _vat), onSelected: (a) => setState(() => _vat = a.id)),
                const SizedBox(height: AkSpace.s2),
                AkAccountField(
                  key: const Key('acc-aib'),
                  label: 'AIB (obligatoire seulement pour une facture avec AIB)',
                  helper: 'Le plan SYSCOHADA n\'a pas de compte dédié : choisissez celui que retient le cabinet (par exemple 4428).',
                  accounts: InvoiceAccounts.aib(all),
                  selected: _find(all, _aib),
                  onSelected: (a) => setState(() => _aib = a.id),
                  onCleared: () => setState(() => _aib = null),
                ),
              ]),
            );
          },
        ),
      ),
      actions: [
        AkButton.ghost('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Enregistrer', key: const Key('save-invoice-settings'), loading: _busy, onPressed: _busy ? null : () => _save(settings.value)),
      ],
    );
  }
}
