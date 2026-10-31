import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/bank_models.dart';
import 'services.dart';

final statementTemplatesProvider = FutureProvider<List<StatementTemplate>>((ref) => ref.watch(reconciliationServiceProvider).templates());
