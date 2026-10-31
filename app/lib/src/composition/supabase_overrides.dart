import 'package:flutter_riverpod/misc.dart' show Override;
import '../application/providers/repositories.dart';
import '../data/supabase_providers.dart';
import '../infrastructure/supabase/supabase_admin_repository.dart';
import '../infrastructure/supabase/supabase_closing_repository.dart';
import '../infrastructure/supabase/supabase_consultation_repository.dart';
import '../infrastructure/supabase/supabase_documents_repository.dart';
import '../infrastructure/supabase/supabase_entities_repository.dart';
import '../infrastructure/supabase/supabase_entries_repository.dart';
import '../infrastructure/supabase/supabase_import_repository.dart';
import '../infrastructure/supabase/supabase_inventory_repository.dart';
import '../infrastructure/supabase/supabase_lettering_repository.dart';
import '../infrastructure/supabase/supabase_reconciliation_repository.dart';
import '../infrastructure/supabase/supabase_references_repository.dart';
import '../infrastructure/supabase/supabase_suggestions_repository.dart';

/// Branche chaque port sur son adaptateur Supabase (production et recette).
List<Override> supabaseOverrides() => [
  adminRepositoryProvider.overrideWith((ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider))),
  closingRepositoryProvider.overrideWith((ref) => SupabaseClosingRepository(ref.watch(supabaseClientProvider))),
  consultationRepositoryProvider.overrideWith((ref) => SupabaseConsultationRepository(ref.watch(supabaseClientProvider))),
  documentsRepositoryProvider.overrideWith((ref) => SupabaseDocumentsRepository(ref.watch(supabaseClientProvider))),
  entitiesRepositoryProvider.overrideWith((ref) => SupabaseEntitiesRepository(ref.watch(supabaseClientProvider))),
  entriesRepositoryProvider.overrideWith((ref) => SupabaseEntriesRepository(ref.watch(supabaseClientProvider))),
  importRepositoryProvider.overrideWith((ref) => SupabaseImportRepository(ref.watch(supabaseClientProvider))),
  inventoryRepositoryProvider.overrideWith((ref) => SupabaseInventoryRepository(ref.watch(supabaseClientProvider))),
  letteringRepositoryProvider.overrideWith((ref) => SupabaseLetteringRepository(ref.watch(supabaseClientProvider))),
  reconciliationRepositoryProvider.overrideWith((ref) => SupabaseReconciliationRepository(ref.watch(supabaseClientProvider))),
  referencesRepositoryProvider.overrideWith((ref) => SupabaseReferencesRepository(ref.watch(supabaseClientProvider))),
  suggestionsRepositoryProvider.overrideWith((ref) => SupabaseSuggestionsRepository(ref.watch(supabaseClientProvider))),
];
