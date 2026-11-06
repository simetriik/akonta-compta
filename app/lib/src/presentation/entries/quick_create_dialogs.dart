import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../application/providers/references_providers.dart';
import '../../application/providers/services.dart';
import '../../application/providers/session_providers.dart';
import '../../application/rules/account_selection.dart';
import '../../domain/reference_models.dart';
import '../../application/providers/entities_providers.dart';
import '../references/references_widgets.dart';
import '../widgets/error_display.dart';

/// Panneau léger de création d'un tiers depuis la saisie : l'essentiel seulement (nom, type, compte collectif, IFU).
/// Renvoie le tiers créé, ou null si l'utilisateur renonce. Le brouillon en cours n'est pas touché.
Future<ThirdParty?> showThirdPartyQuickCreate(BuildContext context, {required String entityId, required String name}) =>
    showDialog<ThirdParty>(context: context, builder: (_) => ThirdPartyQuickCreateDialog(entityId: entityId, initialName: name));

class ThirdPartyQuickCreateDialog extends ConsumerStatefulWidget {
  const ThirdPartyQuickCreateDialog({super.key, required this.entityId, required this.initialName});

  final String entityId;
  final String initialName;

  @override
  ConsumerState<ThirdPartyQuickCreateDialog> createState() => _ThirdPartyQuickCreateState();
}

class _ThirdPartyQuickCreateState extends ConsumerState<ThirdPartyQuickCreateDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName.trim());
  final _taxId = TextEditingController();
  String _type = 'customer';
  String? _collectiveId;
  bool _collectiveTouched = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> collectives, List<ThirdParty> existing) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      final created = await ref
          .read(referencesServiceProvider)
          .saveThirdParty(
            cabinet!.id,
            widget.entityId,
            code: suggestThirdPartyCode(_name.text, existing.map((t) => t.code)),
            name: _name.text,
            type: _type,
            taxId: _taxId.text,
            collectiveAccountIds: [?_collectiveId],
          );
      ref.invalidate(thirdPartiesProvider(widget.entityId));
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entityId)).value ?? const <Account>[];
    final existing = ref.watch(thirdPartiesProvider(widget.entityId)).value ?? const <ThirdParty>[];
    final collectives = AccountSelection.collectives(accounts);
    // Le collectif suit le type tant que l'utilisateur ne l'a pas choisi lui-même.
    if (!_collectiveTouched) _collectiveId = AccountSelection.defaultCollective(collectives, _type)?.id;
    return AkDialog(
      title: 'Créer ce tiers',
      size: AkDialogSize.s,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AkTextField(
              key: const Key('quick-tp-name'),
              controller: _name,
              label: 'Nom',
              autofocus: true,
              validator: (v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null,
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _type,
              label: 'Type',
              items: [for (final e in ThirdParty.typeLabels.entries) AkOption(e.key, e.value)],
              onChanged: (v) => setState(() => _type = v ?? 'other'),
            ),
            const SizedBox(height: AkSpace.s3),
            AkDropdown<String>(
              value: _collectiveId,
              label: 'Compte collectif',
              items: [for (final a in collectives) AkOption(a.id, '${a.code} ${a.label}')],
              onChanged: (v) => setState(() {
                _collectiveId = v;
                _collectiveTouched = true;
              }),
            ),
            const SizedBox(height: AkSpace.s3),
            AkTextField(key: const Key('quick-tp-tax-id'), controller: _taxId, label: 'IFU (facultatif)'),
            if (_error != null) formError(_error!, key: const Key('quick-tp-error')),
          ],
        ),
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: _busy ? null : () => Navigator.pop(context)),
        AkButton.primary('Créer le tiers', key: const Key('quick-tp-submit'), loading: _busy, loadingLabel: 'Création en cours…', onPressed: () => _save(collectives, existing)),
      ],
    );
  }
}

/// Panneau léger de création d'un compte général manquant depuis la saisie. [query] est ce que l'utilisateur a tapé :
/// un numéro (repris tel quel) ou un début d'intitulé.
Future<Account?> showAccountQuickCreate(BuildContext context, {required String entityId, required String query}) =>
    showDialog<Account>(context: context, builder: (_) => AccountQuickCreateDialog(entityId: entityId, query: query));

class AccountQuickCreateDialog extends ConsumerStatefulWidget {
  const AccountQuickCreateDialog({super.key, required this.entityId, required this.query});

  final String entityId;
  final String query;

  @override
  ConsumerState<AccountQuickCreateDialog> createState() => _AccountQuickCreateState();
}

class _AccountQuickCreateState extends ConsumerState<AccountQuickCreateDialog> {
  late final _code = TextEditingController(text: RegExp(r'^[0-9]+$').hasMatch(widget.query.trim()) ? widget.query.trim() : '');
  late final _label = TextEditingController(text: RegExp(r'^[0-9]+$').hasMatch(widget.query.trim()) ? '' : widget.query.trim());
  bool _collective = false;
  bool _busy = false;
  String? _error;
  int _length = 7;

  @override
  void initState() {
    super.initState();
    ref
        .read(entityProvider(widget.entityId).future)
        .then((e) {
          if (mounted) setState(() => _length = e.accountLength);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = errorText(e));
        });
  }

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save(String? padded) async {
    if (_busy) return;
    if (padded == null || _label.text.trim().isEmpty) {
      setState(() => _error = 'Numéro et intitulé requis');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      final created = await ref
          .read(referencesServiceProvider)
          .createAccount(cabinet!.id, widget.entityId, code: padded, label: _label.text.trim(), isCollective: _collective ? true : null);
      ref.invalidate(accountsProvider(widget.entityId));
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padded = padAccountCode(_code.text, _length);
    return AkDialog(
      title: 'Créer ce compte',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkTextField(
            key: const Key('quick-account-code'),
            controller: _code,
            autofocus: _code.text.isEmpty,
            label: 'Numéro',
            helper: padded == null ? 'Chiffres uniquement, $_length au plus' : 'Sera enregistré : $padded',
            mono: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AkSpace.s3),
          AkTextField(key: const Key('quick-account-label'), controller: _label, autofocus: _code.text.isNotEmpty, label: 'Intitulé'),
          const SizedBox(height: AkSpace.s2),
          AkCheckbox(value: _collective, onChanged: (v) => setState(() => _collective = v), label: 'Compte collectif (tiers rattachés)'),
          if (_error != null) formError(_error!, key: const Key('quick-account-error')),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: _busy ? null : () => Navigator.pop(context)),
        AkButton.primary('Créer le compte', key: const Key('quick-account-submit'), loading: _busy, loadingLabel: 'Création en cours…', onPressed: () => _save(padded)),
      ],
    );
  }
}
