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

class ThirdPartiesTab extends ConsumerStatefulWidget {
  const ThirdPartiesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<ThirdPartiesTab> createState() => _ThirdPartiesTabState();
}

class _ThirdPartiesTabState extends ConsumerState<ThirdPartiesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final tps = ref.watch(thirdPartiesProvider(widget.entity.id));
    return Column(
      children: [
        ListToolbar(
          filters: [ToolbarSearchField(hint: 'Code ou nom', onChanged: (v) => setState(() => _search = v.trim().toLowerCase()))],
          action: AkButton.primary(
            'Nouveau tiers',
            icon: Icons.add,
            dense: true,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ThirdPartyDialog(entity: widget.entity),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: tps,
            onRetry: () => ref.invalidate(thirdPartiesProvider(widget.entity.id)),
            builder: (list) {
              final filtered = list.where((p) => _search.isEmpty || p.code.toLowerCase().contains(_search) || p.name.toLowerCase().contains(_search)).toList();
              if (filtered.isEmpty) return const AkEmptyState('Aucun tiers.');
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return ListRow(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ThirdPartyDialog(entity: widget.entity, initial: p),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            p.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AkText.table.copyWith(
                                  color: p.isActive ? t.text : t.textMuted,
                                  decoration: p.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                [
                                  ThirdParty.typeLabels[p.type] ?? p.type,
                                  if (p.collectiveCodes.isNotEmpty) 'collectifs ${p.collectiveCodes.join(', ')}',
                                  if (p.taxId != null) 'IFU ${p.taxId}',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AkText.caption.copyWith(color: t.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (!p.isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: AkSpace.s2),
                            child: InactiveBadge(),
                          ),
                        AkSwitch(
                          value: p.isActive,
                          onChanged: (v) async {
                            await ref.read(referencesServiceProvider).setThirdPartyActive(p.id, v);
                            ref.invalidate(thirdPartiesProvider(widget.entity.id));
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ThirdPartyDialog extends ConsumerStatefulWidget {
  const ThirdPartyDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final ThirdParty? initial;

  @override
  ConsumerState<ThirdPartyDialog> createState() => _ThirdPartyDialogState();
}

class _ThirdPartyDialogState extends ConsumerState<ThirdPartyDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _taxId = TextEditingController(text: widget.initial?.taxId);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _email = TextEditingController(text: widget.initial?.email);
  late String _type = widget.initial?.type ?? 'customer';
  final Set<String> _collectives = {};
  bool _loaded = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[];
    final collectives = accounts.where((a) => a.isCollective && a.allowPosting && a.isActive).toList();
    if (!_loaded && widget.initial != null && accounts.isNotEmpty) {
      _collectives.addAll(collectives.where((a) => widget.initial!.collectiveCodes.contains(a.code)).map((a) => a.id));
      _loaded = true;
    }
    return AkDialog(
      title: widget.initial == null ? 'Nouveau tiers' : 'Tiers ${widget.initial!.code}',
      size: AkDialogSize.m,
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
                  width: 140,
                  child: AkTextField(
                    controller: _code,
                    key: const Key('tp-code'),
                    enabled: widget.initial == null,
                    label: 'Code',
                    mono: true,
                    validator: validateThirdPartyCode,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(
                    controller: _name,
                    key: const Key('tp-name'),
                    label: 'Nom',
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _type,
              label: 'Type',
              items: [for (final e in ThirdParty.typeLabels.entries) AkOption(e.key, e.value)],
              onChanged: (v) => setState(() => _type = v ?? 'other'),
            ),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _taxId, label: 'IFU'),
            const SizedBox(height: AkSpace.s3),
            AkTextField(controller: _address, label: 'Adresse'),
            const SizedBox(height: AkSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AkTextField(controller: _phone, label: 'Téléphone', keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s3),
            Text('Comptes collectifs de rattachement', style: AkText.bodyStrong.copyWith(color: context.ak.text)),
            const SizedBox(height: AkSpace.s2),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s1,
              children: [
                for (final a in collectives)
                  FilterChip(
                    label: Text('${a.code} ${a.label}'),
                    selected: _collectives.contains(a.id),
                    onSelected: (v) => setState(() => v ? _collectives.add(a.id) : _collectives.remove(a.id)),
                  ),
              ],
            ),
            if (_error != null) formError(_error!),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          key: const Key('tp-submit'),
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(referencesServiceProvider)
                  .saveThirdParty(
                    cabinet!.id,
                    widget.entity.id,
                    id: widget.initial?.id,
                    code: _code.text,
                    name: _name.text,
                    type: _type,
                    taxId: _taxId.text,
                    address: _address.text,
                    phone: _phone.text,
                    email: _email.text,
                    collectiveAccountIds: _collectives.toList(),
                  );
              ref.invalidate(thirdPartiesProvider(widget.entity.id));
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
