import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/references_providers.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import 'references_widgets.dart';
import '../../application/rules/template_builder.dart';

class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final templates = ref.watch(templatesProvider(entity.id));
    return Column(
      children: [
        ListToolbar(
          action: AkButton.primary(
            'Nouveau modèle',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => TemplateDialog(entity: entity),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: templates,
            onRetry: () => ref.invalidate(templatesProvider(entity.id)),
            builder: (list) => list.isEmpty
                ? const AkEmptyState('Aucun modèle d\'écriture.')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: t.border)),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
                          title: Row(
                            children: [
                              Text(
                                m.code,
                                style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: AkSpace.s2),
                              Expanded(
                                child: Text(
                                  '— ${m.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AkText.table.copyWith(color: t.text),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            [
                              m.isCabinetLevel ? 'modèle du cabinet' : 'modèle du dossier',
                              if (m.journalType != null) Journal.typeLabels[m.journalType] ?? m.journalType!,
                              if (m.description != null) m.description!,
                            ].join(' · '),
                            style: AkText.caption.copyWith(color: t.textMuted),
                          ),
                          children: [
                            for (final l in m.lines)
                              Container(
                                color: t.surfaceSunken,
                                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text('${l.lineNo}', style: AkText.code.copyWith(color: t.textMuted)),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: l.accountCode,
                                                  style: AkText.code.copyWith(color: t.text),
                                                ),
                                                TextSpan(
                                                  text: '${l.usesThirdParty ? ' + tiers' : ''} · ${l.side == 'debit' ? 'Débit' : 'Crédit'}',
                                                  style: AkText.table.copyWith(color: t.text),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text('${l.label ?? ''} · ${l.formulaLabel}', style: AkText.caption.copyWith(color: t.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!m.isCabinetLevel)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(AkSpace.s2),
                                  child: AkButton.dangerOutline(
                                    'Retirer ce modèle',
                                    dense: true,
                                    onPressed: () async {
                                      await ref.read(referencesServiceProvider).deactivateTemplate(m.id);
                                      ref.invalidate(templatesProvider(entity.id));
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Création d'un modèle du dossier : lignes avec compte, sens, formule (saisie, % d'une ligne, solde).
class TemplateDialog extends ConsumerStatefulWidget {
  const TemplateDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<TemplateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  String? _journalType;
  final List<_LineDraft> _lines = [_LineDraft(), _LineDraft(formula: 'balance', side: 'credit')];
  String? _error;

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(taxRatesProvider).value ?? const <TaxRate>[];
    final rateCodes = rates.map((r) => r.code).toSet().toList()..sort();
    return AkDialog(
      title: 'Nouveau modèle d\'écriture',
      size: AkDialogSize.l,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              SizedBox(
                width: 140,
                child: AkTextField(controller: _code, label: 'Code', mono: true, textCapitalization: TextCapitalization.characters),
              ),
              SizedBox(
                width: 240,
                child: AkTextField(controller: _label, label: 'Libellé'),
              ),
              SizedBox(
                width: 170,
                child: AkDropdown<String?>(
                  value: _journalType,
                  label: 'Journal',
                  items: [const AkOption(null, 'Tous'), for (final e in Journal.typeLabels.entries) AkOption(e.key, e.value)],
                  onChanged: (v) => setState(() => _journalType = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          for (var i = 0; i < _lines.length; i++) _lineRow(i, rateCodes),
          Align(
            alignment: Alignment.centerLeft,
            child: AkButton.ghost('Ajouter une ligne', icon: Icons.add, onPressed: () => setState(() => _lines.add(_LineDraft()))),
          ),
          if (_error != null) formError(_error!),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary('Enregistrer', onPressed: _save),
      ],
    );
  }

  Widget _lineRow(int i, List<String> rateCodes) {
    final t = context.ak;
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Wrap(
        spacing: AkSpace.s2,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 20,
            height: akControlHeight(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${i + 1}', style: AkText.code.copyWith(color: t.textMuted)),
            ),
          ),
          SizedBox(
            width: 96,
            child: AkTextField(controller: l.account, label: 'Compte', mono: true),
          ),
          AkCheckbox(value: l.thirdParty, onChanged: (v) => setState(() => l.thirdParty = v), label: 'tiers'),
          SizedBox(
            width: 110,
            child: AkDropdown<String>(
              value: l.side,
              label: 'Sens',
              items: const [AkOption('debit', 'Débit'), AkOption('credit', 'Crédit')],
              onChanged: (v) => setState(() => l.side = v ?? 'debit'),
            ),
          ),
          SizedBox(
            width: 150,
            child: AkDropdown<String>(
              value: l.formula,
              label: 'Formule',
              items: const [AkOption('input', 'Saisie'), AkOption('percent_of', '% d\'une ligne'), AkOption('balance', 'Solde')],
              onChanged: (v) => setState(() => l.formula = v ?? 'input'),
            ),
          ),
          if (l.formula == 'percent_of') ...[
            SizedBox(
              width: 72,
              child: AkTextField(controller: l.refLine, label: 'Ligne', keyboardType: TextInputType.number),
            ),
            SizedBox(
              width: 120,
              child: AkDropdown<String?>(
                value: l.rateCode,
                label: 'Taux',
                items: [const AkOption(null, '% fixe'), for (final c in rateCodes) AkOption(c, c)],
                onChanged: (v) => setState(() => l.rateCode = v),
              ),
            ),
            if (l.rateCode == null)
              SizedBox(
                width: 80,
                child: AkTextField(controller: l.percent, label: '%', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
          ],
          SizedBox(
            width: 200,
            child: AkTextField(controller: l.label, label: 'Libellé'),
          ),
          AkIconButton(tooltip: 'Retirer la ligne', icon: Icons.close, onPressed: _lines.length <= 2 ? null : () => setState(() => _lines.removeAt(i))),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final built = TemplateBuilder.build(
      code: _code.text,
      label: _label.text,
      inputs: [
        for (final l in _lines)
          TemplateLineInput(
            account: l.account.text,
            thirdParty: l.thirdParty,
            side: l.side,
            formula: l.formula,
            refLine: l.refLine.text,
            percent: l.percent.text,
            rateCode: l.rateCode,
            label: l.label.text,
          ),
      ],
    );
    if (built.error != null) {
      setState(() => _error = built.error);
      return;
    }
    final lines = built.lines!;
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref
          .read(referencesServiceProvider)
          .saveTemplate(cabinet!.id, widget.entity.id, code: _code.text, label: _label.text, journalType: _journalType, lines: lines);
      ref.invalidate(templatesProvider(widget.entity.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = errorText(e));
    }
  }
}

class _LineDraft {
  _LineDraft({this.formula = 'input', this.side = 'debit'});

  final account = TextEditingController();
  final label = TextEditingController();
  final refLine = TextEditingController(text: '1');
  final percent = TextEditingController();
  bool thirdParty = false;
  String side;
  String formula;
  String? rateCode;
}
