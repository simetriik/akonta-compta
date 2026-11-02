import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/invoices_providers.dart';
import '../../domain/invoice_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import 'invoice_editor.dart';
import 'invoice_view.dart';

/// Une facture : éditeur tant qu'elle est en brouillon, vue en lecture (avec QR code) dès qu'elle est émise.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = invoiceId;
    if (id == null) return RequireEntity(builder: (entity) => InvoiceEditor(entityId: entity.id));
    return AsyncView<Invoice>(
      value: ref.watch(invoiceProvider(id)),
      onRetry: () => ref.invalidate(invoiceProvider(id)),
      builder: (inv) => inv.isEditable ? InvoiceEditor(key: ValueKey(inv.id), entityId: inv.entityId, invoice: inv) : InvoiceView(invoice: inv),
    );
  }
}
