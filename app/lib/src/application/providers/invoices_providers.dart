import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/invoice_models.dart';
import 'services.dart';

final invoicesProvider = FutureProvider.family<List<Invoice>, String>((ref, entityId) => ref.watch(invoicesServiceProvider).invoices(entityId));

final invoiceProvider = FutureProvider.family<Invoice, String>((ref, id) => ref.watch(invoicesServiceProvider).invoice(id));

final emcfDevicesProvider = FutureProvider.family<List<EmcfDevice>, String>((ref, entityId) => ref.watch(invoicesServiceProvider).devices(entityId));
