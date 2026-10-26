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
import '../widgets/ak_widgets.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

String frenchRpcError(Object e) => RegExp(r'message: ([^,}]+)').firstMatch(e.toString())?.group(1) ?? e.toString();

/// Marge latérale de page : 24 px sur desktop, 16 px sur mobile (< 600 px).
EdgeInsets akPagePadding(BuildContext context) => EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? AkSpace.s4 : AkSpace.s6);

/// Message d'erreur : le SnackBar du thème est sombre, on force un fond « danger » avec texte lisible.
void showErrorSnack(BuildContext context, String message) {
  final t = context.ak;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: AkText.body.copyWith(color: t.surface)), backgroundColor: t.danger));
}

/// Liste de lignes séparées par des filets, dans une carte sans marge interne.
Widget akRowsCard(BuildContext context, List<Widget> rows) {
  final t = context.ak;
  return AkCard(
    padding: EdgeInsets.zero,
    clip: true,
    child: Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(height: 1, color: t.border),
        rows[i],
      ],
    ]),
  );
}

/// Message de liste vide, dans une carte.
Widget akEmptyRow(BuildContext context, String text) => Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Text(text, style: AkText.body.copyWith(color: context.ak.textMuted)));

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
        final t = context.ak;
        return DefaultTabController(
          length: 5,
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(akPagePadding(context).left, AkSpace.s6, akPagePadding(context).right, AkSpace.s2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AkPageHead(title: 'Travaux d\'inventaire — exercice ${fy.label}', subtitle: entity.name),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: akPagePadding(context).left),
              child: Align(alignment: Alignment.centerLeft, child: Text('Les écritures générées arrivent en brouillard, marquées « générée ».', style: AkText.caption.copyWith(color: t.textMuted))),
            ),
            const SizedBox(height: AkSpace.s2),
            const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Immobilisations'), Tab(text: 'Stocks'), Tab(text: 'Provisions'), Tab(text: 'Régularisations'), Tab(text: 'Écarts de conversion')]),
            Divider(height: 1, color: t.border),
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
    // Avec un bouton d'action, un message reste affiché tant que la navigation accessible est active :
    // on le borne dans le temps et on permet de le fermer.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(id == null ? 'Rien à générer.' : '$successLabel : brouillard créé.'),
      duration: const Duration(seconds: 6),
      showCloseIcon: true,
      action: id == null ? null : SnackBarAction(label: 'Ouvrir', onPressed: () => context.go('/saisie/$id')),
    ));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, frenchRpcError(e));
  }
}

