import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/consultation_models.dart';
import 'services.dart';

final generalLedgerProvider = FutureProvider.family<List<LedgerLine>, ConsultationParams>((ref, p) => ref.watch(consultationServiceProvider).generalLedger(p));

final trialBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationServiceProvider).trialBalance(p));

final auxiliaryBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationServiceProvider).auxiliaryBalance(p));

final agedBalanceProvider = FutureProvider.family<List<AgedRow>, ConsultationParams>((ref, p) => ref.watch(consultationServiceProvider).agedBalance(p));

final centralizationProvider = FutureProvider.family<List<CentralizationRow>, ConsultationParams>((ref, p) => ref.watch(consultationServiceProvider).centralization(p));
