import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../domain/entity_models.dart';
import '../widgets/ak_widgets.dart';

/// Fiche entité en 4 blocs (R1 identification, R2 activité, R3 dirigeants [écran dédié], paramètres comptables).
class EntityForm extends StatefulWidget {
  const EntityForm({super.key, this.initial, required this.onSubmit, this.submitLabel = 'Enregistrer', this.canEditAccountingParams = true, this.accountLengthLocked = false});

  final EntityDetail? initial;
  final Future<void> Function(EntityInput input) onSubmit;
  final String submitLabel;
  final bool canEditAccountingParams;
  final bool accountLengthLocked;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _acronym = TextEditingController(text: widget.initial?.acronym);
  late final _legalForm = TextEditingController(text: widget.initial?.legalForm);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _taxId = TextEditingController(text: widget.initial?.taxId);
  late final _rccm = TextEditingController(text: widget.initial?.tradeRegister);
  late final _taxRegime = TextEditingController(text: widget.initial?.taxRegime);
  late final _incorporation = TextEditingController(text: Fmt.date(widget.initial?.incorporationDate));
  late final _establishments = TextEditingController(text: widget.initial?.establishmentsCount?.toString() ?? '');
  late final _mainActivity = TextEditingController(text: widget.initial?.mainActivity);
  late final _secondary = TextEditingController(text: widget.initial?.secondaryActivities.join(', ') ?? '');
  late final _activityCode = TextEditingController(text: widget.initial?.activityCode);
  late final _accountLength = TextEditingController(text: widget.initial?.accountLength.toString() ?? '');
  late String? _controlType = widget.initial?.controlType;
  late String? _controlOrigin = widget.initial?.controlOrigin;
  late bool _monthlyLock = widget.initial?.monthlyLockEnabled ?? false;
  late String _country = widget.initial?.countryCode ?? 'BJ';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final inc = _incorporation.text.trim().isEmpty ? null : Fmt.parseDate(_incorporation.text);
    if (_incorporation.text.trim().isNotEmpty && inc == null) {
      setState(() => _error = 'Date de création invalide (jj/mm/aaaa)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(EntityInput(
        name: _name.text,
        acronym: _acronym.text,
        legalForm: _legalForm.text,
        address: _address.text,
        countryCode: _country,
        taxId: _taxId.text,
        tradeRegister: _rccm.text,
        taxRegime: _taxRegime.text,
        incorporationDate: inc,
        establishmentsCount: int.tryParse(_establishments.text.trim()),
        controlType: _controlType,
        controlOrigin: _controlOrigin,
        mainActivity: _mainActivity.text,
        secondaryActivities: _secondary.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        activityCode: _activityCode.text,
        accountLength: widget.canEditAccountingParams && !widget.accountLengthLocked ? int.tryParse(_accountLength.text.trim()) : null,
        monthlyLockEnabled: widget.canEditAccountingParams ? _monthlyLock : null,
      ));
    } catch (e) {
      setState(() => _error = _frenchDbError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _frenchDbError(Object e) {
    final m = e.toString();
    if (m.contains('entities_tax_id_unique')) return 'Cet IFU existe déjà dans le cabinet.';
    if (m.contains('entities_trade_register_unique')) return 'Ce RCCM existe déjà dans le cabinet.';
    return 'Enregistrement impossible : $m';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    final t = context.ak;
    return Form(
      key: _form,
      child: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          _Section(title: 'Identification (R1)', children: [
          TextFormField(controller: _name, key: const Key('entity-name'), decoration: const InputDecoration(labelText: 'Dénomination *'), validator: EntityInput.validateName),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: _acronym, decoration: const InputDecoration(labelText: 'Sigle'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _legalForm, decoration: const InputDecoration(labelText: 'Forme juridique'))),
          ]),
          const SizedBox(height: 8),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse du siège')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: _taxId, key: const Key('entity-tax-id'), decoration: const InputDecoration(labelText: 'IFU'), validator: EntityInput.validateTaxId)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _rccm, decoration: const InputDecoration(labelText: 'RCCM'))),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _country,
                decoration: const InputDecoration(labelText: 'Pays'),
                items: const [
                  DropdownMenuItem(value: 'BJ', child: Text('Bénin')),
                  DropdownMenuItem(value: 'TG', child: Text('Togo')),
                  DropdownMenuItem(value: 'CI', child: Text('Côte d\'Ivoire')),
                  DropdownMenuItem(value: 'SN', child: Text('Sénégal')),
                  DropdownMenuItem(value: 'BF', child: Text('Burkina Faso')),
                  DropdownMenuItem(value: 'NE', child: Text('Niger')),
                  DropdownMenuItem(value: 'ML', child: Text('Mali')),
                ],
                onChanged: (v) => setState(() => _country = v ?? 'BJ'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: _taxRegime, decoration: const InputDecoration(labelText: 'Régime fiscal'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _incorporation, decoration: const InputDecoration(labelText: 'Date de création (jj/mm/aaaa)'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _establishments, decoration: const InputDecoration(labelText: 'Nombre d\'établissements'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _controlType,
                decoration: const InputDecoration(labelText: 'Contrôle'),
                items: const [DropdownMenuItem(value: 'private', child: Text('Privé')), DropdownMenuItem(value: 'public', child: Text('Public'))],
                onChanged: (v) => setState(() => _controlType = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _controlOrigin,
                decoration: const InputDecoration(labelText: 'Origine'),
                items: const [DropdownMenuItem(value: 'national', child: Text('National')), DropdownMenuItem(value: 'foreign', child: Text('Étranger'))],
                onChanged: (v) => setState(() => _controlOrigin = v),
              ),
            ),
          ]),
          ]),
          const SizedBox(height: AkSpace.s4),
          _Section(title: 'Activité (R2)', children: [
          TextFormField(controller: _mainActivity, decoration: const InputDecoration(labelText: 'Activité principale')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 2, child: TextFormField(controller: _secondary, decoration: const InputDecoration(labelText: 'Activités secondaires (séparées par des virgules)'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _activityCode, decoration: const InputDecoration(labelText: 'Code de nomenclature'))),
          ]),
          ]),
          const SizedBox(height: AkSpace.s4),
          _Section(title: 'Paramètres comptables', children: [
          Row(children: [
            SizedBox(
              width: 220,
              child: TextFormField(
                controller: _accountLength,
                enabled: widget.canEditAccountingParams && !widget.accountLengthLocked,
                decoration: InputDecoration(labelText: 'Longueur des comptes', helperText: widget.accountLengthLocked ? 'Figée : un exercice existe' : 'Défaut du cabinet si vide'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final n = int.tryParse(v!.trim());
                  return (n == null || n < 6 || n > 12) ? 'Entre 6 et 12 chiffres' : null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                value: _monthlyLock,
                onChanged: widget.canEditAccountingParams ? (v) => setState(() => _monthlyLock = v) : null,
                title: const Text('Verrouillage mensuel par le chef de mission'),
                subtitle: const Text('Système normal SYSCOHADA · FCFA'),
                ),
              ),
            ),
          ]),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: AkSpace.s3), child: Text(_error!, key: const Key('entity-error'), style: AkText.body.copyWith(color: t.danger))),
          const SizedBox(height: AkSpace.s4),
          Align(alignment: Alignment.centerRight, child: FilledButton(key: const Key('entity-submit'), onPressed: _busy ? null : _submit, child: Text(widget.submitLabel))),
        ],
      ),
    );
  }
}

/// Bloc de formulaire : carte à filet avec titre de section.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AkText.heading.copyWith(color: context.ak.text)),
        const SizedBox(height: AkSpace.s3),
        ...children,
      ]),
    );
  }
}
