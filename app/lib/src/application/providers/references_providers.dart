import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/reference_models.dart';
import 'repositories.dart';

final accountsProvider = FutureProvider.family<List<Account>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).accounts(entityId));

final thirdPartiesProvider = FutureProvider.family<List<ThirdParty>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).thirdParties(entityId));

final journalsProvider = FutureProvider.family<List<Journal>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).journals(entityId));

final templatesProvider = FutureProvider.family<List<EntryTemplate>, String>((ref, entityId) => ref.watch(referencesRepositoryProvider).templates(entityId));

final taxRatesProvider = FutureProvider<List<TaxRate>>((ref) => ref.watch(referencesRepositoryProvider).taxRates());
