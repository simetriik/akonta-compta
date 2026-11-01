import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/services.dart';
import '../../domain/documents_models.dart';
import 'launch_url.dart';

/// Aperçu d'une pièce : une image s'affiche (zoomable), un PDF s'ouvre par lien signé (compartiment privé, 10 minutes).
class DocumentPreview extends ConsumerWidget {
  const DocumentPreview({super.key, required this.document, this.height = 480});

  final DocumentModel document;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final repo = ref.watch(documentsServiceProvider);
    final d = document;
    return Container(
      height: height,
      decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: AkRadius.mdAll),
      clipBehavior: Clip.antiAlias,
      child: d.isImage
          ? FutureBuilder<Uint8List>(
              key: ValueKey('preview-${d.id}'),
              future: repo.download(d),
              builder: (_, snap) => snap.hasError
                  ? const Center(child: Text('Aperçu indisponible.'))
                  : snap.hasData
                  ? InteractiveViewer(child: Image.memory(snap.data!))
                  : const AkLoading(),
            )
          : FutureBuilder<String>(
              key: ValueKey('preview-${d.id}'),
              future: repo.signedUrl(d),
              builder: (_, snap) => Center(
                child: snap.hasError
                    ? const Text('Aperçu indisponible.')
                    : snap.hasData
                    ? AkButton.primary('Ouvrir le PDF', icon: Icons.open_in_new, onPressed: () => launchExternalUrl(snap.data!))
                    : const AkLoading(),
              ),
            ),
    );
  }
}
