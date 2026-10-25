import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/entities_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

String frenchRpcError(Object e) => RegExp(r'message: ([^,}]+)').firstMatch(e.toString())?.group(1) ?? e.toString();

/// Travaux d'inventaire (§10.8) : immobilisations, stocks, provisions, régularisations, écarts de conversion.
/// Toutes les générations produisent des brouillards « générée » à valider dans Saisie.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _InventoryBody(entity: entity));
}

class _InventoryBody extends ConsumerWidget {
  const _InventoryBody({required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fys = ref.watch(fiscalYearsProvider(entity.id));
    return AsyncView(
      value: fys,
      builder: (list) {
        final fy = list.where((f) => f.status != 'closed').lastOrNull ?? list.lastOrNull;
        if (fy == null) return const Center(child: Text('Aucun exercice.'));
        return DefaultTabController(
          length: 5,
          child: Column(children: [
            Material(
              color: Colors.white,
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [Text('Travaux d\'inventaire — exercice ${fy.label}', style: Theme.of(context).textTheme.titleMedium), const Spacer(), const Text('Les écritures générées arrivent en brouillard, marquées « générée ».', style: TextStyle(fontSize: 12))])),
                const TabBar(isScrollable: true, tabs: [Tab(text: 'Immobilisations'), Tab(text: 'Stocks'), Tab(text: 'Provisions'), Tab(text: 'Régularisations'), Tab(text: 'Écarts de conversion')]),
              ]),
            ),
            Expanded(child: TabBarView(children: [AssetsTab(entity: entity, fy: fy), StocksTab(entity: entity, fy: fy), ProvisionsTab(entity: entity, fy: fy), AccrualsTab(entity: entity, fy: fy), FxTab(entity: entity, fy: fy)])),
          ]),
        );
      },
    );
  }
}

Future<void> runGeneration(BuildContext context, WidgetRef ref, Future<String?> Function() action, String successLabel) async {
  try {
    final id = await action();
    ref.invalidate(entityDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(id == null ? 'Rien à générer.' : '$successLabel : brouillard créé.'),
      action: id == null ? null : SnackBarAction(label: 'Ouvrir', onPressed: () => context.go('/saisie/$id')),
    ));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
  }
}

