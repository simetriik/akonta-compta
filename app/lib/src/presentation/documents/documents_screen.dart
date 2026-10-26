import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
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
    final t = context.ak;
    final docs = ref.watch(documentsProvider(widget.entity.id));
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canAttach = perms.has('documents.attach', entityId: widget.entity.id);
    final compact = akIsCompact(context);
    final margin = akPageMargin(context);
    final h = akControlHeight(context);
    final list = docs.value;
    final inboxCount = list?.where((d) => d.isInInbox).length;

    Widget photoButton({double? height}) => FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: Size(0, height ?? h)),
          onPressed: _busy ? null : _capturePhoto,
          icon: const Icon(Icons.photo_camera_outlined, size: 20),
          label: const Text('Photographier'),
        );
    Widget uploadButton({required bool primary}) {
      final label = const Text('Déposer');
      const icon = Icon(Icons.upload_file_outlined, size: 18);
      return primary
          ? FilledButton.icon(key: const Key('upload-document'), style: FilledButton.styleFrom(minimumSize: Size(0, h)), onPressed: _busy ? null : _pickFiles, icon: icon, label: label)
          : OutlinedButton.icon(key: const Key('upload-document'), style: OutlinedButton.styleFrom(minimumSize: Size(0, h)), onPressed: _busy ? null : _pickFiles, icon: icon, label: label);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AkPageHead(
          title: 'Pièces',
          subtitle: widget.entity.dossierLabel,
          actions: [if (canAttach && !compact) uploadButton(primary: !_isMobile), if (canAttach && !compact && _isMobile) photoButton()],
        ),
        const SizedBox(height: AkSpace.s3),
        Expanded(
          child: AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(children: [
              Row(children: [
                const SizedBox(width: AkSpace.s2),
                _InboxTab(label: 'Boîte de réception', count: inboxCount, selected: _inboxOnly, onTap: () => setState(() => _inboxOnly = true)),
                _InboxTab(label: 'Toutes les pièces', count: list?.length, selected: !_inboxOnly, onTap: () => setState(() => _inboxOnly = false)),
              ]),
              Divider(height: 1, color: t.border),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
                color: t.surfaceSunken,
                child: Row(children: [
                  if (_busy) const Padding(padding: EdgeInsets.only(right: AkSpace.s2), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  Expanded(child: Text('PDF, JPEG, PNG, HEIC · 20 Mo max · empreinte SHA-256', style: AkText.caption.copyWith(color: t.textMuted))),
                ]),
              ),
              Divider(height: 1, color: t.border),
              Expanded(
                child: AsyncView(
                  value: docs,
                  onRetry: () => ref.invalidate(documentsProvider(widget.entity.id)),
                  builder: (all) {
                    final shown = _inboxOnly ? all.where((d) => d.isInInbox).toList() : all;
                    if (shown.isEmpty) return AkEmptyState(_inboxOnly ? 'Boîte de réception vide.' : 'Aucune pièce.');
                    return ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) => DocumentTile(document: shown[i], entity: widget.entity, canAttach: canAttach),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
        if (canAttach && compact) ...[
          const SizedBox(height: AkSpace.s3),
          if (_isMobile) SizedBox(width: double.infinity, child: photoButton(height: 56)),
          if (_isMobile) const SizedBox(height: AkSpace.s2),
          SizedBox(width: double.infinity, child: uploadButton(primary: !_isMobile)),
        ],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dépôt refusé : $e'), backgroundColor: context.ak.danger));
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
    final t = context.ak;
    final d = document;
    final compact = akIsCompact(context);
    final meta = '${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko · ${d.capturedVia == 'mobile' ? 'capture mobile' : 'dépôt'}';
    final status = d.isInInbox
        ? AkBadge(label: 'À rattacher', color: t.warning, tint: t.warningTint, icon: Icons.inbox_outlined)
        : AkBadge(label: '${d.entryIds.length} écriture(s)', color: t.success, tint: t.successTint, icon: Icons.link);
    return InkWell(
      onTap: () => showDialog(context: context, builder: (_) => DocumentViewer(document: d)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.only(left: AkSpace.s4, top: 10, bottom: 10, right: AkSpace.s2),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: Row(children: [
          Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: AkRadius.smAll),
            child: Icon(d.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, color: t.textMuted),
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.bodyStrong.copyWith(color: t.text)),
              Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.caption.copyWith(color: t.textMuted)),
              if (compact) Padding(padding: const EdgeInsets.only(top: 4), child: status) else Text('${d.sha256.substring(0, 12)}…', style: AkText.code.copyWith(fontSize: 11, color: t.textMuted)),
            ]),
          ),
          if (!compact) ...[status, const SizedBox(width: AkSpace.s2)],
          if (canAttach)
            PopupMenuButton<String>(
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
            )
          else
            const SizedBox(width: AkSpace.s2),
        ]),
      ),
    );
  }
}

