import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import '../inventory/inventory_widgets.dart';
import 'closing_widgets.dart';

class FinalStep extends ConsumerStatefulWidget {
  const FinalStep({super.key, required this.entity, required this.fy, required this.onChanged});

  final EntitySummary entity;
  final FiscalYear fy;
  final VoidCallback onChanged;

  @override
  ConsumerState<FinalStep> createState() => _FinalStepState();
}

class _FinalStepState extends ConsumerState<FinalStep> {
  final _confirm = TextEditingController();
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final can = perms.has('closing.final');
    final expected = 'ARRETER ${widget.fy.label}';
    if (widget.fy.status == 'closed') {
      final when = widget.fy.finalClosedAt;
      return ListView(
        padding: closingBodyPadding(context),
        children: [
          AkBanner(
            kind: AkBannerKind.success,
            icon: Icons.lock,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exercice ${widget.fy.label} arrêté définitivement', style: AkText.bodyStrong.copyWith(color: t.text)),
                Text(
                  '${when == null ? '' : 'Le ${Fmt.date(when)}. '}Aucune réouverture possible ; états financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.',
                ),
              ],
            ),
          ),
        ],
      );
    }
    final blocked = !can || !_acknowledged || _confirm.text.trim() != expected || widget.fy.status != 'closing';
    return ListView(
      padding: closingBodyPadding(context),
      children: [
        AkBanner(
          kind: AkBannerKind.danger,
          icon: Icons.warning_amber_outlined,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Action irréversible. ', style: AkText.bodyStrong),
                const TextSpan(text: 'Après l\'arrêté, l\'exercice devient intangible : aucune réouverture, aucune écriture ajoutée ni modifiée.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkSectionTitle('Arrêté définitif de l\'exercice ${widget.fy.label}'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Réservé à l\'associé (TOTP vérifié). L\'exercice devient intangible : aucune réouverture. Les états financiers, le grand livre et la balance sont archivés avec leurs empreintes SHA-256.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              AkCheckbox(
                value: _acknowledged,
                onChanged: can ? (v) => setState(() => _acknowledged = v) : null,
                label: 'J\'ai vérifié les états financiers et je comprends que cette action est irréversible.',
              ),
              const SizedBox(height: AkSpace.s2),
              AkTextField(
                controller: _confirm,
                enabled: can && _acknowledged,
                mono: true,
                label: 'Tapez « $expected » pour confirmer',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AkSpace.s3),
              AkButton.danger(
                'Arrêter définitivement',
                icon: Icons.lock,
                onPressed: blocked
                    ? null
                    : () async {
                        try {
                          final archive = await ref.read(closingServiceProvider).closeFinal(widget.entity.id, widget.fy.id, _confirm.text.trim());
                          widget.onChanged();
                          if (context.mounted) showAkToast(context, 'Exercice arrêté. Archive $archive.');
                        } catch (e) {
                          if (context.mounted) showErrorSnack(context, errorText(e));
                        }
                      },
              ),
              if (widget.fy.status != 'closing')
                Padding(
                  padding: const EdgeInsets.only(top: AkSpace.s2),
                  child: Text('L\'exercice doit être en clôture provisoire.', style: AkText.caption.copyWith(color: t.textMuted)),
                ),
              if (!can)
                Padding(
                  padding: const EdgeInsets.only(top: AkSpace.s2),
                  child: Text('Votre rôle ne permet pas l\'arrêté définitif.', style: AkText.caption.copyWith(color: t.textMuted)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Ce que fait l\'arrêté définitif'),
              const SizedBox(height: AkSpace.s2),
              for (final (icon, text) in const [
                (Icons.lock_outline, 'L\'exercice passe en lecture seule, définitivement.'),
                (Icons.fingerprint, 'États financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: t.textMuted),
                      const SizedBox(width: AkSpace.s2),
                      Expanded(
                        child: Text(text, style: AkText.table.copyWith(color: t.text)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