// ---------------------------------------------------------------------------
class AssetsTab extends ConsumerWidget {
  const AssetsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(fixedAssetsProvider(entity.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(heroTag: 'gen-dep', onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateDepreciation(entity.id, fy.id), 'Dotations ${fy.label}'), icon: const Icon(Icons.auto_awesome), label: const Text('Générer les dotations')),
        const SizedBox(width: 12),
        FloatingActionButton.extended(heroTag: 'new-asset', onPressed: () => showDialog(context: context, builder: (_) => AssetDialog(entity: entity)), icon: const Icon(Icons.add), label: const Text('Immobilisation')),
      ]),
      body: AsyncView(
        value: assets,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(children: [
                for (final a in list)
                  ListTile(
                    leading: SizedBox(width: 80, child: Text(a.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                    title: Text(a.designation, style: TextStyle(decoration: a.status == 'in_service' ? null : TextDecoration.lineThrough)),
                    subtitle: Text('${a.assetAccountCode} · mise en service ${Fmt.date(a.serviceDate)} · ${Fmt.fcfa(a.grossValue, showZero: true)} FCFA · ${a.durationMonths ~/ 12} ans ${a.method == 'declining' ? 'dégressif' : 'linéaire'}${a.priorDepreciation > 0 ? ' · amortissements antérieurs ${Fmt.fcfa(a.priorDepreciation)}' : ''} · ${a.statusLabel}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'plan') {
                          showDialog(context: context, builder: (_) => PlanDialog(asset: a));
                        } else if (v == 'edit') {
                          showDialog(context: context, builder: (_) => AssetDialog(entity: entity, initial: a));
                        } else {
                          showDialog(context: context, builder: (_) => DisposalDialog(entity: entity, asset: a, scrap: v == 'scrap'));
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
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucune immobilisation. Reprenez l\'existant (valeur brute + amortissements cumulés) ou enregistrez les acquisitions.')),
              ]),
            ),
          ],
        ),
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
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.classNo == 2 && a.allowPosting && a.isActive && !a.code.startsWith('28') && !a.code.startsWith('29')).toList();
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouvelle immobilisation' : 'Immobilisation ${widget.initial!.code}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(width: 120, child: TextField(controller: _code, enabled: widget.initial == null, decoration: const InputDecoration(labelText: 'Code'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _designation, decoration: const InputDecoration(labelText: 'Désignation'))),
            ]),
            const SizedBox(height: 8),
            if (widget.initial == null)
              Autocomplete<Account>(
                displayStringForOption: (a) => '${a.code} ${a.label}',
                optionsBuilder: (v) => accounts.where((a) => v.text.isNotEmpty && (a.code.startsWith(v.text) || a.label.toLowerCase().contains(v.text.toLowerCase()))).take(12),
                onSelected: (a) => _accountId = a.id,
                fieldViewBuilder: (c, ctrl, f, _) => TextField(controller: ctrl, focusNode: f, onChanged: (v) => _accountId = matchAccountCode(accounts, v)?.id ?? _accountId, decoration: const InputDecoration(labelText: 'Compte d\'immobilisation (classe 2, ex. 2451)')),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _acq, decoration: const InputDecoration(labelText: 'Acquisition'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _service, decoration: const InputDecoration(labelText: 'Mise en service'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _gross, decoration: const InputDecoration(labelText: 'Valeur brute'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _months, decoration: const InputDecoration(labelText: 'Durée (mois)'))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _method, decoration: const InputDecoration(labelText: 'Méthode'), items: const [DropdownMenuItem(value: 'linear', child: Text('Linéaire')), DropdownMenuItem(value: 'declining', child: Text('Dégressif'))], onChanged: (v) => setState(() => _method = v ?? 'linear'))),
              const SizedBox(width: 8),
              if (_method == 'declining') Expanded(child: TextField(controller: _coef, decoration: const InputDecoration(labelText: 'Coefficient'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _salvage, decoration: const InputDecoration(labelText: 'Valeur résiduelle'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _prior, decoration: const InputDecoration(labelText: 'Amortissements antérieurs (reprise)'))),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final acq = Fmt.parseDate(_acq.text), svc = Fmt.parseDate(_service.text), gross = Fmt.parseAmount(_gross.text), months = int.tryParse(_months.text.trim());
            if (_code.text.trim().isEmpty || _designation.text.trim().isEmpty || acq == null || svc == null || gross == null || gross <= 0 || months == null || months <= 0 || (widget.initial == null && _accountId == null)) {
              setState(() => _error = 'Code, désignation, compte, dates, valeur brute et durée requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(inventoryRepositoryProvider).saveAsset(cabinet!.id, widget.entity.id, {
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
              setState(() => _error = frenchRpcError(e));
            }
          },
          child: const Text('Enregistrer'),
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
    return AlertDialog(
      title: Text('Tableau d\'amortissement — ${asset.code}'),
      content: SizedBox(
        width: 620,
        height: 400,
        child: FutureBuilder<List<PlanRow>>(
          future: ref.read(inventoryRepositoryProvider).plan(asset.id),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AkColors.sand),
                columns: const [DataColumn(label: Text('Exercice')), DataColumn(label: Text('Période')), DataColumn(label: Text('Taux'), numeric: true), DataColumn(label: Text('Dotation'), numeric: true), DataColumn(label: Text('Cumul'), numeric: true), DataColumn(label: Text('VNC'), numeric: true)],
                rows: [
                  for (final r in snap.data!)
                    DataRow(cells: [DataCell(Text('${r.periodStart.year}')), DataCell(Text('${Fmt.date(r.periodStart)} → ${Fmt.date(r.periodEnd)}')), DataCell(Text('${(r.rate * 100).toStringAsFixed(2)} %')), DataCell(Text(Fmt.fcfa(r.charge, showZero: true))), DataCell(Text(Fmt.fcfa(r.cumulated, showZero: true))), DataCell(Text(Fmt.fcfa(r.netBookValue, showZero: true)))]),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
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
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.allowPosting && a.isActive && (a.code.startsWith('485') || a.classNo == 5 || a.code.startsWith('411'))).toList();
    return AlertDialog(
      title: Text('${widget.scrap ? 'Mise au rebut' : 'Cession'} de ${widget.asset.code}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _date, decoration: const InputDecoration(labelText: 'Date')),
          if (!widget.scrap) ...[
            const SizedBox(height: 8),
            TextField(controller: _price, decoration: const InputDecoration(labelText: 'Prix de cession (FCFA)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Contrepartie (485 créances sur cessions, banque…)'),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.label}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _counterpart = v),
            ),
          ],
          const SizedBox(height: 8),
          const Text('Génère la dotation complémentaire, la sortie de l\'actif (81 / 28 / 2x) et le produit de cession (82), en brouillard.', style: TextStyle(fontSize: 12)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final d = Fmt.parseDate(_date.text);
            if (d == null) return;
            try {
              await ref.read(inventoryRepositoryProvider).disposeAsset(widget.asset.id, date: d, price: Fmt.parseAmount(_price.text) ?? 0, counterpartAccountId: _counterpart, scrap: widget.scrap);
              ref.invalidate(fixedAssetsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = frenchRpcError(e));
            }
          },
          child: Text(widget.scrap ? 'Mettre au rebut' : 'Céder'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class StocksTab extends ConsumerWidget {
  const StocksTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stocks = ref.watch(stocksProvider(fy.id));
    final accounts = ref.watch(accountsProvider(entity.id)).value ?? const <Account>[];
    final stockAccounts = accounts.where((a) => a.classNo == 3 && a.allowPosting && a.isActive && !a.code.startsWith('39')).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateStockVariations(entity.id, fy.id), 'Variations de stocks'), icon: const Icon(Icons.auto_awesome), label: const Text('Générer les variations')),
      body: AsyncView(
        value: stocks,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Inventaire intermittent : saisissez le stock final par compte de stock ; le stock initial est repris des à-nouveaux.'),
            const SizedBox(height: 8),
            for (final a in stockAccounts)
              _StockRow(entity: entity, fy: fy, account: a, existing: list.where((s) => s.stockAccountCode == a.code).firstOrNull, variationAccounts: accounts.where((x) => x.allowPosting && x.isActive && (x.code.startsWith('603') || x.code.startsWith('73'))).toList()),
            if (stockAccounts.isEmpty) const Text('Aucun compte de stock imputable dans le plan.'),
          ],
        ),
      ),
    );
  }
}

