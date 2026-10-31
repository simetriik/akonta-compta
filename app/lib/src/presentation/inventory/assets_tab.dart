import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../../application/providers/inventory_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../domain/inventory_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';
import 'inventory_widgets.dart';

class AssetsTab extends ConsumerWidget {
  const AssetsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final assets = ref.watch(fixedAssetsProvider(entity.id));
    return AsyncView(
      value: assets,
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer les dotations',
                icon: Icons.auto_awesome,
                onPressed: () =>
                    runGeneration(context, ref, () => ref.read(inventoryServiceProvider).generateDepreciation(entity.id, fy.id), 'Dotations ${fy.label}'),
              ),
              AkButton.secondary(
                'Immobilisation',
                icon: Icons.add,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AssetDialog(entity: entity),
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkTable<FixedAsset>(
            rows: list,
            minWidth: 800,
            emptyMessage: 'Aucune immobilisation. Reprenez l\'existant (valeur brute + amortissements cumulés) ou enregistrez les acquisitions.',
            columns: [
              AkColumn<FixedAsset>(
                label: 'Code',
                width: 96,
                cell: (context, a) => Text(
                  a.code,
                  style: AkText.code.copyWith(fontWeight: FontWeight.w600, color: t.text),
                ),
              ),
              AkColumn<FixedAsset>(
                label: 'Désignation',
                flex: 2,
                cell: (context, a) => Text(
                  a.designation,
                  style: AkText.body.copyWith(
                    color: a.status == 'in_service' ? t.text : t.textMuted,
                    decoration: a.status == 'in_service' ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
              AkColumn<FixedAsset>(
                label: 'Détail',
                flex: 4,
                cell: (context, a) => Text(
                  '${a.assetAccountCode} · mise en service ${Fmt.date(a.serviceDate)} · ${Fmt.fcfa(a.grossValue, showZero: true)} FCFA · ${a.durationMonths ~/ 12} ans ${a.method == 'declining' ? 'dégressif' : 'linéaire'}${a.priorDepreciation > 0 ? ' · amortissements antérieurs ${Fmt.fcfa(a.priorDepreciation)}' : ''} · ${a.statusLabel}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ),
              AkColumn<FixedAsset>(
                label: '',
                width: 48,
                cell: (context, a) => PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'plan') {
                      showDialog(
                        context: context,
                        builder: (_) => PlanDialog(asset: a),
                      );
                    } else if (v == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => AssetDialog(entity: entity, initial: a),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (_) => DisposalDialog(entity: entity, asset: a, scrap: v == 'scrap'),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'plan', child: Text('Tableau d\'amortissement')),
                    if (a.status == 'in_service') const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    if (a.status == 'in_service') const PopupMenuItem(value: 'dispose', child: Text('Cession…')),
                    if (a.status == 'in_service') const PopupMenuItem(value: 'scrap', child: Text('Mise au rebut…')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AssetDialog extends ConsumerStatefulWidget {
  const AssetDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final FixedAsset? initial;

  @override
  ConsumerState<AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends ConsumerState<AssetDialog> {
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _designation = TextEditingController(text: widget.initial?.designation);
  late final _acq = TextEditingController(text: Fmt.date(widget.initial?.acquisitionDate ?? DateTime.now()));
  late final _service = TextEditingController(text: Fmt.date(widget.initial?.serviceDate ?? DateTime.now()));
  late final _gross = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.grossValue}');
  late final _salvage = TextEditingController(text: '${widget.initial?.salvageValue ?? 0}');
  late final _months = TextEditingController(text: '${widget.initial?.durationMonths ?? 60}');
  late final _prior = TextEditingController(text: '${widget.initial?.priorDepreciation ?? 0}');
  late final _coef = TextEditingController(text: '${widget.initial?.decliningCoefficient ?? 1.5}');
  late String _method = widget.initial?.method ?? 'linear';
  String? _accountId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[])
        .where((a) => a.classNo == 2 && a.allowPosting && a.isActive && !a.code.startsWith('28') && !a.code.startsWith('29'))
        .toList();
    return AkDialog(
      title: widget.initial == null ? 'Nouvelle immobilisation' : 'Immobilisation ${widget.initial!.code}',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: AkTextField(controller: _code, enabled: widget.initial == null, label: 'Code'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkTextField(controller: _designation, label: 'Désignation'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          if (widget.initial == null)
            AkAccountField(label: 'Compte d\'immobilisation (classe 2, ex. 2451)', accounts: accounts, onSelected: (a) => _accountId = a.id),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkDateField(controller: _acq, label: 'Acquisition'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _service, label: 'Mise en service'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkAmountField(controller: _gross, label: 'Valeur brute', showCurrency: false),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkTextField(controller: _months, label: 'Durée (mois)', keyboardType: TextInputType.number),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDropdown<String>(
                  label: 'Méthode',
                  value: _method,
                  items: const [AkOption('linear', 'Linéaire'), AkOption('declining', 'Dégressif')],
                  onChanged: (v) => setState(() => _method = v ?? 'linear'),
                ),
              ),
              if (_method == 'declining') ...[
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: AkTextField(controller: _coef, label: 'Coefficient', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _salvage, label: 'Valeur résiduelle', showCurrency: false),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkAmountField(controller: _prior, label: 'Amortissements antérieurs (reprise)', showCurrency: false),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          'Enregistrer',
          onPressed: () async {
            final acq = Fmt.parseDate(_acq.text),
                svc = Fmt.parseDate(_service.text),
                gross = Fmt.parseAmount(_gross.text),
                months = int.tryParse(_months.text.trim());
            if (_code.text.trim().isEmpty ||
                _designation.text.trim().isEmpty ||
                acq == null ||
                svc == null ||
                gross == null ||
                gross <= 0 ||
                months == null ||
                months <= 0 ||
                (widget.initial == null && _accountId == null)) {
              setState(() => _error = 'Code, désignation, compte, dates, valeur brute et durée requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(inventoryServiceProvider).saveAsset(cabinet!.id, widget.entity.id, {
                if (widget.initial == null) 'code': _code.text.trim(),
                'designation': _designation.text.trim(),
                if (widget.initial == null) 'asset_account_id': _accountId,
                'acquisition_date': acq.toIso8601String().substring(0, 10),
                'service_date': svc.toIso8601String().substring(0, 10),
                'gross_value': gross,
                'salvage_value': Fmt.parseAmount(_salvage.text) ?? 0,
                'duration_months': months,
                'method': _method,
                'declining_coefficient': _method == 'declining' ? double.tryParse(_coef.text.replaceAll(',', '.')) ?? 1.5 : null,
                'prior_depreciation': Fmt.parseAmount(_prior.text) ?? 0,
              }, id: widget.initial?.id);
              ref.invalidate(fixedAssetsProvider(widget.entity.id));
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

class PlanDialog extends ConsumerWidget {
  const PlanDialog({super.key, required this.asset});

  final FixedAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AkDialog(
      title: 'Tableau d\'amortissement — ${asset.code}',
      size: AkDialogSize.m,
      content: FutureBuilder<List<PlanRow>>(
        future: ref.read(inventoryServiceProvider).plan(asset.id),
        builder: (_, snap) {
          if (snap.hasError) return AkErrorMessage('Erreur : ${snap.error}');
          if (!snap.hasData) return const SizedBox(height: 160, child: AkLoading());
          return AkTable<PlanRow>(
            rows: snap.data!,
            minWidth: 580,
            columns: [
              AkColumn<PlanRow>.text(label: 'Exercice', width: 72, text: (r) => '${r.periodStart.year}'),
              AkColumn<PlanRow>.text(label: 'Période', flex: 2, text: (r) => '${Fmt.date(r.periodStart)} → ${Fmt.date(r.periodEnd)}'),
              AkColumn<PlanRow>.text(label: 'Taux', width: 72, numeric: true, text: (r) => '${(r.rate * 100).toStringAsFixed(2)} %'),
              AkColumn<PlanRow>.text(label: 'Dotation', numeric: true, text: (r) => Fmt.fcfa(r.charge, showZero: true)),
              AkColumn<PlanRow>.text(label: 'Cumul', numeric: true, text: (r) => Fmt.fcfa(r.cumulated, showZero: true)),
              AkColumn<PlanRow>.text(label: 'VNC', numeric: true, text: (r) => Fmt.fcfa(r.netBookValue, showZero: true)),
            ],
          );
        },
      ),
      actions: [AkButton.secondary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}

class DisposalDialog extends ConsumerStatefulWidget {
  const DisposalDialog({super.key, required this.entity, required this.asset, required this.scrap});

  final EntitySummary entity;
  final FixedAsset asset;
  final bool scrap;

  @override
  ConsumerState<DisposalDialog> createState() => _DisposalDialogState();
}

class _DisposalDialogState extends ConsumerState<DisposalDialog> {
  final _date = TextEditingController(text: Fmt.date(DateTime.now()));
  final _price = TextEditingController(text: '0');
  String? _counterpart;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[])
        .where((a) => a.allowPosting && a.isActive && (a.code.startsWith('485') || a.classNo == 5 || a.code.startsWith('411')))
        .toList();
    return AkDialog(
      title: '${widget.scrap ? 'Mise au rebut' : 'Cession'} de ${widget.asset.code}',
      size: AkDialogSize.s,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDateField(controller: _date, label: 'Date'),
          if (!widget.scrap) ...[
            const SizedBox(height: AkSpace.s2),
            AkAmountField(controller: _price, label: 'Prix de cession (FCFA)', showCurrency: false),
            const SizedBox(height: AkSpace.s2),
            AkAccountField(
              label: 'Contrepartie (485 créances sur cessions, banque…)',
              accounts: accounts,
              onSelected: (a) => _counterpart = a.id,
              onCleared: () => _counterpart = null,
            ),
          ],
          const SizedBox(height: AkSpace.s2),
          Text(
            'Génère la dotation complémentaire, la sortie de l\'actif (81 / 28 / 2x) et le produit de cession (82), en brouillard.',
            style: AkText.caption.copyWith(color: context.ak.textMuted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(
          widget.scrap ? 'Mettre au rebut' : 'Céder',
          onPressed: () async {
            final d = Fmt.parseDate(_date.text);
            if (d == null) return;
            try {
              await ref
                  .read(inventoryServiceProvider)
                  .disposeAsset(widget.asset.id, date: d, price: Fmt.parseAmount(_price.text) ?? 0, counterpartAccountId: _counterpart, scrap: widget.scrap);
              ref.invalidate(fixedAssetsProvider(widget.entity.id));
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