// ---------------------------------------------------------------------------
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
      builder: (list) => ListView(
        padding: akPagePadding(context),
        children: [
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
            FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateDepreciation(entity.id, fy.id), 'Dotations ${fy.label}'), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Générer les dotations')),
            OutlinedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => AssetDialog(entity: entity)), icon: const Icon(Icons.add, size: 18), label: const Text('Immobilisation')),
          ]),
          const SizedBox(height: AkSpace.s4),
          akRowsCard(context, [
            for (final a in list)
              ListTile(
                leading: SizedBox(width: 80, child: Text(a.code, style: AkText.code.copyWith(fontWeight: FontWeight.w600, color: t.text))),
                title: Text(a.designation, style: AkText.body.copyWith(color: a.status == 'in_service' ? t.text : t.textMuted, decoration: a.status == 'in_service' ? null : TextDecoration.lineThrough)),
                subtitle: Text('${a.assetAccountCode} · mise en service ${Fmt.date(a.serviceDate)} · ${Fmt.fcfa(a.grossValue, showZero: true)} FCFA · ${a.durationMonths ~/ 12} ans ${a.method == 'declining' ? 'dégressif' : 'linéaire'}${a.priorDepreciation > 0 ? ' · amortissements antérieurs ${Fmt.fcfa(a.priorDepreciation)}' : ''} · ${a.statusLabel}', style: AkText.caption.copyWith(color: t.textMuted)),
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
            if (list.isEmpty) akEmptyRow(context, 'Aucune immobilisation. Reprenez l\'existant (valeur brute + amortissements cumulés) ou enregistrez les acquisitions.'),
          ]),
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
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: AkText.caption.copyWith(color: context.ak.danger))),
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
                columns: const [DataColumn(label: Text('Exercice')), DataColumn(label: Text('Période')), DataColumn(label: Text('Taux'), numeric: true), DataColumn(label: Text('Dotation'), numeric: true), DataColumn(label: Text('Cumul'), numeric: true), DataColumn(label: Text('VNC'), numeric: true)],
                rows: [
                  for (final r in snap.data!)
                    DataRow(cells: [DataCell(Text('${r.periodStart.year}')), DataCell(Text('${Fmt.date(r.periodStart)} → ${Fmt.date(r.periodEnd)}')), DataCell(Text('${(r.rate * 100).toStringAsFixed(2)} %', style: AkText.amount)), DataCell(Text(Fmt.fcfa(r.charge, showZero: true), style: AkText.amount)), DataCell(Text(Fmt.fcfa(r.cumulated, showZero: true), style: AkText.amount)), DataCell(Text(Fmt.fcfa(r.netBookValue, showZero: true), style: AkText.amount))]),
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
          Text('Génère la dotation complémentaire, la sortie de l\'actif (81 / 28 / 2x) et le produit de cession (82), en brouillard.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: AkText.caption.copyWith(color: context.ak.danger))),
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
    final t = context.ak;
    final stocks = ref.watch(stocksProvider(fy.id));
    final accounts = ref.watch(accountsProvider(entity.id)).value ?? const <Account>[];
    final stockAccounts = accounts.where((a) => a.classNo == 3 && a.allowPosting && a.isActive && !a.code.startsWith('39')).toList();
    final opening = ref.watch(stockOpeningBalancesProvider((entityId: entity.id, startDate: fy.startDate))).value ?? const <String, int>{};
    return AsyncView(
      value: stocks,
      builder: (list) => ListView(
        padding: akPagePadding(context),
        children: [
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
            FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateStockVariations(entity.id, fy.id), 'Variations de stocks'), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Générer les variations')),
          ]),
          const SizedBox(height: AkSpace.s3),
          AkBanner(kind: AkBannerKind.info, child: const Text('Inventaire intermittent : saisissez le stock final par compte de stock ; le stock initial est repris des à-nouveaux.')),
          const SizedBox(height: AkSpace.s3),
          for (final a in stockAccounts)
            _StockRow(entity: entity, fy: fy, account: a, existing: list.where((s) => s.stockAccountCode == a.code).firstOrNull, openingValue: opening[a.code] ?? 0, variationAccounts: accounts.where((x) => x.allowPosting && x.isActive && (x.code.startsWith('603') || x.code.startsWith('73'))).toList()),
          if (stockAccounts.isEmpty) Text('Aucun compte de stock imputable dans le plan.', style: AkText.body.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

class _StockRow extends ConsumerStatefulWidget {
  const _StockRow({required this.entity, required this.fy, required this.account, required this.existing, required this.openingValue, required this.variationAccounts});

  final EntitySummary entity;
  final FiscalYear fy;
  final Account account;
  final StockRow? existing;
  /// Stock initial lu dans les à-nouveaux (balance à l'ouverture).
  final int openingValue;
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
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: AkCard(
        padding: const EdgeInsets.all(AkSpace.s3),
        child: Row(children: [
          SizedBox(width: 260, child: Text.rich(TextSpan(children: [TextSpan(text: widget.account.code, style: AkText.code), TextSpan(text: ' ${widget.account.label}')]), style: AkText.body.copyWith(color: t.text), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 160, child: Text('Initial ${Fmt.fcfa(widget.openingValue, showZero: true)}', style: AkText.amount.copyWith(color: t.textMuted))),
          SizedBox(width: 160, child: TextField(controller: _closing, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Stock final'), keyboardType: TextInputType.number)),
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
          OutlinedButton(
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
    final t = context.ak;
    return AsyncView(
        value: provisions,
        builder: (list) => ListView(
          padding: akPagePadding(context),
          children: [
            Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
              FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateProvisionEntries(widget.entity.id, widget.fy.id), 'Provisions'), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Générer dotations / reprises')),
            ]),
            const SizedBox(height: AkSpace.s4),
            AkCard(
                child: Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('Créances douteuses depuis la balance âgée :', style: AkText.body.copyWith(color: t.text)),
                  SizedBox(width: 120, child: TextField(controller: _r91, decoration: const InputDecoration(labelText: '91-180 j (%)'))),
                  SizedBox(width: 120, child: TextField(controller: _r180, decoration: const InputDecoration(labelText: '> 180 j (%)'))),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        final n = await ref.read(inventoryRepositoryProvider).proposeReceivableProvisions(widget.entity.id, widget.fy.id, rate91to180: (double.tryParse(_r91.text) ?? 0) / 100, rateOver180: (double.tryParse(_r180.text) ?? 0) / 100);
                        ref.invalidate(provisionsProvider(widget.fy.id));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n provision(s) proposée(s).')));
                      } catch (e) {
                        if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                      }
                    },
                    child: const Text('Proposer'),
                  ),
                ]),
            ),
            const SizedBox(height: AkSpace.s3),
            akRowsCard(context, [
                for (final p in list)
                  ListTile(
                    dense: true,
                    title: Text('${p.kind == 'receivable' ? 'Créance' : 'Risque'} · ${p.thirdPartyCode ?? ''} · base ${Fmt.fcfa(p.baseAmount, showZero: true)}${p.rate != null ? ' × ${(p.rate! * 100).toStringAsFixed(0)} %' : ''}'),
                    subtitle: Text('Provision N-1 ${Fmt.fcfa(p.previousAmount, showZero: true)} → N ${Fmt.fcfa(p.amount, showZero: true)} · ${p.amount - p.previousAmount >= 0 ? 'dotation' : 'reprise'} ${Fmt.fcfa((p.amount - p.previousAmount).abs(), showZero: true)}${p.note != null ? ' · ${p.note}' : ''}'),
                    trailing: p.entryId != null
                        ? Icon(Icons.check_circle_outline, color: t.success)
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
                if (list.isEmpty) akEmptyRow(context, 'Aucune provision pour cet exercice.'),
            ]),
          ],
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
    final t = context.ak;
    final accruals = ref.watch(accrualsProvider(fy.id));
    return AsyncView(
      value: accruals,
      builder: (list) => ListView(
        padding: akPagePadding(context),
        children: [
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
            FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateAccruals(entity.id, fy.id), 'Régularisations au 31/12'), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Générer au 31/12')),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final ids = await ref.read(inventoryRepositoryProvider).generateReversals(entity.id, fy.id);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} extourne(s) générée(s) au 1er janvier N+1.')));
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                }
              },
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Extournes N+1'),
            ),
            OutlinedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => AccrualDialog(entity: entity, fy: fy)), icon: const Icon(Icons.add, size: 18), label: const Text('Régularisation')),
          ]),
          const SizedBox(height: AkSpace.s4),
          akRowsCard(context, [
            for (final a in list)
              ListTile(
                dense: true,
                title: Text('${AccrualRow.kindLabels[a.kind]} · ${a.description}', style: AkText.body.copyWith(color: t.text)),
                subtitle: Text('${a.accountCode} / ${a.counterpartCode} · ${Fmt.fcfa(a.totalAmount, showZero: true)} du ${Fmt.date(a.periodFrom)} au ${Fmt.date(a.periodTo)} · part régularisée ${Fmt.fcfa(a.amount, showZero: true)}${a.entryId != null ? ' · écriture générée' : ''}${a.reversalEntryId != null ? ' · extournée' : ''}', style: AkText.caption.copyWith(color: t.textMuted)),
                trailing: a.entryId == null ? IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () async {
                  await ref.read(inventoryRepositoryProvider).deleteAccrual(a.id);
                  ref.invalidate(accrualsProvider(fy.id));
                }) : null,
              ),
            if (list.isEmpty) akEmptyRow(context, 'Aucune régularisation saisie.'),
          ]),
        ],
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
          Text('Prorata au jour (base 360) calculé à la génération ; extourne automatique au 1er janvier N+1.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: AkText.caption.copyWith(color: context.ak.danger))),
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
    final t = context.ak;
    return ListView(
      padding: akPagePadding(context),
      children: [
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cours de clôture', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            Text('Cours de clôture (l\'euro est à parité fixe 655,957). Les créances et dettes en devises non lettrées sont réévaluées au cours de clôture : écarts 478 / 479 et provision pour pertes de change, extournés au 1er janvier.', style: AkText.body.copyWith(color: t.textMuted)),
            const SizedBox(height: AkSpace.s3),
            Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 100, child: TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Devise'), textCapitalization: TextCapitalization.characters)),
              SizedBox(width: 160, child: TextField(controller: _rate, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Cours de clôture (FCFA)'))),
              OutlinedButton(
                onPressed: () async {
                  final r = double.tryParse(_rate.text.replaceAll(',', '.'));
                  if (r == null || _currency.text.trim().length != 3) return;
                  final cabinet = await ref.read(currentCabinetProvider.future);
                  await ref.read(inventoryRepositoryProvider).setClosingRate(cabinet!.id, _currency.text.trim().toUpperCase(), widget.fy.endDate, r);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cours enregistré.')));
                },
                child: const Text('Enregistrer le cours'),
              ),
              FilledButton.icon(onPressed: () => runGeneration(context, ref, () => ref.read(inventoryRepositoryProvider).generateFxRevaluation(widget.entity.id, widget.fy.id), 'Écarts de conversion'), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Générer les écarts')),
            ]),
          ]),
        ),
      ],
    );
  }
}
