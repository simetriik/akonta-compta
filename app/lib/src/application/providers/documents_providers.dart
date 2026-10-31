import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories.dart';
import '../../domain/documents_models.dart';

final documentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entityId) => ref.watch(documentsRepositoryProvider).list(entityId));

final entryDocumentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entryId) => ref.watch(documentsRepositoryProvider).forEntry(entryId));
