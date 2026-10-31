import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/closing_repository.dart';
import '../../domain/repositories/consultation_repository.dart';
import '../../domain/repositories/documents_repository.dart';
import '../../domain/repositories/entities_repository.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../domain/repositories/import_repository.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/repositories/lettering_repository.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../../domain/repositories/references_repository.dart';
import '../../domain/repositories/suggestions_repository.dart';

/// Points d'injection des dépôts : la composition (main.dart) les remplace par les adaptateurs d'infrastructure.
final adminRepositoryProvider = Provider<AdminRepository>((ref) => throw UnimplementedError('adminRepositoryProvider doit être fourni par la composition'));
final closingRepositoryProvider = Provider<ClosingRepository>((ref) => throw UnimplementedError('closingRepositoryProvider doit être fourni par la composition'));
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) => throw UnimplementedError('consultationRepositoryProvider doit être fourni par la composition'));
final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) => throw UnimplementedError('documentsRepositoryProvider doit être fourni par la composition'));
final entitiesRepositoryProvider = Provider<EntitiesRepository>((ref) => throw UnimplementedError('entitiesRepositoryProvider doit être fourni par la composition'));
final entriesRepositoryProvider = Provider<EntriesRepository>((ref) => throw UnimplementedError('entriesRepositoryProvider doit être fourni par la composition'));
final importRepositoryProvider = Provider<ImportRepository>((ref) => throw UnimplementedError('importRepositoryProvider doit être fourni par la composition'));
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => throw UnimplementedError('inventoryRepositoryProvider doit être fourni par la composition'));
final letteringRepositoryProvider = Provider<LetteringRepository>((ref) => throw UnimplementedError('letteringRepositoryProvider doit être fourni par la composition'));
final reconciliationRepositoryProvider = Provider<ReconciliationRepository>((ref) => throw UnimplementedError('reconciliationRepositoryProvider doit être fourni par la composition'));
final referencesRepositoryProvider = Provider<ReferencesRepository>((ref) => throw UnimplementedError('referencesRepositoryProvider doit être fourni par la composition'));
final suggestionsRepositoryProvider = Provider<SuggestionsRepository>((ref) => throw UnimplementedError('suggestionsRepositoryProvider doit être fourni par la composition'));
