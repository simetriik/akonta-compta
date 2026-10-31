import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/reference_models.dart';
import 'services.dart';

final accountsProvider = FutureProvider.family<List<Account>, String>((ref, entityId) => ref.watch(referencesServiceProvider).accounts(entityId));

final thirdPartiesProvider = FutureProvider.family<List<ThirdParty>, String>((ref, entityId) => ref.watch(referencesServiceProvider).thirdParties(entityId));

final journalsProvider = FutureProvider.family<List<Journal>, String>((ref, entityId) => ref.watch(referencesServiceProvider).journals(entityId));

final templatesProvider = FutureProvider.family<List<EntryTemplate>, String>((ref, entityId) => ref.watch(referencesServiceProvider).templates(entityId));

final taxRatesProvider = FutureProvider<List<TaxRate>>((ref) => ref.watch(referencesServiceProvider).taxRates());
