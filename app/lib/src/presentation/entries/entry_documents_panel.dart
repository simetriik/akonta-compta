import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/documents_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/documents_models.dart';

/// Pièces justificatives d'une écriture : liste, ajout depuis la boîte de réception, d'un nouveau fichier ou d'une photo.
/// Pour une écriture pas encore enregistrée, les pièces choisies restent en attente ([pending]) et sont rattachées à l'enregistrement.
class EntryDocumentsPanel extends ConsumerStatefulWidget {
  const EntryDocumentsPanel({
    super.key,
    required this.entityId,
    required this.entryId,
    required this.pending,
    required this.onPendingChanged,
    required this.onView,
    required this.canDetach,
    required this.canAttach,
    this.viewedId,
  });

  final String entityId;

  /// Écriture enregistrée sur le serveur ; null pour une nouvelle écriture ou un brouillon local.
  final String? entryId;
  final List<DocumentModel> pending;
  final ValueChanged<List<DocumentModel>> onPendingChanged;
  final ValueChanged<DocumentModel> onView;
  final String? viewedId;

  /// Une pièce d'une écriture validée ne se détache plus (règle de la base).
  final bool canDetach;
  final bool canAttach;

  @override
  ConsumerState<EntryDocumentsPanel> createState() => _EntryDocumentsPanelState();
}

class _EntryDocumentsPanelState extends ConsumerState<EntryDocumentsPanel> {
  bool _busy = false;

  bool get _canTakePhoto => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showAkToast(context, errorText(e, action: failure), kind: AkToastKind.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ajoute la pièce : en attente tant que l'écriture n'existe pas, sinon rattachement immédiat.
  Future<void> _add(DocumentModel d) async {
    final entryId = widget.entryId;
    if (entryId == null) {
      if (widget.pending.any((p) => p.id == d.id)) return;
      widget.onPendingChanged([...widget.pending, d]);
    } else {
      await ref.read(documentsServiceProvider).attach(entryId, d.id);
      ref.invalidate(entryDocumentsProvider(entryId));
    }
    ref.invalidate(documentsProvider(widget.entityId));
    widget.onView(d);
  }

  Future<void> _fromInbox() => _run(() async {
    final chosen = await showDialog<DocumentModel>(context: context, builder: (_) => _InboxPicker(entityId: widget.entityId, excluded: {for (final p in widget.pending) p.id}));
    if (chosen != null) await _add(chosen);
  }, 'Rattachement impossible');

  Future<void> _uploadFile() => _run(() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif']);
    if (picked.isEmpty) return;
    for (final f in picked) {
      await _upload(f.name, await f.readAsBytes(), 'desktop');
    }
  }, 'Dépôt refusé');

