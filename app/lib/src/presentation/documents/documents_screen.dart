import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/documents_repository.dart';
import '../../data/entries_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import 'launch_url.dart';

/// Pièces justificatives du dossier : dépôt (fichier ou photo sur mobile), boîte de réception, rattachement, visionneuse (§10.5).
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _DocumentsBody(entity: entity));
}

class _DocumentsBody extends ConsumerStatefulWidget {
  const _DocumentsBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_DocumentsBody> createState() => _DocumentsBodyState();
}

class _DocumentsBodyState extends ConsumerState<_DocumentsBody> {
  bool _inboxOnly = true;
  bool _busy = false;

  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider(widget.entity.id));
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canAttach = perms.has('documents.attach', entityId: widget.entity.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !canAttach
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (_isMobile) ...[
                FloatingActionButton.extended(heroTag: 'photo', onPressed: _busy ? null : _capturePhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Photographier')),
                const SizedBox(width: 12),
              ],
              FloatingActionButton.extended(key: const Key('upload-document'), heroTag: 'file', onPressed: _busy ? null : _pickFiles, icon: const Icon(Icons.upload_file_outlined), label: const Text('Déposer')),
            ]),
      body: Column(children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('Boîte de réception')), ButtonSegment(value: false, label: Text('Toutes les pièces'))],
                selected: {_inboxOnly},
                onSelectionChanged: (s) => setState(() => _inboxOnly = s.first),
              ),
              const Spacer(),
              if (_busy) const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              const Text('PDF, JPEG, PNG, HEIC · 20 Mo max · empreinte SHA-256', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: docs,
            onRetry: () => ref.invalidate(documentsProvider(widget.entity.id)),
            builder: (list) {
              final shown = _inboxOnly ? list.where((d) => d.isInInbox).toList() : list;
              if (shown.isEmpty) return Center(child: Text(_inboxOnly ? 'Boîte de réception vide.' : 'Aucune pièce.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => DocumentTile(document: shown[i], entity: widget.entity, canAttach: canAttach),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _pickFiles() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif']);
    if (picked.isEmpty) return;
    for (final f in picked) {
      await _upload(f.name, await f.readAsBytes(), 'desktop');
    }
  }

  Future<void> _capturePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2400);
    if (photo == null) return;
    await _upload(photo.name.endsWith('.jpg') || photo.name.endsWith('.jpeg') ? photo.name : '${photo.name}.jpg', await photo.readAsBytes(), 'mobile');
  }

  Future<void> _upload(String name, Uint8List bytes, String via) async {
    setState(() => _busy = true);
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref.read(documentsRepositoryProvider).upload(cabinetId: cabinet!.id, entityId: widget.entity.id, fileName: name, bytes: bytes, capturedVia: via);
      ref.invalidate(documentsProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dépôt refusé : $e'), backgroundColor: AkColors.toCorrect));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class DocumentTile extends ConsumerWidget {
  const DocumentTile({super.key, required this.document, required this.entity, required this.canAttach});

  final DocumentModel document;
  final EntitySummary entity;
  final bool canAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = document;
    return ListTile(
      leading: Icon(d.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, color: AkColors.terracotta),
      title: Text(d.fileName),
      subtitle: Text('${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko · ${d.capturedVia == 'mobile' ? 'capture mobile' : 'dépôt'} · ${d.sha256.substring(0, 12)}… · ${d.isInInbox ? 'non rattachée' : '${d.entryIds.length} écriture(s)'}'),
      onTap: () => showDialog(context: context, builder: (_) => DocumentViewer(document: d)),
      trailing: !canAttach
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'attach':
                    final entryId = await showDialog<String>(context: context, builder: (_) => _EntryPicker(entity: entity));
                    if (entryId == null) return;
                    await ref.read(documentsRepositoryProvider).attach(entryId, d.id);
                  case 'draft':
                    if (context.mounted) context.go('/saisie/nouvelle?document=${d.id}');
                    return;
                  case 'delete':
                    try {
                      await ref.read(documentsRepositoryProvider).delete(d);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pièce liée à une écriture validée : non supprimable.')));
                    }
                }
                ref.invalidate(documentsProvider(entity.id));
                ref.invalidate(entityDashboardProvider);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'attach', child: Text('Rattacher à une écriture…')),
                if (d.isInInbox) const PopupMenuItem(value: 'draft', child: Text('Créer un brouillard avec cette pièce')),
                if (d.isInInbox) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
    );
  }
}

/// Visionneuse : image ou PDF (ouverture par URL signée) à côté de l'écriture.
class DocumentViewer extends ConsumerWidget {
  const DocumentViewer({super.key, required this.document});

  final DocumentModel document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentsRepositoryProvider);
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 640,
        child: Column(children: [
          ListTile(title: Text(document.fileName), subtitle: Text('SHA-256 ${document.sha256}'), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
          Expanded(
            child: document.isImage
                ? FutureBuilder<Uint8List>(
                    future: repo.download(document),
                    builder: (_, snap) => snap.hasData ? InteractiveViewer(child: Image.memory(snap.data!)) : const Center(child: CircularProgressIndicator()),
                  )
                : FutureBuilder<String>(
                    future: repo.signedUrl(document),
                    builder: (_, snap) => Center(
                      child: snap.hasData
                          ? FilledButton.icon(onPressed: () => _open(snap.data!), icon: const Icon(Icons.open_in_new), label: const Text('Ouvrir le PDF (lien signé, 10 min)'))
                          : const CircularProgressIndicator(),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Future<void> _open(String url) => launchExternalUrl(url);
}

/// Sélection d'une écriture du dossier pour rattachement.
class _EntryPicker extends ConsumerWidget {
  const _EntryPicker({required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesListProvider(entity.id));
    return AlertDialog(
      title: const Text('Rattacher à une écriture'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: AsyncView(
          value: entries,
          builder: (list) => ListView(children: [
            for (final e in list)
              ListTile(dense: true, title: Text('${Fmt.date(e.entryDate)} · ${e.numberLabel} · ${e.label}'), subtitle: Text(Fmt.fcfa(e.totalDebit, showZero: true)), onTap: () => Navigator.pop(context, e.id)),
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucune écriture dans le mois filtré (changez le filtre dans Saisie).')),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))],
    );
  }
}
