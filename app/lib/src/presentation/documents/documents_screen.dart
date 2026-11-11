import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:akonta/design/design.dart';

import '../widgets/error_display.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import 'document_preview.dart';
import '../../application/providers/documents_providers.dart';
import '../../domain/entry_models.dart';
import '../../domain/documents_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

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
    final list = docs.value;
    final inboxCount = list?.where((d) => d.isInInbox).length;
    final onMobile = canAttach && _isMobile;

    Widget uploadButton({required bool primary}) {
      const key = Key('upload-document');
      return primary
          ? AkButton.primary('Déposer', key: key, icon: Icons.upload_file_outlined, onPressed: _busy ? null : _pickFiles, expand: compact)
          : AkButton.secondary('Déposer', key: key, icon: Icons.upload_file_outlined, onPressed: _busy ? null : _pickFiles, expand: compact);
    }

    String withCount(String label, int? n) => n == null ? label : '$label ($n)';

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AkPageHead(
            title: 'Pièces',
            subtitle: widget.entity.dossierLabel,
            actions: [
              if (canAttach && !compact) uploadButton(primary: !_isMobile),
              if (onMobile && !compact) AkButton.primary('Photographier', icon: Icons.photo_camera_outlined, onPressed: _busy ? null : _capturePhoto),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          if (onMobile && compact) ...[
            _CaptureButton(busy: _busy, onPressed: _capturePhoto),
            const SizedBox(height: AkSpace.s2),
            uploadButton(primary: false),
            const SizedBox(height: AkSpace.s3),
          ] else if (canAttach && compact) ...[
            uploadButton(primary: true),
            const SizedBox(height: AkSpace.s3),
          ],
          Expanded(
            child: AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AkSpace.s3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AkSegmented<bool>(
                        options: [AkOption(true, withCount('Boîte de réception', inboxCount)), AkOption(false, withCount('Toutes les pièces', list?.length))],
                        selected: _inboxOnly,
                        onChanged: (v) => setState(() => _inboxOnly = v),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: t.border),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
                    color: t.surfaceSunken,
                    child: Row(
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(right: AkSpace.s2),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        Expanded(
                          child: Text('PDF, JPEG, PNG, HEIC · 20 Mo max · chaque pièce est protégée contre toute modification', style: AkText.caption.copyWith(color: t.textMuted)),
                        ),
                      ],
                    ),
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
                ],
              ),
            ),
          ),
        ],
      ),
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
      final sent = await ref.read(documentsServiceProvider).upload(cabinetId: cabinet!.id, entityId: widget.entity.id, fileName: name, bytes: bytes, capturedVia: via);
      if (sent == null && mounted) showAkToast(context, 'Hors connexion : la pièce est conservée sur cet appareil et sera envoyée à la reconnexion.', kind: AkToastKind.info);
      ref.invalidate(documentsProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
    } catch (e) {
      if (mounted) showError(context, e, action: 'Dépôt refusé');
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
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => DocumentViewer(document: d),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.only(left: AkSpace.s4, top: 10, bottom: 10, right: AkSpace.s2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 48,
              decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: AkRadius.smAll),
              child: Icon(d.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, color: t.textMuted),
            ),
            const SizedBox(width: AkSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AkText.bodyStrong.copyWith(color: t.text),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AkText.caption.copyWith(color: t.textMuted),
                  ),
                  if (compact)
                    Padding(padding: const EdgeInsets.only(top: 4), child: status)
                  else
                    Text('${d.sha256.substring(0, 12)}…', style: AkText.code.copyWith(color: t.textMuted)),
                ],
              ),
            ),
            if (!compact) ...[status, const SizedBox(width: AkSpace.s2)],
            if (canAttach)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'attach':
                      final entryId = await showDialog<String>(
                        context: context,
                        builder: (_) => _EntryPicker(entity: entity),
                      );
                      if (entryId == null) return;
                      await ref.read(documentsServiceProvider).attach(entryId, d.id);
                    case 'scan':
                      await _proposeEntry(context, ref, d);
                      return;
                    case 'draft':
                      if (context.mounted) context.go('/saisie/nouvelle?document=${d.id}');
                      return;
                    case 'delete':
                      final ok = await showAkConfirm(
                        context,
                        title: 'Supprimer cette pièce ?',
                        message: 'La pièce « ${d.fileName} » sera supprimée de la boîte de réception. Cette action est irréversible.',
                        confirmLabel: 'Supprimer',
                        danger: true,
                      );
                      if (!ok || !context.mounted) return;
                      try {
                        await ref.read(documentsServiceProvider).delete(d);
                      } catch (e) {
                        if (context.mounted) {
                          showAkToast(context, 'Pièce liée à une écriture validée : non supprimable.', kind: AkToastKind.warning);
                        }
                      }
                  }
                  ref.invalidate(documentsProvider(entity.id));
                  ref.invalidate(entityDashboardProvider);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'attach', child: Text('Rattacher à une écriture…')),
                  if (d.isInInbox) const PopupMenuItem(value: 'scan', child: Text('Proposer une écriture (lecture de la pièce)')),
                  if (d.isInInbox) const PopupMenuItem(value: 'draft', child: Text('Créer un brouillard avec cette pièce')),
                  if (d.isInInbox) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              )
            else
              const SizedBox(width: AkSpace.s2),
          ],
        ),
      ),
    );
  }
}

