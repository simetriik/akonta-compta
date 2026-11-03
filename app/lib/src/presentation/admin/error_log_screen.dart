import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../../application/providers/session_providers.dart';
import '../widgets/copy_text.dart';

/// Journal technique des erreurs de cet appareil, réservé à l'administrateur technique : il retrouve ici, à partir de la référence
/// communiquée par l'utilisateur, le détail que l'écran ne montre jamais. Le journal reste local : rien n'est envoyé ailleurs.
class ErrorLogScreen extends ConsumerWidget {
  const ErrorLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    if (!perms.roles.any((r) => r.code == 'tech_admin')) {
      return const AkEmptyState('Cet écran est réservé à l\'administrateur technique.');
    }
    final t = context.ak;
    final pad = akPageMargin(context);
    return ListenableBuilder(
      listenable: ErrorLog.instance,
      builder: (context, _) {
        final entries = ErrorLog.instance.entries;
        return ListView(
          padding: EdgeInsets.all(pad),
          children: [
            AkPageHead(
              title: 'Journal des erreurs',
              subtitle: 'Les ${ErrorLog.capacity} dernières erreurs de cet appareil, avec leur détail technique. Rien n\'est envoyé hors de l\'appareil.',
              actions: [
                AkButton.secondary(
                  'Tout copier',
                  key: const Key('error-log-copy-all'),
                  icon: Icons.copy_all_outlined,
                  onPressed: entries.isEmpty
                      ? null
                      : () => copyWithFeedback(context, ErrorLog.instance.export(), successMessage: 'Journal copié.'),
                ),
                AkButton.secondary('Vider', key: const Key('error-log-clear'), icon: Icons.delete_outline, onPressed: entries.isEmpty ? null : ErrorLog.instance.clear),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            if (entries.isEmpty)
              const AkEmptyState('Aucune erreur enregistrée sur cet appareil.')
            else
              for (final e in entries) ...[
                _EntryCard(entry: e),
                const SizedBox(height: AkSpace.s3),
              ],
            if (entries.isNotEmpty) Text('Référence, heure et nature en tête de chaque ligne ; le message affiché à l\'utilisateur est rappelé avant le détail.', style: AkText.caption.copyWith(color: t.textMuted)),
          ],
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final ErrorLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkCard(
      key: Key('error-log-${entry.reference}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(entry.reference, style: AkText.code.copyWith(color: t.textStrong)),
              Text('${Fmt.date(entry.time)} ${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}', style: AkText.caption.copyWith(color: t.textMuted)),
              AkBadge(label: entry.kind.name, color: t.danger, tint: t.dangerTint),
              AkIconButton(
                icon: Icons.copy_outlined,
                tooltip: 'Copier ce détail',
                onPressed: () => copyWithFeedback(context, entry.text, successMessage: 'Détail copié.'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text('Message affiché : ${entry.message}', style: AkText.body.copyWith(color: t.text)),
          const SizedBox(height: AkSpace.s2),
          Text(entry.technical, style: AkText.code.copyWith(color: t.textMuted)),
          if (entry.stackTrace != null) ...[
            const SizedBox(height: AkSpace.s2),
            Text(entry.stackTrace!.split('\n').take(6).join('\n'), style: AkText.code.copyWith(color: t.textMuted)),
          ],
        ],
      ),
    );
  }
}
