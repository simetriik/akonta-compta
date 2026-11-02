import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/invoices_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/invoice_rules.dart';
import '../../core/formatting.dart';
import '../../domain/invoice_models.dart';
import '../widgets/error_display.dart';
import 'invoice_status_badge.dart';

/// Ligne d'article en cours de saisie (champs texte conservés entre les rafraîchissements).
class _LineFields {
  _LineFields({String name = '', String quantity = '1', String price = '', this.taxGroup = 'B'})
      : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity),
        price = TextEditingController(text: price);

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;
  String taxGroup;

  InvoiceLine toLine() => InvoiceLine(
        name: name.text,
        price: Fmt.parseAmount(price.text) ?? 0,
        quantity: Fmt.parseDecimal(quantity.text) ?? 0,
        taxGroup: taxGroup,
      );

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}

/// Brouillon de facture (vente ou avoir) : client, articles, AIB, paiement, aperçu des totaux, enregistrement et émission.
class InvoiceEditor extends ConsumerStatefulWidget {
  const InvoiceEditor({super.key, required this.entityId, this.invoice});

  final String entityId;
  final Invoice? invoice;

  @override
  ConsumerState<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends ConsumerState<InvoiceEditor> {
  final _operator = TextEditingController();
  final _clientName = TextEditingController();
  final _clientIfu = TextEditingController();
  final _clientContact = TextEditingController();
  final _clientAddress = TextEditingController();
  final _message = TextEditingController();
  final List<_LineFields> _lines = [];
  String? _deviceId;
  String? _aib;
  String _payment = 'ESPECES';
  bool _busy = false;
  List<String> _problems = const [];
  String? _issueMessage;

  Invoice? get _invoice => widget.invoice;
  bool get _isCredit => _invoice?.isCreditNote ?? false;

  @override
  void initState() {
    super.initState();
    final inv = _invoice;
    if (inv != null) {
      _deviceId = inv.deviceId;
      _aib = inv.aib;
      _operator.text = inv.operatorName;
      _clientName.text = inv.clientName ?? '';
      _clientIfu.text = inv.clientIfu ?? '';
      _clientContact.text = inv.clientContact ?? '';
      _clientAddress.text = inv.clientAddress ?? '';
      _message.text = inv.commercialMessage ?? '';
      if (inv.payments.isNotEmpty) _payment = inv.payments.first.name;
      for (final l in inv.lines) {
        _lines.add(_LineFields(name: l.name, quantity: '${l.quantity}'.replaceAll(RegExp(r'\.0+$'), '').replaceAll('.', ','), price: '${l.price}', taxGroup: l.taxGroup));
      }
    } else {
      _lines.add(_LineFields());
      ref.read(currentProfileProvider.future).then((p) {
        if (mounted && _operator.text.isEmpty) _operator.text = p?.fullName ?? '';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_operator, _clientName, _clientIfu, _clientContact, _clientAddress, _message]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  List<InvoiceLine> get _currentLines => [for (final l in _lines) l.toLine()];

  String? _nullIfEmpty(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  InvoiceDraft _draft() {
    final lines = _currentLines;
    final totals = previewTotals(lines);
    return InvoiceDraft(
      id: _invoice?.id,
      entityId: widget.entityId,
      deviceId: _deviceId ?? '',
      type: _invoice?.type ?? 'FV',
      operatorName: _operator.text,
      lines: lines,
      payments: totals.total > 0 ? [InvoicePayment(name: _payment, amount: totals.total)] : const [],
      aib: _aib,
      clientIfu: _nullIfEmpty(_clientIfu),
      clientName: _nullIfEmpty(_clientName),
      clientContact: _nullIfEmpty(_clientContact),
      clientAddress: _nullIfEmpty(_clientAddress),
      commercialMessage: _nullIfEmpty(_message),
      originalInvoiceId: _invoice?.originalInvoiceId,
      reference: _invoice?.reference,
    );
  }

  /// Enregistre le brouillon ; renvoie son identifiant, ou null si le contenu est invalide ou l'enregistrement a échoué.
  Future<String?> _save({bool forIssue = false}) async {
    final draft = _draft();
    final problems = [if (draft.deviceId.isEmpty) 'Choisissez l\'e-MCF (point de vente) qui émet la facture.', ...draftProblems(draft, forIssue: forIssue)];
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return null;
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final id = await ref.read(invoicesServiceProvider).saveDraft(profile!.cabinetId, draft);
      ref.invalidate(invoicesProvider(widget.entityId));
      ref.invalidate(invoiceProvider(id));
      return id;
    } catch (e) {
      if (mounted) showError(context, e, action: 'L\'enregistrement de la facture');
      return null;
    }
  }

  Future<void> _saveOnly() async {
    setState(() => _busy = true);
    final id = await _save();
    if (!mounted) return;
    setState(() => _busy = false);
    if (id != null) {
      showAkToast(context, 'Brouillon enregistré.');
      if (_invoice == null) context.go('/factures/$id');
    }
  }

  Future<void> _issue() async {
    setState(() => _busy = true);
    final id = await _save(forIssue: true);
    if (id == null || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    // Le bouton ne tourne pas pendant la question : l'utilisateur n'a encore rien confirmé.
    setState(() => _busy = false);
    final totals = previewTotals(_currentLines);
    final confirmed = await showAkConfirm(
      context,
      title: 'Émettre la facture ?',
      message: 'La facture de ${Fmt.fcfa(totals.total, showZero: true)} FCFA sera envoyée à la DGI. Une fois normalisée, elle ne pourra plus être modifiée : une erreur se corrige par une facture d\'avoir.',
      confirmLabel: 'Émettre',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(invoicesServiceProvider).issue(id);
      ref.invalidate(invoicesProvider(widget.entityId));
      ref.invalidate(invoiceProvider(id));
      if (!mounted) return;
      if (result.state == IssueState.draft) {
        setState(() => _issueMessage = [result.message ?? 'La DGI n\'a pas pu émettre la facture.', ...result.gaps].join('\n'));
      } else if (_invoice == null || result.state != IssueState.draft) {
        context.go('/factures/$id');
      }
    } catch (e) {
      if (mounted) showError(context, e, action: 'L\'émission de la facture');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final inv = _invoice;
    if (inv == null) return;
    final ok = await showAkConfirm(context, title: 'Supprimer ce brouillon ?', message: 'Le brouillon sera supprimé. Une facture émise ne peut jamais être supprimée.', confirmLabel: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(invoicesServiceProvider).deleteDraft(inv.id);
      ref.invalidate(invoicesProvider(widget.entityId));
      if (mounted) context.go('/factures');
    } catch (e) {
      if (mounted) showError(context, e, action: 'La suppression du brouillon');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final devices = ref.watch(emcfDevicesProvider(widget.entityId)).value ?? const [];
    final active = devices.where((d) => d.isActive).toList();
    if (_deviceId == null && active.length == 1) _deviceId = active.first.id;
    final totals = previewTotals(_currentLines);
    final lastError = _issueMessage ?? _invoice?.lastError;
    final testMode = devices.where((d) => d.id == _deviceId).any((d) => d.isTest);

    return AkPage(
      children: [
        AkPageHead(
          title: _isCredit ? 'Facture d\'avoir' : (_invoice == null ? 'Nouvelle facture' : 'Brouillon de facture'),
          actions: [if (testMode) const TestBadge(), AkButton.ghost('Retour à la liste', icon: Icons.arrow_back, onPressed: () => context.go('/factures'))],
        ),
        const SizedBox(height: AkSpace.s4),
        if (_isCredit)
          AkBanner(kind: AkBannerKind.info, child: Text('Avoir de la facture dont le code MECeF/DGI est ${_invoice?.reference}. Ajustez les quantités : un avoir ne peut pas dépasser le montant de la facture d\'origine.')),
        if (lastError != null && lastError.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s2),
          AkBanner(kind: AkBannerKind.danger, child: Text(lastError, key: const Key('issue-error'))),
        ],
        if (_problems.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s2),
          AkBanner(kind: AkBannerKind.warning, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final p in _problems) Text(p)])),
        ],
        const SizedBox(height: AkSpace.s4),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AkSectionTitle('Émetteur'),
            const SizedBox(height: AkSpace.s2),
            Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s3, children: [
              SizedBox(
                width: 280,
                child: AkDropdown<String>(
                  key: const Key('invoice-device'),
                  label: 'e-MCF (point de vente)',
                  required: true,
                  value: _deviceId,
                  items: [for (final d in active) AkOption(d.id, '${d.label} · ${d.nim}${d.isTest ? ' (test)' : ''}')],
                  onChanged: _invoice == null ? (v) => setState(() => _deviceId = v) : null,
                ),
              ),
              SizedBox(width: 220, child: AkTextField(key: const Key('invoice-operator'), controller: _operator, label: 'Opérateur', required: true)),
            ]),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AkSectionTitle('Client (facultatif)'),
            const SizedBox(height: AkSpace.s2),
            Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s3, children: [
              SizedBox(width: 260, child: AkTextField(key: const Key('client-name'), controller: _clientName, label: 'Nom')),
              SizedBox(width: 200, child: AkTextField(key: const Key('client-ifu'), controller: _clientIfu, label: 'IFU (13 caractères)', maxLength: 13, mono: true)),
              SizedBox(width: 200, child: AkTextField(controller: _clientContact, label: 'Contact')),
              SizedBox(width: 280, child: AkTextField(controller: _clientAddress, label: 'Adresse')),
            ]),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AkSectionTitle('Articles', trailing: AkButton.secondary('Ajouter', key: const Key('add-line'), dense: true, icon: Icons.add, onPressed: () => setState(() => _lines.add(_LineFields())))),
            const SizedBox(height: AkSpace.s2),
            for (final (i, l) in _lines.indexed) _lineRow(i, l, t),
            Text('Les prix saisis sont TTC. Groupe A : exonéré. Groupe B : taxable (TVA 18 %).', style: AkText.caption.copyWith(color: t.textMuted)),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Wrap(spacing: AkSpace.s4, runSpacing: AkSpace.s3, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(
              width: 220,
              child: AkDropdown<String?>(
                key: const Key('invoice-aib'),
                label: 'AIB',
                value: _aib,
                items: const [AkOption(null, 'Aucun'), AkOption('A', 'AIB 1 %'), AkOption('B', 'AIB 5 %')],
                onChanged: (v) => setState(() => _aib = v),
              ),
            ),
            SizedBox(
              width: 220,
              child: AkDropdown<String>(
                key: const Key('invoice-payment'),
                label: 'Mode de paiement',
                value: _payment,
                items: [for (final e in paymentTypeLabels.entries) AkOption(e.key, e.value)],
                onChanged: (v) => setState(() => _payment = v ?? 'ESPECES'),
              ),
            ),
            SizedBox(width: 360, child: AkTextField(controller: _message, label: 'Message commercial (facultatif)', maxLines: 2)),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        _totalsCard(totals, t),
        const SizedBox(height: AkSpace.s4),
        Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, alignment: WrapAlignment.end, children: [
          if (_invoice != null) AkButton.dangerOutline('Supprimer', key: const Key('delete-draft'), icon: Icons.delete_outline, onPressed: _busy ? null : _delete),
          AkButton.secondary('Enregistrer le brouillon', key: const Key('save-draft'), icon: Icons.save_outlined, onPressed: _busy ? null : _saveOnly),
          AkButton.primary('Émettre la facture', key: const Key('issue-invoice'), icon: Icons.verified_outlined, loading: _busy, onPressed: _busy ? null : _issue),
        ]),
      ],
    );
  }

