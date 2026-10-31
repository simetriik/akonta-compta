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

class JournalsTab extends ConsumerWidget {
  const JournalsTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final journals = ref.watch(journalsProvider(entity.id));
    return Column(
      children: [
        ListToolbar(
          action: AkButton.primary(
            'Nouveau journal',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => JournalDialog(entity: entity),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: journals,
            onRetry: () => ref.invalidate(journalsProvider(entity.id)),
            builder: (list) => list.isEmpty
                ? const AkEmptyState('Aucun journal.')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final j = list[i];
                      return ListRow(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => JournalDialog(entity: entity, initial: j),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                j.code,
                                style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    j.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AkText.table.copyWith(
                                      color: j.isActive ? t.text : t.textMuted,
                                      decoration: j.isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    [Journal.typeLabels[j.type] ?? j.type, if (j.treasuryAccountCode != null) 'compte ${j.treasuryAccountCode}'].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AkText.caption.copyWith(color: t.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (!j.isActive)
                              const Padding(
                                padding: EdgeInsets.only(left: AkSpace.s2),
                                child: InactiveBadge(),
                              ),
                            if (j.type == 'opening')
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: AkSpace.s2),
                                child: Tooltip(message: 'Journal imposé', child: Icon(Icons.lock_outline, size: 20)),
                              )
                            else
                              AkSwitch(
                                value: j.isActive,
                                onChanged: (v) async {
                                  await ref.read(referencesServiceProvider).setJournalActive(j.id, v);
                                  ref.invalidate(journalsProvider(entity.id));
                                },
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

class JournalDialog extends ConsumerStatefulWidget {
  const JournalDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final Journal? initial;

  @override
  ConsumerState<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends ConsumerState<JournalDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _label = TextEditingController(text: widget.initial?.label);
  late String _type = widget.initial?.type ?? 'misc';
  late String? _account = widget.initial?.treasuryAccountId;
  bool _accountMissing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[])
        .where((a) => a.classNo == 5 && a.allowPosting && a.isActive)
        .toList();
    final treasury = _type == 'bank' || _type == 'cash';
    return AkDialog(
      title: widget.initial == null ? 'Nouveau journal' : 'Journal ${widget.initial!.code}',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: AkTextField(
                    controller: _code,
                    enabled: widget.initial == null,
                    label: 'Code',
                    mono: true,
                    validator: validateJournalCode,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _label, label: 'Libellé', validator: (v) => (v ?? '').trim().isEmpty ? 'Libellé requis' : null),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _type,
              label: 'Type',
              items: [for (final e in Journal.typeLabels.entries.where((e) => e.key != 'opening')) AkOption(e.key, e.value)],
              onChanged: widget.initial == null ? (v) => setState(() => _type = v ?? 'misc') : null,
            ),
            if (treasury) ...[
              const SizedBox(height: AkSpace.s3),
              AkAccountField(
                accounts: accounts,
                selected: accounts.where((a) => a.id == _account).firstOrNull,
                label: 'Compte de trésorerie (classe 5)',
                invalid: _accountMissing,
                helper: _accountMissing ? 'Compte requis pour un journal de trésorerie' : null,
                onSelected: (a) => setState(() {
                  _account = a.id;
                  _accountMissing = false;
                }),
                onCleared: () => _account = null,
              ),
            ],
            if (_error != null) formError(_error!),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: () async {
            final formOk = _form.currentState!.validate();
            if (treasury && _account == null) setState(() => _accountMissing = true);
            if (!formOk || (treasury && _account == null)) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(referencesServiceProvider)
                  .saveJournal(
                    cabinet!.id,
                    widget.entity.id,
                    id: widget.initial?.id,
                    code: _code.text,
                    label: _label.text,
                    type: _type,
                    treasuryAccountId: treasury ? _account : null,
                  );
              ref.invalidate(journalsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = errorText(e));
            }
          },
        ),
      ],
    );
  }
}
