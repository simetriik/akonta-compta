import 'dart:convert';

import '../../core/errors/errors.dart';
import '../../domain/outbox_models.dart';
import '../../domain/repositories/documents_repository.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../connectivity/connectivity.dart';
import 'outbox_codec.dart';

/// Résultat d'un passage de synchronisation.
class SyncReport {
  const SyncReport({required this.sent, required this.failed, required this.remaining});

  final int sent;
  final int failed;
  final int remaining;
}

/// Rejoue la file d'envoi dans l'ordre. Le serveur fait foi : un brouillard est enregistré comme n'importe quel brouillard
/// (numérotation, contrôles et droits s'appliquent à ce moment). Un défaut de connexion arrête le passage ; tout autre échec est consigné
/// sur l'élément, qui n'est plus rejoué automatiquement après `maxAutomaticAttempts` échecs (relance manuelle possible).
class SyncService {
  SyncService({required this.outbox, required this.entries, required this.documents, required this.connectivity});

  static const maxAutomaticAttempts = 3;

  final OutboxRepository outbox;
  final EntriesRepository entries;
  final DocumentsRepository documents;
  final ConnectivityPort connectivity;
  bool _running = false;

  Future<SyncReport> flush({bool retryFailed = false}) async {
    if (_running || !connectivity.isOnline) return SyncReport(sent: 0, failed: 0, remaining: (await outbox.all()).length);
    _running = true;
    var sent = 0, failed = 0;
    try {
      for (final item in await outbox.all()) {
        if (!retryFailed && item.attempts >= maxAutomaticAttempts) continue;
        try {
          await _send(item);
          await outbox.remove(item.id);
          sent++;
        } catch (e) {
          if (isConnectivityFailure(e)) break;
          await outbox.recordFailure(item.id, errorText(e));
          failed++;
        }
      }
    } finally {
      _running = false;
    }
    return SyncReport(sent: sent, failed: failed, remaining: (await outbox.all()).length);
  }

  Future<void> _send(OutboxItem item) async {
    final p = item.payload;
    switch (item.kind) {
      case OutboxKind.entryDraft:
        await entries.saveDraft(p['cabinet_id'] as String, p['entity_id'] as String, decodeEntryDraft(p));
      case OutboxKind.documentUpload:
        await documents.upload(
          cabinetId: p['cabinet_id'] as String,
          entityId: p['entity_id'] as String,
          fileName: p['file_name'] as String,
          bytes: base64Decode(p['bytes'] as String),
          capturedVia: p['captured_via'] as String,
          note: p['note'] as String?,
        );
      default:
        throw AppError.business('Action en attente de nature inconnue : ${item.kind}.');
    }
  }
}
