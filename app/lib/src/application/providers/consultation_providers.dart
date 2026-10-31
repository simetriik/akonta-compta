import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/consultation_models.dart';
import 'repositories.dart';

final generalLedgerProvider = FutureProvider.family<List<LedgerLine>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).generalLedger(p));

final trialBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).trialBalance(p));

final auxiliaryBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).auxiliaryBalance(p));

final agedBalanceProvider = FutureProvider.family<List<AgedRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).agedBalance(p));

final centralizationProvider = FutureProvider.family<List<CentralizationRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).centralization(p));
