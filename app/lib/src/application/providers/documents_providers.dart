import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/documents_models.dart';
import 'services.dart';

final documentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entityId) => ref.watch(documentsServiceProvider).list(entityId));

final entryDocumentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entryId) => ref.watch(documentsServiceProvider).forEntry(entryId));
