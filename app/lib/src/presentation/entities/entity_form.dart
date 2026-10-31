import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';

/// Fiche entité en 4 blocs (R1 identification, R2 activité, R3 dirigeants [écran dédié], paramètres comptables).
class EntityForm extends StatefulWidget {
  const EntityForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.submitLabel = 'Enregistrer',
    this.canEditAccountingParams = true,
    this.accountLengthLocked = false,
  });

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
  late String _system = widget.initial?.accountingSystem ?? 'normal';
  bool _systemTouched = false;
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
      await widget.onSubmit(
        EntityInput(
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
          accountingSystem: widget.initial == null ? _system : null,
          accountLength: widget.canEditAccountingParams && !widget.accountLengthLocked ? int.tryParse(_accountLength.text.trim()) : null,
          monthlyLockEnabled: widget.canEditAccountingParams ? _monthlyLock : null,
        ),
      );
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final canEditLength = widget.canEditAccountingParams && !widget.accountLengthLocked;
    return Form(
      key: _form,
      child: ListView(
        padding: EdgeInsets.all(akPageMargin(context)),
        children: [
          _Section(
            title: 'Identification (R1)',
            children: [
              AkTextField(key: const Key('entity-name'), controller: _name, label: 'Dénomination', required: true, validator: EntityInput.validateName),
              _FieldRow(
                children: [
                  AkTextField(controller: _acronym, label: 'Sigle'),
                  AkTextField(
                    key: const Key('entity-legal-form'),
                    controller: _legalForm,
                    label: 'Forme juridique',
                    onChanged: (v) {
                      final suggested = EntityInput.suggestAccountingSystem(v);
                      if (widget.initial == null && !_systemTouched && suggested != null && suggested != _system) setState(() => _system = suggested);
                    },
                  ),
                ],
              ),
              AkTextField(controller: _address, label: 'Adresse du siège'),
              _FieldRow(
                children: [
                  AkTextField(key: const Key('entity-tax-id'), controller: _taxId, label: 'IFU', validator: EntityInput.validateTaxId),
                  AkTextField(controller: _rccm, label: 'RCCM'),
                  AkDropdown<String>(
                    label: 'Pays',
                    value: _country,
                    items: const [
                      AkOption('BJ', 'Bénin'),
                      AkOption('TG', 'Togo'),
                      AkOption('CI', 'Côte d\'Ivoire'),
                      AkOption('SN', 'Sénégal'),
                      AkOption('BF', 'Burkina Faso'),
                      AkOption('NE', 'Niger'),
                      AkOption('ML', 'Mali'),
                    ],
                    onChanged: (v) => setState(() => _country = v ?? 'BJ'),
                  ),
                ],
              ),
              _FieldRow(
                children: [
                  AkTextField(controller: _taxRegime, label: 'Régime fiscal'),
                  AkDateField(controller: _incorporation, label: 'Date de création (jj/mm/aaaa)'),
                  AkTextField(controller: _establishments, label: 'Nombre d\'établissements', keyboardType: TextInputType.number),
                ],
              ),
              _FieldRow(
                children: [
                  AkDropdown<String>(
                    label: 'Contrôle',
                    value: _controlType,
                    items: const [AkOption('private', 'Privé'), AkOption('public', 'Public')],
                    onChanged: (v) => setState(() => _controlType = v),
                  ),
                  AkDropdown<String>(
                    label: 'Origine',
                    value: _controlOrigin,
                    items: const [AkOption('national', 'National'), AkOption('foreign', 'Étranger')],
                    onChanged: (v) => setState(() => _controlOrigin = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          _Section(
            title: 'Activité (R2)',
            children: [
              AkTextField(controller: _mainActivity, label: 'Activité principale'),
              _FieldRow(
                flexes: const [2, 1],
                children: [
                  AkTextField(controller: _secondary, label: 'Activités secondaires (séparées par des virgules)'),
                  AkTextField(controller: _activityCode, label: 'Code de nomenclature'),
                ],
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          _Section(
            title: 'Paramètres comptables',
            children: [
              AkDropdown<String>(
                key: const Key('entity-accounting-system'),
                label: 'Référentiel comptable',
                value: _system,
                items: const [
                  AkOption('normal', 'Système normal SYSCOHADA (entreprises)'),
                  AkOption('sycebnl', 'SYCEBNL (associations et entités à but non lucratif)'),
                ],
                helper: widget.initial == null ? 'Choix définitif : détermine le plan de comptes et les modèles' : 'Figé à la création',
                onChanged: widget.initial != null
                    ? null
                    : (v) => setState(() {
                          _system = v ?? 'normal';
                          _systemTouched = true;
                        }),
              ),
              _FieldRow(
                children: [
                  AkTextField(
                    controller: _accountLength,
                    label: 'Longueur des comptes',
                    enabled: canEditLength,
                    helper: widget.accountLengthLocked ? 'Figée : un exercice existe' : 'Défaut du cabinet si vide',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = int.tryParse(v!.trim());
                      return (n == null || n < 6 || n > 12) ? 'Entre 6 et 12 chiffres' : null;
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AkSwitch(
                        value: _monthlyLock,
                        onChanged: widget.canEditAccountingParams ? (v) => setState(() => _monthlyLock = v) : null,
                        label: 'Verrouillage mensuel par le chef de mission',
                      ),
                      Text(_system == 'sycebnl' ? 'SYCEBNL · FCFA' : 'Système normal SYSCOHADA · FCFA', style: AkText.caption.copyWith(color: t.textMuted)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s3),
              child: AkBanner(
                kind: AkBannerKind.danger,
                child: Text(_error!, key: const Key('entity-error')),
              ),
            ),
          const SizedBox(height: AkSpace.s4),
          Align(
            alignment: Alignment.centerRight,
            child: AkButton.primary(widget.submitLabel, key: const Key('entity-submit'), loading: _busy, onPressed: _submit),
          ),
        ],
      ),
    );
  }
}

/// Ligne de champs côte à côte (empilés sur mobile), avec l'espacement vertical entre lignes.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children, this.flexes});

  final List<Widget> children;
  final List<int>? flexes;

  @override
  Widget build(BuildContext context) {
    final compact = akIsCompact(context);
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s3),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: AkSpace.s3), children[i]],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: AkSpace.s3),
                  Expanded(flex: flexes?[i] ?? 1, child: children[i]),
                ],
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [AkSectionTitle(title), ...children]),
    );
  }
}
