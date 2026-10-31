import '../../core/errors/errors.dart';
import '../../domain/entry_models.dart';
import '../../domain/outbox_models.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../connectivity/connectivity.dart';
import '../offline/outbox_codec.dart';

/// Cas d'usage des écritures : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
/// Les brouillons se saisissent aussi hors connexion : ils sont alors conservés dans la file d'envoi (`local:<n>`) et envoyés à la reconnexion.
class EntriesService {
  EntriesService(this._repository, this._online, this._outbox);

  final EntriesRepository _repository;
  final OnlinePolicy _online;
  final OutboxRepository _outbox;

  /// Écritures du dossier ; les brouillons en attente d'envoi (saisis hors connexion) sont ajoutés en tête.
  Future<List<EntryModel>> list(String entityId, EntryFilter f, {String? fiscalYearId, int limit = 300}) async {
    final pending = await _pendingDrafts(entityId, f);
    List<EntryModel> remote;
    try {
      remote = await _repository.list(entityId, f, fiscalYearId: fiscalYearId, limit: limit);
    } catch (e) {
      if (pending.isEmpty || !isConnectivityFailure(e)) rethrow;
      remote = const [];
    }
    return [...pending, ...remote];
  }

  Future<List<EntryModel>> _pendingDrafts(String entityId, EntryFilter f) async {
    if (f.status != null && f.status != 'draft') return const [];
    final items = (await _outbox.all()).where((i) => i.kind == OutboxKind.entryDraft && i.payload['entity_id'] == entityId && i.payload['remote_id'] == null);
    final search = f.search?.trim().toLowerCase();
    return [
      for (final i in items.toList().reversed)
        if (_matches(localDraftAsEntry(i.id, i.payload), f, search)) localDraftAsEntry(i.id, i.payload),
    ];
  }

  bool _matches(EntryModel e, EntryFilter f, String? search) {
    if (f.journalId != null && e.journalId != f.journalId) return false;
    if (f.month != null && (e.entryDate.year != f.month!.year || e.entryDate.month != f.month!.month)) return false;
    if (search != null && search.isNotEmpty && !e.label.toLowerCase().contains(search) && !(e.reference ?? '').toLowerCase().contains(search)) return false;
    return true;
  }

  Future<EntryModel> get(String id) async {
    if (isLocalDraftId(id)) {
      final item = await _outbox.get(localDraftOutboxId(id));
      if (item == null) throw const AppError.business('Ce brouillon n\'est plus en attente : il a peut-être déjà été envoyé.');
      return localDraftAsEntry(item.id, item.payload);
    }
    return _repository.get(id);
  }

  /// Enregistre un brouillon : sur le serveur si la connexion le permet, sinon dans la file d'envoi (identifiant `local:<n>`).
  Future<String> saveDraft(String cabinetId, String entityId, EntryDraft d) async {
    if (isLocalDraftId(d.id)) {
      final outboxId = localDraftOutboxId(d.id!);
      await _outbox.update(outboxId, encodeEntryDraft(cabinetId: cabinetId, entityId: entityId, draft: d));
      return d.id!;
    }
    if (_online.isOnline) {
      try {
        return await _repository.saveDraft(cabinetId, entityId, d);
      } catch (e) {
        if (!isConnectivityFailure(e)) rethrow;
      }
    }
    final outboxId = await _outbox.enqueue(OutboxKind.entryDraft, encodeEntryDraft(cabinetId: cabinetId, entityId: entityId, draft: d));
    return localDraftId(outboxId);
  }

  Future<void> deleteDraft(String id) async {
    if (isLocalDraftId(id)) return _outbox.remove(localDraftOutboxId(id));
    _online.require('La suppression d\'un brouillard enregistré');
    return _repository.deleteDraft(id);
  }

  Future<int> validate(String id) async {
    _online.require('La validation des écritures');
    return _repository.validate(id);
  }

  Future<void> validateMany(List<String> ids) async {
    _online.require('La validation et la revue des écritures');
    return _repository.validateMany(ids);
  }

  Future<String> reverse(String id, {required String reason, DateTime? date}) async {
    _online.require('La contre-passation');
    return _repository.reverse(id, reason: reason, date: date);
  }

  Future<void> review(String id, {required String status, String? comment}) async {
    _online.require('La revue des écritures');
    return _repository.review(id, status: status, comment: comment);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    _online.require('La validation et la revue des écritures');
    return _repository.notifications();
  }

  Future<void> markRead(int id) async {
    _online.require('La validation et la revue des écritures');
    return _repository.markRead(id);
  }
}
