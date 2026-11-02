import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/invoice_rules.dart';
import '../../core/formatting.dart';
import '../../domain/invoice_models.dart';
import '../../domain/models.dart';
import '../widgets/error_display.dart';
import '../widgets/save_export.dart';
import 'invoice_status_badge.dart';

/// Facture émise (normalisée, en cours ou annulée) : lecture seule, éléments de sécurité avec QR code, PDF, avoir.
class InvoiceView extends ConsumerStatefulWidget {
  const InvoiceView({super.key, required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends ConsumerState<InvoiceView> {
  bool _busy = false;
  String? _message;

  Invoice get inv => widget.invoice;

  Future<void> _run(Future<void> Function() action, String label) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e, action: label);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdf() => _run(() async {
        final (name, bytes) = await ref.read(invoicesServiceProvider).pdf(inv.id);
        final where = await saveExportedFile(dialogTitle: 'Enregistrer la facture', fileName: name, bytes: bytes);
        if (where != null && mounted) showAkToast(context, 'Facture enregistrée.');
      }, 'Le téléchargement de la facture');

  Future<void> _creditNote() async {
    final ok = await showAkConfirm(context,
        title: 'Créer un avoir ?', message: 'Un brouillon de facture d\'avoir sera créé avec les articles de cette facture. Ajustez les quantités puis émettez-le.', confirmLabel: 'Créer l\'avoir');
    if (!ok || !mounted) return;
    await _run(() async {
      final id = await ref.read(invoicesServiceProvider).createCreditNote(inv.id);
      ref.invalidate(invoicesProvider(inv.entityId));
      if (mounted) context.go('/factures/$id');
    }, 'La création de l\'avoir');
  }

  Future<void> _pendingAction(bool resume) => _run(() async {
        final service = ref.read(invoicesServiceProvider);
        final result = resume ? await service.resume(inv.id) : await service.cancelPending(inv.id);
        ref.invalidate(invoiceProvider(inv.id));
        ref.invalidate(invoicesProvider(inv.entityId));
        if (mounted) setState(() => _message = result.state == IssueState.confirmed ? null : result.message);
      }, resume ? 'La reprise de la facture' : 'L\'annulation de la facture');

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canIssue = perms.has('invoices.issue', entityId: inv.entityId);
    final shown = inv.total ?? inv.lines.fold<int>(0, (s, l) => s + l.amount);
    final totals = previewTotals(inv.lines);

    return AkPage(
      children: [
        AkPageHead(
          title: inv.typeLabel,
          actions: [if (inv.isTest) const TestBadge(), InvoiceStatusBadge(inv.status), AkButton.ghost('Retour à la liste', icon: Icons.arrow_back, onPressed: () => context.go('/factures'))],
        ),
        const SizedBox(height: AkSpace.s4),
        if (inv.isTest)
          const AkBanner(kind: AkBannerKind.warning, child: Text('Facture émise sur l\'environnement de test de la DGI : elle n\'a aucune valeur fiscale ni comptable.')),
        if (inv.status == InvoiceStatus.pending) ...[
          const SizedBox(height: AkSpace.s2),
          AkBanner(
            kind: AkBannerKind.warning,
            child: Text('Cette facture est en cours d\'émission (coupure avant la confirmation de la DGI). La demande expire deux minutes après son envoi.'
                '${_message == null ? '' : '\n$_message'}'),
          ),
        ],
        if (inv.status == InvoiceStatus.cancelled) ...[
          const SizedBox(height: AkSpace.s2),
          AkBanner(kind: AkBannerKind.danger, child: Text(inv.lastError ?? 'Cette facture a été annulée avant sa confirmation.')),
        ],
        if (inv.isCreditNote && inv.reference != null) ...[
          const SizedBox(height: AkSpace.s2),
          AkBanner(kind: AkBannerKind.info, child: Text('Avoir de la facture dont le code MECeF/DGI commence par ${inv.reference}.')),
        ],
        const SizedBox(height: AkSpace.s4),
        AkCard(
          child: Wrap(spacing: AkSpace.s6, runSpacing: AkSpace.s3, children: [
            _fact('Client', [inv.clientName, if (inv.clientIfu != null) 'IFU ${inv.clientIfu}', inv.clientAddress, inv.clientContact].whereType<String>().join('\n'), t),
            _fact('Opérateur', inv.operatorName, t),
            _fact('Date', Fmt.date(inv.issuedAt ?? inv.createdAt), t),
            if (inv.aib != null) _fact('AIB', '${aibRate(inv.aib)} %', t),
            if (inv.payments.isNotEmpty) _fact('Paiement', inv.payments.map((p) => paymentTypeLabels[p.name] ?? p.name).join(', '), t),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, l) in inv.lines.indexed) ...[
              if (i > 0) Divider(height: 1, color: t.border),
              AkListRow(
                title: Text(l.name),
                subtitle: Text('${Fmt.fcfa(l.price)} × ${'${l.quantity}'.replaceAll(RegExp(r'\.0+$'), '').replaceAll('.', ',')} · groupe ${l.taxGroup} (${l.taxGroup == 'A' ? 'exonéré' : 'taxable'})'),
                trailing: AkAmountText(Fmt.fcfa(l.amount, showZero: true)),
              ),
            ],
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.all(AkSpace.s4),
              child: Column(children: [
                _amountRow('Montant HT groupe B', totals.htB),
                _amountRow('TVA groupe B', totals.vatB),
                _amountRow('Total', shown, strong: true),
              ]),
            ),
          ]),
        ),
        if (inv.status == InvoiceStatus.confirmed) ...[
          const SizedBox(height: AkSpace.s3),
          _security(t),
        ],
        const SizedBox(height: AkSpace.s4),
        Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, alignment: WrapAlignment.end, children: [
          if (inv.status == InvoiceStatus.pending && canIssue) ...[
            AkButton.dangerOutline('Annuler la demande', key: const Key('cancel-pending'), onPressed: _busy ? null : () => _pendingAction(false)),
            AkButton.primary('Reprendre l\'émission', key: const Key('resume-pending'), loading: _busy, onPressed: _busy ? null : () => _pendingAction(true)),
          ],
          if (inv.status == InvoiceStatus.confirmed) ...[
            if (canIssue && inv.type == 'FV') AkButton.secondary('Créer un avoir', key: const Key('credit-note'), icon: Icons.undo, onPressed: _busy ? null : _creditNote),
            AkButton.primary('Télécharger le PDF', key: const Key('invoice-pdf'), icon: Icons.picture_as_pdf_outlined, loading: _busy, onPressed: _busy ? null : _pdf),
          ],
        ]),
      ],
    );
  }

  Widget _security(AkTokens t) {
    return AkCard(
      key: const Key('security-elements'),
      child: Wrap(spacing: AkSpace.s6, runSpacing: AkSpace.s3, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(AkSpace.s2),
          child: QrImageView(key: const Key('invoice-qr'), data: inv.qrCode ?? '', size: 150, backgroundColor: Colors.white),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _fact('Code MECeF/DGI', inv.codeMecef ?? '', t, mono: true),
          const SizedBox(height: AkSpace.s2),
          _fact('NIM', inv.dgiNim ?? '', t, mono: true),
          const SizedBox(height: AkSpace.s2),
          _fact('Compteurs', inv.counters ?? '', t, mono: true),
          const SizedBox(height: AkSpace.s2),
          _fact('Date et heure', inv.dgiDatetime ?? '', t, mono: true),
        ]),
      ]),
    );
  }

  Widget _fact(String label, String value, AkTokens t, {bool mono = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AkText.caption.copyWith(color: t.textMuted)),
          SelectableText(value.isEmpty ? '—' : value, style: (mono ? AkText.code : AkText.body).copyWith(color: t.text)),
        ],
      );

  Widget _amountRow(String label, int amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? AkText.bodyStrong : AkText.body)),
          AkAmountText(Fmt.fcfa(amount, showZero: true), bold: strong),
        ]),
      );
}
