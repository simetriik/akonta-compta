import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entry_models.dart';
import 'supabase_providers.dart';

class EntryFilter {
  const EntryFilter({this.journalId, this.month, this.status, this.reviewStatus, this.search, this.toReviewOnly = false});

  final String? journalId;
  final DateTime? month; // premier jour du mois
  final String? status;
  final String? reviewStatus;
  final String? search;
  final bool toReviewOnly;

  EntryFilter copyWith({String? journalId, DateTime? month, String? status, String? reviewStatus, String? search, bool? toReviewOnly, bool clearJournal = false, bool clearMonth = false, bool clearStatus = false}) =>
      EntryFilter(
        journalId: clearJournal ? null : (journalId ?? this.journalId),
        month: clearMonth ? null : (month ?? this.month),
        status: clearStatus ? null : (status ?? this.status),
        reviewStatus: reviewStatus ?? this.reviewStatus,
        search: search ?? this.search,
        toReviewOnly: toReviewOnly ?? this.toReviewOnly,
      );
}

/// Module 4 : brouillards, validation, revue, contre-passation, recherche.
class EntriesRepository {
  EntriesRepository(this._client);

  final SupabaseClient _client;

  static const _select = 'id, entity_id, journal_id, entry_date, number, reference, label, status, review_status, review_comment, is_generated, reversal_of, reversed_by, created_by, '
      'journals(code), entry_lines(id, line_no, account_id, third_party_id, label, debit, credit, currency_code, amount_currency, exchange_rate, letter_code, accounts(code, label), third_parties(code))';

  Future<List<EntryModel>> list(String entityId, EntryFilter f, {String? fiscalYearId, int limit = 300}) async {
    var q = _client.from('entries').select(_select).eq('entity_id', entityId);
    if (fiscalYearId != null) q = q.eq('fiscal_year_id', fiscalYearId);   // un dossier = une entité et un exercice
    if (f.journalId != null) q = q.eq('journal_id', f.journalId!);
    if (f.month != null) {
      final start = DateTime(f.month!.year, f.month!.month, 1);
      final end = DateTime(f.month!.year, f.month!.month + 1, 0);
      q = q.gte('entry_date', _d(start)).lte('entry_date', _d(end));
    }
    if (f.status != null) q = q.eq('status', f.status!);
    if (f.reviewStatus != null) q = q.eq('review_status', f.reviewStatus!);
    if (f.toReviewOnly) q = q.eq('status', 'validated').eq('review_status', 'not_reviewed');
    final s = f.search?.trim();
    if (s != null && s.isNotEmpty) {
      final n = int.tryParse(s.replaceAll(RegExp(r'[\s  .]'), ''));
      if (n != null) {
        q = q.or('number.eq.$n,label.ilike.%$s%');
      } else {
        q = q.ilike('label', '%$s%');
      }
    }
    final rows = await q.order('entry_date', ascending: false).order('number', ascending: false, nullsFirst: true).limit(limit);
    var entries = rows.map(EntryModel.fromJson).toList();
    // Recherche par montant, compte ou tiers : filtre côté client sur les lignes chargées
    if (s != null && s.isNotEmpty) {
      final n = int.tryParse(s.replaceAll(RegExp(r'[\s  .]'), ''));
      final upper = s.toUpperCase();
      entries = entries.where((e) {
        if (e.label.toLowerCase().contains(s.toLowerCase())) return true;
        if (n != null && (e.number == n || e.lines.any((l) => l.debit == n || l.credit == n))) return true;
        return e.lines.any((l) => l.accountCode.startsWith(s) || (l.thirdPartyCode ?? '').toUpperCase().contains(upper));
      }).toList();
    }
    return entries;
  }

  Future<EntryModel> get(String id) async => EntryModel.fromJson(await _client.from('entries').select(_select).eq('id', id).single());

  Future<String> saveDraft(String cabinetId, String entityId, EntryDraft d) async {
    final header = {
      'cabinet_id': cabinetId,
      'entity_id': entityId,
      'journal_id': d.journalId,
      'entry_date': _d(d.entryDate),
      'reference': d.reference.trim().isEmpty ? null : d.reference.trim(),
      'label': d.label.trim(),
    };
    String id;
    if (d.id == null) {
      // fiscal_year_id et period_id sont déduits de la date par le déclencheur ; valeurs de remplissage requises par NOT NULL
      final fy = await _client.from('fiscal_years').select('id, periods(id, start_date, end_date)').eq('entity_id', entityId).lte('start_date', _d(d.entryDate)).gte('end_date', _d(d.entryDate)).maybeSingle();
      if (fy == null) throw Exception('Aucun exercice ne couvre la date ${_d(d.entryDate)}');
      final period = (fy['periods'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['start_date'].compareTo(_d(d.entryDate)) <= 0 && p['end_date'].compareTo(_d(d.entryDate)) >= 0);
      final row = await _client.from('entries').insert({...header, 'fiscal_year_id': fy['id'], 'period_id': period['id']}).select('id').single();
      id = row['id'] as String;
    } else {
      id = d.id!;
      await _client.from('entries').update(header).eq('id', id);
      await _client.from('entry_lines').delete().eq('entry_id', id);
    }
    final lines = d.nonEmptyLines;
    await _client.from('entry_lines').insert([for (var i = 0; i < lines.length; i++) {'cabinet_id': cabinetId, 'entity_id': entityId, 'entry_id': id, ...lines[i].toJson(i + 1)}]);
    return id;
  }

  Future<void> deleteDraft(String id) => _client.from('entries').delete().eq('id', id);

  Future<int> validate(String id) async => ((await _client.rpc('validate_entry', params: {'p_entry': id})) as num).toInt();

  Future<void> validateMany(List<String> ids) => _client.rpc('validate_entries', params: {'p_entries': ids});

  Future<String> reverse(String id, {required String reason, DateTime? date}) async =>
      (await _client.rpc('reverse_entry', params: {'p_entry': id, 'p_reason': reason, 'p_date': _d(date ?? DateTime.now())})) as String;

  Future<void> review(String id, {required String status, String? comment}) =>
      _client.rpc('review_entry', params: {'p_entry': id, 'p_status': status, 'p_comment': comment});

  Future<List<Map<String, dynamic>>> notifications() async =>
      (await _client.from('notifications').select().isFilter('read_at', null).order('created_at', ascending: false).limit(50)).cast<Map<String, dynamic>>();

  Future<void> markRead(int id) => _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);
}

final entriesRepositoryProvider = Provider<EntriesRepository>((ref) => EntriesRepository(ref.watch(supabaseClientProvider)));

class EntryFilterNotifier extends Notifier<EntryFilter> {
  @override
  EntryFilter build() => EntryFilter(month: DateTime(DateTime.now().year, DateTime.now().month, 1));

  void set(EntryFilter f) => state = f;
}

final entryFilterProvider = NotifierProvider<EntryFilterNotifier, EntryFilter>(EntryFilterNotifier.new);

final entriesListProvider = FutureProvider.family<List<EntryModel>, String>((ref, entityId) {
  final filter = ref.watch(entryFilterProvider);
  final current = ref.watch(currentEntityProvider);
  final fiscalYearId = current?.id == entityId ? current?.fiscalYearId : null;
  return ref.watch(entriesRepositoryProvider).list(entityId, filter, fiscalYearId: fiscalYearId);
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(entriesRepositoryProvider).notifications();
});