class _StockRow extends ConsumerStatefulWidget {
  const _StockRow({required this.entity, required this.fy, required this.account, required this.existing, required this.variationAccounts});

  final EntitySummary entity;
  final FiscalYear fy;
  final Account account;
  final StockRow? existing;
  final List<Account> variationAccounts;

  @override
  ConsumerState<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends ConsumerState<_StockRow> {
  late final _closing = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.closingValue}');
  String? _variation;

  @override
  Widget build(BuildContext context) {
    final def = widget.variationAccounts.where((v) => widget.existing != null ? v.code == widget.existing!.variationAccountCode : v.code.startsWith(widget.account.code.startsWith('31') || widget.account.code.startsWith('32') || widget.account.code.startsWith('33') ? '603' : '73')).firstOrNull;
    _variation ??= def?.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SizedBox(width: 260, child: Text('${widget.account.code} ${widget.account.label}', overflow: TextOverflow.ellipsis)),
          SizedBox(width: 160, child: Text('Initial ${Fmt.fcfa(widget.existing?.openingValue ?? 0, showZero: true)}')),
          SizedBox(width: 160, child: TextField(controller: _closing, decoration: const InputDecoration(labelText: 'Stock final'), keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _variation,
              decoration: const InputDecoration(labelText: 'Compte de variation'),
              items: [for (final v in widget.variationAccounts) DropdownMenuItem(value: v.id, child: Text('${v.code} ${v.label}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _variation = v),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () async {
              final closing = Fmt.parseAmount(_closing.text);
              if (closing == null || _variation == null) return;
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(inventoryRepositoryProvider).upsertStock(cabinet!.id, widget.entity.id, widget.fy.id, stockAccountId: widget.account.id, variationAccountId: _variation!, closingValue: closing);
              ref.invalidate(stocksProvider(widget.fy.id));
            },
            child: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class ProvisionsTab extends ConsumerStatefulWidget {
  const ProvisionsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<ProvisionsTab> createState() => _ProvisionsTabState();
}

class _ProvisionsTabState extends ConsumerState<ProvisionsTab> {
  final _r91 = TextEditingController(text: '25');
  final _r180 = TextEditingController(text: '50');

  @override
  Widget build(BuildContext context) {
    final provisions = ref.watch(provisionsProvider(widget.fy.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateProvisionEntries(widget.entity.id, widget.fy.id), 'Provisions'), icon: const Icon(Icons.auto_awesome), label: const Text('Générer dotations / reprises')),
      body: AsyncView(
        value: provisions,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Text('Créances douteuses depuis la balance âgée :'),
                  const SizedBox(width: 12),
                  SizedBox(width: 120, child: TextField(controller: _r91, decoration: const InputDecoration(labelText: '91-180 j (%)'))),
                  const SizedBox(width: 8),
                  SizedBox(width: 120, child: TextField(controller: _r180, decoration: const InputDecoration(labelText: '> 180 j (%)'))),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () async {
                      try {
                        final n = await ref.read(inventoryRepositoryProvider).proposeReceivableProvisions(widget.entity.id, widget.fy.id, rate91to180: (double.tryParse(_r91.text) ?? 0) / 100, rateOver180: (double.tryParse(_r180.text) ?? 0) / 100);
                        ref.invalidate(provisionsProvider(widget.fy.id));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n provision(s) proposée(s).')));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                      }
                    },
                    child: const Text('Proposer'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                for (final p in list)
                  ListTile(
                    dense: true,
                    title: Text('${p.kind == 'receivable' ? 'Créance' : 'Risque'} · ${p.thirdPartyCode ?? ''} · base ${Fmt.fcfa(p.baseAmount, showZero: true)}${p.rate != null ? ' × ${(p.rate! * 100).toStringAsFixed(0)} %' : ''}'),
                    subtitle: Text('Provision N-1 ${Fmt.fcfa(p.previousAmount, showZero: true)} → N ${Fmt.fcfa(p.amount, showZero: true)} · ${p.amount - p.previousAmount >= 0 ? 'dotation' : 'reprise'} ${Fmt.fcfa((p.amount - p.previousAmount).abs(), showZero: true)}${p.note != null ? ' · ${p.note}' : ''}'),
                    trailing: p.entryId != null
                        ? const Icon(Icons.check, color: AkColors.validated)
                        : IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final c = TextEditingController(text: '${p.amount}');
                              final v = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Montant de la provision'), content: TextField(controller: c, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider'))]));
                              final n = v == null ? null : Fmt.parseAmount(v);
                              if (n == null) return;
                              await ref.read(inventoryRepositoryProvider).updateProvisionAmount(p.id, n);
                              ref.invalidate(provisionsProvider(widget.fy.id));
                            },
                          ),
                  ),
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucune provision pour cet exercice.')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class AccrualsTab extends ConsumerWidget {
  const AccrualsTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accruals = ref.watch(accrualsProvider(fy.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(heroTag: 'gen-acc', onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateAccruals(entity.id, fy.id), 'Régularisations au 31/12'), icon: const Icon(Icons.auto_awesome), label: const Text('Générer au 31/12')),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: 'gen-rev',
          onPressed: () async {
            try {
              final ids = await ref.read(inventoryRepositoryProvider).generateReversals(entity.id, fy.id);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} extourne(s) générée(s) au 1er janvier N+1.')));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
            }
          },
          icon: const Icon(Icons.undo),
          label: const Text('Extournes N+1'),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(heroTag: 'new-acc', onPressed: () => showDialog(context: context, builder: (_) => AccrualDialog(entity: entity, fy: fy)), icon: const Icon(Icons.add), label: const Text('Régularisation')),
      ]),
      body: AsyncView(
        value: accruals,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(children: [
                for (final a in list)
                  ListTile(
                    dense: true,
                    title: Text('${AccrualRow.kindLabels[a.kind]} · ${a.description}'),
                    subtitle: Text('${a.accountCode} / ${a.counterpartCode} · ${Fmt.fcfa(a.totalAmount, showZero: true)} du ${Fmt.date(a.periodFrom)} au ${Fmt.date(a.periodTo)} · part régularisée ${Fmt.fcfa(a.amount, showZero: true)}${a.entryId != null ? ' · écriture générée' : ''}${a.reversalEntryId != null ? ' · extournée' : ''}'),
                    trailing: a.entryId == null ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                      await ref.read(inventoryRepositoryProvider).deleteAccrual(a.id);
                      ref.invalidate(accrualsProvider(fy.id));
                    }) : null,
                  ),
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucune régularisation saisie.')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class AccrualDialog extends ConsumerStatefulWidget {
  const AccrualDialog({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<AccrualDialog> createState() => _AccrualDialogState();
}

class _AccrualDialogState extends ConsumerState<AccrualDialog> {
  String _kind = 'cca';
  final _desc = TextEditingController();
  final _total = TextEditingController();
  late final _from = TextEditingController(text: Fmt.date(widget.fy.startDate));
  late final _to = TextEditingController(text: Fmt.date(widget.fy.endDate));
  String? _account;
  String? _counterpart;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.allowPosting && a.isActive).toList();
    final defaultCounterpart = switch (_kind) { 'cap' => '408', 'par' => '418', 'cca' => '476', _ => '477' };
    return AlertDialog(
      title: const Text('Régularisation'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: _kind, decoration: const InputDecoration(labelText: 'Type'), items: [for (final e in AccrualRow.kindLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => _kind = v ?? 'cca')),
          const SizedBox(height: 8),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          Autocomplete<Account>(
            displayStringForOption: (a) => '${a.code} ${a.label}',
            optionsBuilder: (v) => accounts.where((a) => v.text.isNotEmpty && (a.classNo == 6 || a.classNo == 7) && (a.code.startsWith(v.text) || a.label.toLowerCase().contains(v.text.toLowerCase()))).take(12),
            onSelected: (a) => _account = a.id,
            fieldViewBuilder: (c, ctrl, f, _) => TextField(controller: ctrl, focusNode: f, onChanged: (v) => _account = matchAccountCode(accounts, v)?.id ?? _account, decoration: const InputDecoration(labelText: 'Compte de charge ou de produit')),
          ),
          const SizedBox(height: 8),
          Autocomplete<Account>(
            displayStringForOption: (a) => '${a.code} ${a.label}',
            initialValue: TextEditingValue(text: accounts.where((a) => a.code.startsWith(defaultCounterpart)).firstOrNull?.code ?? ''),
            optionsBuilder: (v) => accounts.where((a) => v.text.isNotEmpty && a.classNo == 4 && (a.code.startsWith(v.text) || a.label.toLowerCase().contains(v.text.toLowerCase()))).take(12),
            onSelected: (a) => _counterpart = a.id,
            fieldViewBuilder: (c, ctrl, f, _) => TextField(controller: ctrl, focusNode: f, onChanged: (v) => _counterpart = matchAccountCode(accounts, v)?.id ?? _counterpart, decoration: InputDecoration(labelText: 'Compte de régularisation (défaut $defaultCounterpart)')),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _total, decoration: const InputDecoration(labelText: 'Montant total'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'Période du'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _to, decoration: const InputDecoration(labelText: 'au'))),
          ]),
          const SizedBox(height: 6),
          const Text('Prorata au jour (base 360) calculé à la génération ; extourne automatique au 1er janvier N+1.', style: TextStyle(fontSize: 12)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final total = Fmt.parseAmount(_total.text), from = Fmt.parseDate(_from.text), to = Fmt.parseDate(_to.text);
            final counterpart = _counterpart ?? accounts.where((a) => a.code.startsWith(defaultCounterpart)).firstOrNull?.id;
            if (_desc.text.trim().isEmpty || _account == null || counterpart == null || total == null || total <= 0 || from == null || to == null || to.isBefore(from)) {
              setState(() => _error = 'Description, comptes, montant et période requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(inventoryRepositoryProvider).addAccrual(cabinet!.id, widget.entity.id, widget.fy.id, kind: _kind, description: _desc.text.trim(), accountId: _account!, counterpartAccountId: counterpart, totalAmount: total, from: from, to: to);
              ref.invalidate(accrualsProvider(widget.fy.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = frenchRpcError(e));
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class FxTab extends ConsumerStatefulWidget {
  const FxTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<FxTab> createState() => _FxTabState();
}

class _FxTabState extends ConsumerState<FxTab> {
  final _currency = TextEditingController(text: 'USD');
  final _rate = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cours de clôture (l\'euro est à parité fixe 655,957). Les créances et dettes en devises non lettrées sont réévaluées au cours de clôture : écarts 478 / 479 et provision pour pertes de change, extournés au 1er janvier.'),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 100, child: TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Devise'), textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 8),
                SizedBox(width: 160, child: TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Cours de clôture (FCFA)'))),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    final r = double.tryParse(_rate.text.replaceAll(',', '.'));
                    if (r == null || _currency.text.trim().length != 3) return;
                    final cabinet = await ref.read(currentCabinetProvider.future);
                    await ref.read(inventoryRepositoryProvider).setClosingRate(cabinet!.id, _currency.text.trim().toUpperCase(), widget.fy.endDate, r);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cours enregistré.')));
                  },
                  child: const Text('Enregistrer le cours'),
                ),
                const Spacer(),
                FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateFxRevaluation(widget.entity.id, widget.fy.id), 'Écarts de conversion'), icon: const Icon(Icons.auto_awesome), label: const Text('Générer les écarts')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}