/// Onglet de la liste des pièces : libellé, compteur et filet de sélection terracotta.
class _InboxTab extends StatelessWidget {
  const _InboxTab({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: akIsCompact(context) ? AkSpace.controlTouch : 40,
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? t.brand : Colors.transparent, width: 2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: (selected ? AkText.bodyStrong : AkText.body).copyWith(color: selected ? t.brandText : t.textMuted)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: selected ? t.brandTint : t.surfaceSunken, borderRadius: AkRadius.smAll),
              child: Text('$count', style: AkText.label.copyWith(color: selected ? t.brandText : t.textMuted, letterSpacing: 0)),
            ),
          ],
        ]),
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
    final t = context.ak;
    final repo = ref.watch(documentsRepositoryProvider);
    final size = MediaQuery.sizeOf(context);
    final d = document;
    return Dialog(
      insetPadding: const EdgeInsets.all(AkSpace.s4),
      child: SizedBox(
        width: size.width < 792 ? size.width - 32 : 760,
        height: size.height < 704 ? size.height - 32 : 640,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s2, AkSpace.s3),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.heading.copyWith(color: t.text)),
                  Text('${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko · ${d.capturedVia == 'mobile' ? 'capture mobile' : 'dépôt'}', style: AkText.caption.copyWith(color: t.textMuted)),
                  Text('SHA-256 ${d.sha256}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.code.copyWith(fontSize: 11, color: t.textMuted)),
                ]),
              ),
              IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: Container(
              color: t.surfaceSunken,
              child: d.isImage
                  ? FutureBuilder<Uint8List>(
                      future: repo.download(d),
                      builder: (_, snap) => snap.hasData ? InteractiveViewer(child: Image.memory(snap.data!)) : const Center(child: CircularProgressIndicator()),
                    )
                  : FutureBuilder<String>(
                      future: repo.signedUrl(d),
                      builder: (_, snap) => Center(
                        child: snap.hasData
                            ? FilledButton.icon(onPressed: () => _open(snap.data!), icon: const Icon(Icons.open_in_new), label: const Text('Ouvrir le PDF (lien signé, 10 min)'))
                            : const CircularProgressIndicator(),
                      ),
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
    final t = context.ak;
    final entries = ref.watch(entriesListProvider(entity.id));
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: const Text('Rattacher à une écriture'),
      contentPadding: const EdgeInsets.fromLTRB(0, AkSpace.s2, 0, 0),
      content: SizedBox(
        width: width < 620 ? width - 80 : 560,
        height: 420,
        child: AsyncView(
          value: entries,
          builder: (list) {
            if (list.isEmpty) return const AkEmptyState('Aucune écriture dans le mois filtré (changez le filtre dans Saisie).');
            return ListView(children: [
              for (final e in list)
                InkWell(
                  onTap: () => Navigator.pop(context, e.id),
                  child: Container(
                    constraints: BoxConstraints(minHeight: akIsCompact(context) ? AkSpace.rowTouch : AkSpace.rowCompact + 8),
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 6),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text)),
                          Text('${Fmt.date(e.entryDate)} · ${e.numberLabel}', style: AkText.code.copyWith(fontSize: 12, color: t.textMuted)),
                        ]),
                      ),
                      const SizedBox(width: AkSpace.s2),
                      AkAmountText(Fmt.fcfa(e.totalDebit, showZero: true)),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))],
    );
  }
}