  Future<void> _photo() => _run(() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2400);
    if (photo == null) return;
    await _upload(photo.name.endsWith('.jpg') || photo.name.endsWith('.jpeg') ? photo.name : '${photo.name}.jpg', await photo.readAsBytes(), 'mobile');
  }, 'Dépôt refusé');

  Future<void> _upload(String name, Uint8List bytes, String via) async {
    final cabinet = await ref.read(currentCabinetProvider.future);
    final doc = await ref.read(documentsServiceProvider).upload(cabinetId: cabinet!.id, entityId: widget.entityId, fileName: name, bytes: bytes, capturedVia: via);
    if (doc == null) {
      if (mounted) showAkToast(context, 'Hors connexion : la pièce est conservée sur cet appareil et sera envoyée à la reconnexion ; rattachez-la ensuite depuis Pièces.', kind: AkToastKind.info);
      return;
    }
    await _add(doc);
  }

  Future<void> _detach(DocumentModel d) => _run(() async {
    final entryId = widget.entryId;
    if (entryId == null) {
      widget.onPendingChanged([for (final p in widget.pending) if (p.id != d.id) p]);
    } else {
      await ref.read(documentsServiceProvider).detach(entryId, d.id);
      ref.invalidate(entryDocumentsProvider(entryId));
    }
    ref.invalidate(documentsProvider(widget.entityId));
  }, 'Retrait impossible');

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final entryId = widget.entryId;
    final attached = entryId == null ? widget.pending : (ref.watch(entryDocumentsProvider(entryId)).value ?? const <DocumentModel>[]);
    return AkCard(
      key: const Key('entry-documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: AkSpace.iconSm, color: t.textMuted),
              const SizedBox(width: AkSpace.s1),
              Expanded(child: Text('Pièces justificatives${attached.isEmpty ? '' : ' (${attached.length})'}', style: AkText.bodyStrong.copyWith(color: t.text))),
            ],
          ),
          if (widget.canAttach)
            // Les boutons passent à la ligne sur petit écran (trois boutons avec la photo sur mobile).
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: Wrap(
                spacing: AkSpace.s2,
                runSpacing: AkSpace.s2,
                children: [
                  AkButton.secondary('Boîte de réception', key: const Key('doc-from-inbox'), icon: Icons.inbox_outlined, dense: true, onPressed: _busy ? null : _fromInbox),
                  AkButton.secondary('Déposer un fichier', key: const Key('doc-upload'), icon: Icons.upload_file_outlined, dense: true, onPressed: _busy ? null : _uploadFile),
                  if (_canTakePhoto) AkButton.primary('Photographier', key: const Key('doc-photo'), icon: Icons.photo_camera_outlined, dense: true, onPressed: _busy ? null : _photo),
                ],
              ),
            ),
          if (attached.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: Text(
                widget.canAttach ? 'Aucune pièce jointe. Joignez la facture, le reçu ou le relevé qui justifie cette écriture.' : 'Aucune pièce jointe.',
                key: const Key('doc-empty'),
                style: AkText.caption.copyWith(color: t.textMuted),
              ),
            )
          else
            for (final d in attached)
              InkWell(
                key: Key('doc-${d.id}'),
                onTap: () => widget.onView(d),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: widget.viewedId == d.id ? t.surfaceSunken : null,
                  child: Row(
                    children: [
                      Icon(d.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, size: 20, color: t.textMuted),
                      const SizedBox(width: AkSpace.s2),
                      Expanded(child: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
                      Text('${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko', style: AkText.caption.copyWith(color: t.textMuted)),
                      if (widget.canDetach) AkIconButton(key: Key('doc-detach-${d.id}'), icon: Icons.link_off, tooltip: 'Détacher la pièce', dense: true, onPressed: _busy ? null : () => _detach(d)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Boîte de réception du dossier : les pièces déposées et pas encore rattachées.
class _InboxPicker extends ConsumerWidget {
  const _InboxPicker({required this.entityId, required this.excluded});

  final String entityId;
  final Set<String> excluded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final docs = ref.watch(documentsProvider(entityId));
    return AkDialog(
      title: 'Boîte de réception',
      size: AkDialogSize.m,
      content: SizedBox(
        height: 360,
        child: docs.when(
          loading: () => const AkLoading(),
          error: (e, _) => AkErrorMessage(errorText(e)),
          data: (all) {
            final inbox = [for (final d in all) if (d.isInInbox && !excluded.contains(d.id)) d];
            if (inbox.isEmpty) return const AkEmptyState('Aucune pièce en attente. Déposez un fichier ou une photo.', icon: Icons.inbox_outlined);
            return ListView(
              children: [
                for (final d in inbox)
                  InkWell(
                    key: Key('inbox-${d.id}'),
                    onTap: () => Navigator.pop(context, d),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: 6),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                      child: Row(
                        children: [
                          Icon(d.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, color: t.textMuted),
                          const SizedBox(width: AkSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text)),
                                Text('${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko', style: AkText.caption.copyWith(color: t.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context))],
    );
  }
}

/// Mobile : ligne repliable qui remplace le bloc des pièces, avec leur nombre.
class EntryDocumentsToggle extends StatelessWidget {
  const EntryDocumentsToggle({super.key, required this.count, required this.open, required this.onTap});

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: AkCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: const Key('entry-documents-toggle'),
          borderRadius: AkRadius.smAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSpace.rowTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
              child: Row(
                children: [
                  Icon(Icons.attach_file, size: AkSpace.iconSm, color: t.textMuted),
                  const SizedBox(width: AkSpace.s1),
                  Expanded(
                    child: Text('Pièces justificatives${count == 0 ? '' : ' ($count)'}', style: AkText.bodyStrong.copyWith(color: t.text)),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: t.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