/// Lit la pièce et ouvre le brouillard proposé ; les points douteux sont rappelés, rien n'est validé automatiquement.
Future<void> _proposeEntry(BuildContext context, WidgetRef ref, DocumentModel d) async {
  showAkToast(context, 'Lecture de « ${d.fileName} »…');
  try {
    final result = await ref.read(documentsServiceProvider).proposeEntry(d.id);
    ref.invalidate(documentsProvider(d.entityId));
    if (!context.mounted) return;
    final note = result.existing ? 'Brouillard déjà proposé pour cette pièce.' : 'Brouillard proposé : à vérifier avant validation.';
    showAkToast(context, result.warnings.isEmpty ? note : '$note ${result.warnings.join(' ')}', kind: result.warnings.isEmpty ? AkToastKind.info : AkToastKind.warning);
    context.go('/saisie/${result.entryId}');
  } catch (e) {
    if (context.mounted) showError(context, e, action: 'Lecture de la pièce impossible');
  }
}

/// Gros bouton de capture (mobile) : photographier une pièce avec la caméra, elle arrive dans la boîte de réception.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Material(
      color: busy ? t.disabledFill : t.accent,
      borderRadius: AkRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('capture-document'),
        onTap: busy ? null : onPressed,
        hoverColor: t.accentHover,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_outlined, size: 28, color: busy ? t.textDisabled : t.onAccent),
              const SizedBox(width: AkSpace.s3),
              Text('Photographier une pièce', style: AkText.title.copyWith(color: busy ? t.textDisabled : t.onAccent)),
            ],
          ),
        ),
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
    final size = MediaQuery.sizeOf(context);
    final d = document;
    return AkDialog(
      title: d.fileName,
      size: AkDialogSize.l,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Fmt.date(d.capturedAt)} · ${(d.sizeBytes / 1024).toStringAsFixed(0)} Ko · ${d.capturedVia == 'mobile' ? 'capture mobile' : 'dépôt'}',
            style: AkText.caption.copyWith(color: t.textMuted),
          ),
          Tooltip(
            message: 'Empreinte numérique (SHA-256) : elle change si le fichier est modifié.',
            child: Text('Empreinte ${d.sha256}', style: AkText.code.copyWith(color: t.textMuted)),
          ),
          const SizedBox(height: AkSpace.s3),
          DocumentPreview(document: d, height: size.height < 704 ? size.height - 280 : 480),
        ],
      ),
      actions: [AkButton.secondary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }

}

/// Choix d'une écriture du dossier pour y rattacher la pièce : tout l'exercice, avec recherche (libellé, référence, montant).
class _EntryPicker extends ConsumerStatefulWidget {
  const _EntryPicker({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_EntryPicker> createState() => _EntryPickerState();
}

class _EntryPickerState extends ConsumerState<_EntryPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<EntryModel>> _entries = _load('');

  Future<List<EntryModel>> _load(String q) =>
      ref.read(entriesServiceProvider).list(widget.entity.id, EntryFilter(search: q.trim().isEmpty ? null : q.trim()), fiscalYearId: widget.entity.fiscalYearId, limit: 100);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _entries = _load(q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkDialog(
      title: 'Rattacher à une écriture',
      size: AkDialogSize.m,
      content: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(key: const Key('entry-picker-search'), controller: _search, label: 'Rechercher (libellé, référence, montant)', onChanged: _onChanged),
            const SizedBox(height: AkSpace.s2),
            Expanded(
              child: FutureBuilder<List<EntryModel>>(
                future: _entries,
                builder: (context, snap) {
                  if (snap.hasError) return AkErrorMessage(errorText(snap.error!));
                  if (!snap.hasData) return const AkLoading();
                  final list = snap.data!;
                  if (list.isEmpty) return const AkEmptyState('Aucune écriture ne correspond.');
                  return ListView(
                    children: [
                      for (final e in list)
                        InkWell(
                          onTap: () => Navigator.pop(context, e.id),
                          child: Container(
                            constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact + 8),
                            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 6),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text)),
                                      Text('${Fmt.date(e.entryDate)} · ${e.numberLabel}', style: AkText.code.copyWith(color: t.textMuted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AkSpace.s2),
                                AkAmountText(Fmt.fcfa(e.totalDebit, showZero: true)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context))],
    );
  }
}
