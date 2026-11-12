import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../application/entries/entry_editor_logic.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/template_builder.dart';
import '../../domain/entry_models.dart';
import '../../domain/reference_models.dart';
import '../widgets/error_display.dart';

/// « Enregistrer comme modèle » : propose de garder les comptes, sens et libellés de l'écriture en cours comme modèle,
/// pour ce dossier ou pour tout le cabinet selon les droits (décision provisoire D-R03). Les montants ne sont pas gardés.
Future<void> saveEntryAsTemplate(BuildContext context, WidgetRef ref, {required String entityId, required EntryDraft draft}) async {
  final journalType = (ref.read(journalsProvider(entityId)).value ?? const []).where((j) => j.id == draft.journalId).firstOrNull?.type;
  final lines = EntryEditorLogic.templateLinesFrom(draft);
  if (lines.length < 2) {
    showAkToast(context, 'Renseignez au moins deux lignes avec un compte avant d\'enregistrer un modèle.', kind: AkToastKind.warning);
    return;
  }
  final perms = ref.read(permissionsProvider).value;
  final canEntity = (perms?.has('templates.manage_entity', entityId: entityId) ?? false) || (perms?.has('references.manage', entityId: entityId) ?? false);
  final canCommon = (perms?.hasAnywhere('templates.manage_common') ?? false) || (perms?.has('cabinet.settings') ?? false);
  if (!canEntity && !canCommon) {
    showAkToast(context, 'Vous n\'avez pas le droit de créer un modèle d\'écriture.', kind: AkToastKind.warning);
    return;
  }
  final existing = await ref.read(templatesProvider(entityId).future);
  if (!context.mounted) return;
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SaveAsTemplateDialog(entityId: entityId, lines: lines, label: draft.label, journalType: journalType, existing: existing, canEntity: canEntity, canCommon: canCommon),
  );
  if (saved == true && context.mounted) showAkToast(context, 'Modèle enregistré.');
}

class _SaveAsTemplateDialog extends ConsumerStatefulWidget {
  const _SaveAsTemplateDialog({required this.entityId, required this.lines, required this.label, required this.journalType, required this.existing, required this.canEntity, required this.canCommon});

  final String entityId;
  final List<TemplateLine> lines;
  final String label;
  final String? journalType;
  final List<EntryTemplate> existing;
  final bool canEntity;
  final bool canCommon;

  @override
  ConsumerState<_SaveAsTemplateDialog> createState() => _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends ConsumerState<_SaveAsTemplateDialog> {
  late final _name = TextEditingController(text: widget.label.trim());
  late bool _common = !widget.canEntity;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Donnez un nom au modèle');
      return;
    }
    setState(() => _error = null);
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      final sameLevel = widget.existing.where((t) => t.isCabinetLevel == _common).map((t) => t.code);
      await ref
          .read(referencesServiceProvider)
          .saveTemplate(cabinet!.id, _common ? null : widget.entityId, code: TemplateBuilder.suggestCode(name, sameLevel), label: name, journalType: widget.journalType, lines: widget.lines);
      ref.invalidate(templatesProvider(widget.entityId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: 'Enregistrer comme modèle',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(key: const Key('template-name'), controller: _name, label: 'Nom du modèle', autofocus: true),
          const SizedBox(height: AkSpace.s3),
          if (widget.canEntity && widget.canCommon)
            AkDropdown<bool>(
              value: _common,
              label: 'Disponible pour',
              items: const [AkOption(false, 'Ce dossier seulement'), AkOption(true, 'Tous les dossiers du cabinet')],
              onChanged: (v) => setState(() => _common = v ?? false),
            )
          else
            Text(_common ? 'Ce modèle sera disponible pour tous les dossiers du cabinet.' : 'Ce modèle sera disponible pour ce dossier.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
          const SizedBox(height: AkSpace.s2),
          Text('Gardés : comptes, sens, libellés. Les montants ne le sont pas ; le tiers se choisit à chaque emploi.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: AkSpace.s2), child: Text(_error!, key: const Key('template-error'), style: AkText.caption.copyWith(color: context.ak.danger))),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context, false)),
        AkButton.primary('Enregistrer le modèle', key: const Key('template-save'), onPressed: _save),
      ],
    );
  }
}