  Widget _lineRow(int i, _LineFields l, AkTokens t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(width: 260, child: AkTextField(key: Key('line-name-$i'), controller: l.name, label: i == 0 ? 'Désignation' : null, hint: 'Désignation', onChanged: (_) => setState(() {}))),
        SizedBox(
          width: 90,
          child: AkTextField(key: Key('line-qty-$i'), controller: l.quantity, label: i == 0 ? 'Quantité' : null, textAlign: TextAlign.end, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
        ),
        SizedBox(
          width: 130,
          child: AkTextField(key: Key('line-price-$i'), controller: l.price, label: i == 0 ? 'Prix unitaire TTC' : null, textAlign: TextAlign.end, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {})),
        ),
        SizedBox(
          width: 140,
          child: AkDropdown<String>(
            key: Key('line-group-$i'),
            label: i == 0 ? 'Groupe' : null,
            value: l.taxGroup,
            items: const [AkOption('B', 'B · Taxable'), AkOption('A', 'A · Exonéré')],
            onChanged: (v) => setState(() => l.taxGroup = v ?? 'B'),
          ),
        ),
        SizedBox(width: 110, child: Padding(padding: const EdgeInsets.only(bottom: AkSpace.s2), child: Align(alignment: Alignment.centerRight, child: AkAmountText(Fmt.fcfa(l.toLine().amount, showZero: true))))),
        AkIconButton(
          icon: Icons.close,
          tooltip: 'Retirer l\'article',
          onPressed: _lines.length <= 1 ? null : () => setState(() => _lines.removeAt(i).dispose()),
        ),
      ]),
    );
  }

  Widget _totalsCard(InvoiceTotalsPreview totals, AkTokens t) {
    Widget row(String label, int amount, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: strong ? AkText.bodyStrong : AkText.body)),
            AkAmountText(Fmt.fcfa(amount, showZero: true), bold: strong),
          ]),
        );
    final aib = (totals.total * aibRate(_aib) / 100).round();
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AkCard(
          key: const Key('invoice-totals'),
          child: Column(children: [
            row('Total groupe A (exonéré)', totals.totalA),
            row('Total groupe B (taxable)', totals.totalB),
            row('dont montant HT', totals.htB),
            row('dont TVA ($defaultVatRate %)', totals.vatB),
            if (_aib != null) row('AIB (${aibRate(_aib)} %), indicatif', aib),
            const Divider(),
            row('Total TTC', totals.total, strong: true),
            Text('Aperçu : la DGI calcule les montants définitifs à l\'émission.', style: AkText.caption.copyWith(color: t.textMuted)),
          ]),
        ),
      ),
    );
  }
}
