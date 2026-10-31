import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/errors/errors.dart';
import '../../core/formatting.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entities_providers.dart';
import '../../application/providers/inventory_providers.dart';
import '../../application/providers/references_providers.dart';
import '../../domain/inventory_models.dart';
import '../../application/providers/session_providers.dart';
import '../../application/providers/services.dart';

/// Marge latérale de page : 24 px sur desktop, 16 px sur mobile (< 600 px).
EdgeInsets akPagePadding(BuildContext context) => EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? AkSpace.s4 : AkSpace.s6);

/// Message d'erreur sous forme de toast.
void showErrorSnack(BuildContext context, String message) {
  showAkToast(context, message, kind: AkToastKind.danger);
}

/// Liste de lignes séparées par des filets, dans une carte sans marge interne.
Widget akRowsCard(BuildContext context, List<Widget> rows) {
  final t = context.ak;
  return AkCard(
    padding: EdgeInsets.zero,
    clip: true,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(height: 1, color: t.border), rows[i]],
      ],
    ),
  );
}

/// Message de liste vide, dans une carte.
Widget akEmptyRow(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.all(AkSpace.s4),
  child: Text(text, style: AkText.body.copyWith(color: context.ak.textMuted)),
);

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
        if (fy == null) return const AkEmptyState('Aucun exercice.');
        final t = context.ak;
        final margin = akPageMargin(context);
        return DefaultTabController(
          length: 5,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(margin, AkSpace.s6, margin, AkSpace.s2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AkPageHead(title: 'Travaux d\'inventaire — exercice ${fy.label}', subtitle: entity.name),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Les écritures générées arrivent en brouillard, marquées « générée ».', style: AkText.caption.copyWith(color: t.textMuted)),
                ),
              ),
              const SizedBox(height: AkSpace.s2),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Immobilisations'),
                  Tab(text: 'Stocks'),
                  Tab(text: 'Provisions'),
                  Tab(text: 'Régularisations'),
                  Tab(text: 'Écarts de conversion'),
                ],
              ),
              Divider(height: 1, color: t.border),
              Expanded(
                child: TabBarView(
                  children: [
                    AssetsTab(entity: entity, fy: fy),
                    StocksTab(entity: entity, fy: fy),
                    ProvisionsTab(entity: entity, fy: fy),
                    AccrualsTab(entity: entity, fy: fy),
                    FxTab(entity: entity, fy: fy),
                  ],
                ),
              ),
            ],
          ),
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
    showAkToast(
      context,
      id == null ? 'Rien à générer.' : '$successLabel : brouillard créé.',
      kind: id == null ? AkToastKind.info : AkToastKind.success,
      actionLabel: id == null ? null : 'Ouvrir',
      onAction: id == null ? null : () => context.go('/saisie/$id'),
    );
  } catch (e) {
    if (context.mounted) showErrorSnack(context, errorText(e));
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
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer les variations',
                icon: Icons.auto_awesome,
                onPressed: () =>
                    runGeneration(context, ref, () => ref.read(inventoryServiceProvider).generateStockVariations(entity.id, fy.id), 'Variations de stocks'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          const AkBanner(
            kind: AkBannerKind.info,
            child: Text('Inventaire intermittent : saisissez le stock final par compte de stock ; le stock initial est repris des à-nouveaux.'),
          ),
          const SizedBox(height: AkSpace.s3),
          for (final a in stockAccounts)
            _StockRow(
              entity: entity,
              fy: fy,
              account: a,
              existing: list.where((s) => s.stockAccountCode == a.code).firstOrNull,
              openingValue: opening[a.code] ?? 0,
              variationAccounts: accounts.where((x) => x.allowPosting && x.isActive && (x.code.startsWith('603') || x.code.startsWith('73'))).toList(),
            ),
          if (stockAccounts.isEmpty) Text('Aucun compte de stock imputable dans le plan.', style: AkText.body.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

class _StockRow extends ConsumerStatefulWidget {
  const _StockRow({
    required this.entity,
    required this.fy,
    required this.account,
    required this.existing,
    required this.openingValue,
    required this.variationAccounts,
  });

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
    final def = widget.variationAccounts
        .where(
          (v) => widget.existing != null
              ? v.code == widget.existing!.variationAccountCode
              : v.code.startsWith(
                  widget.account.code.startsWith('31') || widget.account.code.startsWith('32') || widget.account.code.startsWith('33') ? '603' : '73',
                ),
        )
        .firstOrNull;
    _variation ??= def?.id;
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: AkCard(
        padding: const EdgeInsets.all(AkSpace.s3),
        child: Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 260,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AkSpace.s2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: widget.account.code, style: AkText.code),
                      TextSpan(text: ' ${widget.account.label}'),
                    ],
                  ),
                  style: AkText.body.copyWith(color: t.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AkSpace.s2),
                child: Text('Initial ${Fmt.fcfa(widget.openingValue, showZero: true)}', style: AkText.amount.copyWith(color: t.textMuted)),
              ),
            ),
            SizedBox(
              width: 200,
              child: AkAmountField(controller: _closing, label: 'Stock final'),
            ),
            SizedBox(
              width: 320,
              child: AkDropdown<String>(
                label: 'Compte de variation',
                value: _variation,
                items: [for (final v in widget.variationAccounts) AkOption(v.id, '${v.code} ${v.label}')],
                onChanged: (v) => setState(() => _variation = v),
              ),
            ),
            AkButton.secondary(
              'Enregistrer',
              onPressed: () async {
                final closing = Fmt.parseAmount(_closing.text);
                if (closing == null || _variation == null) return;
                final cabinet = await ref.read(currentCabinetProvider.future);
                await ref
                    .read(inventoryServiceProvider)
                    .upsertStock(
                      cabinet!.id,
                      widget.entity.id,
                      widget.fy.id,
                      stockAccountId: widget.account.id,
                      variationAccountId: _variation!,
                      closingValue: closing,
                    );
                ref.invalidate(stocksProvider(widget.fy.id));
              },
            ),
          ],
        ),
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
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer dotations / reprises',
                icon: Icons.auto_awesome,
                onPressed: () => runGeneration(
                  context,
                  ref,
                  () => ref.read(inventoryServiceProvider).generateProvisionEntries(widget.entity.id, widget.fy.id),
                  'Provisions',
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkCard(
            child: Wrap(
              spacing: AkSpace.s3,
              runSpacing: AkSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AkSpace.s2),
                  child: Text('Créances douteuses depuis la balance âgée :', style: AkText.body.copyWith(color: t.text)),
                ),
                SizedBox(
                  width: 140,
                  child: AkTextField(controller: _r91, label: '91-180 j (%)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                SizedBox(
                  width: 140,
                  child: AkTextField(controller: _r180, label: '> 180 j (%)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                AkButton.secondary(
                  'Proposer',
                  onPressed: () async {
                    try {
                      final n = await ref
                          .read(inventoryServiceProvider)
                          .proposeReceivableProvisions(
                            widget.entity.id,
                            widget.fy.id,
                            rate91to180: (double.tryParse(_r91.text) ?? 0) / 100,
                            rateOver180: (double.tryParse(_r180.text) ?? 0) / 100,
                          );
                      ref.invalidate(provisionsProvider(widget.fy.id));
                      if (context.mounted) showAkToast(context, '$n provision(s) proposée(s).');
                    } catch (e) {
                      if (context.mounted) showErrorSnack(context, errorText(e));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          AkTable<ProvisionRow>(
            rows: list,
            minWidth: 760,
            emptyMessage: 'Aucune provision pour cet exercice.',
            columns: [
              AkColumn<ProvisionRow>(
                label: 'Provision',
                flex: 3,
                cell: (context, p) => Text(
                  '${p.kind == 'receivable' ? 'Créance' : 'Risque'} · ${p.thirdPartyCode ?? ''} · base ${Fmt.fcfa(p.baseAmount, showZero: true)}${p.rate != null ? ' × ${(p.rate! * 100).toStringAsFixed(0)} %' : ''}',
                  style: AkText.body.copyWith(color: t.text),
                ),
              ),
              AkColumn<ProvisionRow>(
                label: 'Détail',
                flex: 4,
                cell: (context, p) => Text(
                  'Provision N-1 ${Fmt.fcfa(p.previousAmount, showZero: true)} → N ${Fmt.fcfa(p.amount, showZero: true)} · ${p.amount - p.previousAmount >= 0 ? 'dotation' : 'reprise'} ${Fmt.fcfa((p.amount - p.previousAmount).abs(), showZero: true)}${p.note != null ? ' · ${p.note}' : ''}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ),
              AkColumn<ProvisionRow>(
                label: '',
                width: 48,
                cell: (context, p) => p.entryId != null
                    ? Icon(Icons.check_circle_outline, color: t.success)
                    : AkIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Modifier le montant',
                        dense: true,
                        onPressed: () async {
                          final c = TextEditingController(text: '${p.amount}');
                          final v = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AkDialog(
                              title: 'Montant de la provision',
                              content: AkAmountField(controller: c, autofocus: true),
                              actions: [
                                AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx)),
                                AkButton.primary('Valider', onPressed: () => Navigator.pop(ctx, c.text)),
                              ],
                            ),
                          );
                          final n = v == null ? null : Fmt.parseAmount(v);
                          if (n == null) return;
                          await ref.read(inventoryServiceProvider).updateProvisionAmount(p.id, n);
                          ref.invalidate(provisionsProvider(widget.fy.id));
                        },
                      ),
              ),
            ],
          ),
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
      builder: (list) => AkPage(
        children: [
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkButton.primary(
                'Générer au 31/12',
                icon: Icons.auto_awesome,
                onPressed: () =>
                    runGeneration(context, ref, () => ref.read(inventoryServiceProvider).generateAccruals(entity.id, fy.id), 'Régularisations au 31/12'),
              ),
              AkButton.secondary(
                'Extournes N+1',
                icon: Icons.undo,
                onPressed: () async {
                  try {
                    final ids = await ref.read(inventoryServiceProvider).generateReversals(entity.id, fy.id);
                    if (context.mounted) {
                      showAkToast(context, '${ids.length} extourne(s) générée(s) au 1er janvier N+1.');
                    }
                  } catch (e) {
                    if (context.mounted) showErrorSnack(context, errorText(e));
                  }
                },
              ),
              AkButton.secondary(
                'Régularisation',
                icon: Icons.add,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AccrualDialog(entity: entity, fy: fy),
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s4),
          AkTable<AccrualRow>(
            rows: list,
            minWidth: 760,
            emptyMessage: 'Aucune régularisation saisie.',
            columns: [
              AkColumn<AccrualRow>(
                label: 'Régularisation',
                flex: 3,
                cell: (context, a) => Text('${AccrualRow.kindLabels[a.kind]} · ${a.description}', style: AkText.body.copyWith(color: t.text)),
              ),
              AkColumn<AccrualRow>(
                label: 'Détail',
                flex: 4,
                cell: (context, a) => Text(
                  '${a.accountCode} / ${a.counterpartCode} · ${Fmt.fcfa(a.totalAmount, showZero: true)} du ${Fmt.date(a.periodFrom)} au ${Fmt.date(a.periodTo)} · part régularisée ${Fmt.fcfa(a.amount, showZero: true)}${a.entryId != null ? ' · écriture générée' : ''}${a.reversalEntryId != null ? ' · extournée' : ''}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ),
              AkColumn<AccrualRow>(
                label: '',
                width: 48,
                cell: (context, a) => a.entryId == null
                    ? AkIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Supprimer',
                        dense: true,
                        onPressed: () async {
                          await ref.read(inventoryServiceProvider).deleteAccrual(a.id);
                          ref.invalidate(accrualsProvider(fy.id));
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
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
    final defaultCounterpart = switch (_kind) {
      'cap' => '408',
      'par' => '418',
      'cca' => '476',
      _ => '477',
    };
    return AkDialog(
      title: 'Régularisation',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AkDropdown<String>(
            label: 'Type',
            value: _kind,
            items: [for (final e in AccrualRow.kindLabels.entries) AkOption(e.key, e.value)],
            onChanged: (v) => setState(() => _kind = v ?? 'cca'),
          ),
          const SizedBox(height: AkSpace.s2),
          AkTextField(controller: _desc, label: 'Description'),
          const SizedBox(height: AkSpace.s2),
          AkAccountField(
            label: 'Compte de charge ou de produit',
            accounts: accounts.where((a) => a.classNo == 6 || a.classNo == 7).toList(),
            onSelected: (a) => _account = a.id,
          ),
          const SizedBox(height: AkSpace.s2),
          AkAccountField(
            label: 'Compte de régularisation (défaut $defaultCounterpart)',
            accounts: accounts.where((a) => a.classNo == 4).toList(),
            selected: accounts.where((a) => a.classNo == 4 && a.code.startsWith(defaultCounterpart)).firstOrNull,
            onSelected: (a) => _counterpart = a.id,
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AkAmountField(controller: _total, label: 'Montant total', showCurrency: false),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _from, label: 'Période du'),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkDateField(controller: _to, label: 'au'),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Prorata au jour (base 360) calculé à la génération ; extourne automatique au 1er janvier N+1.',
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
          'Ajouter',
          onPressed: () async {
            final total = Fmt.parseAmount(_total.text), from = Fmt.parseDate(_from.text), to = Fmt.parseDate(_to.text);
            final counterpart = _counterpart ?? accounts.where((a) => a.code.startsWith(defaultCounterpart)).firstOrNull?.id;
            if (_desc.text.trim().isEmpty ||
                _account == null ||
                counterpart == null ||
                total == null ||
                total <= 0 ||
                from == null ||
                to == null ||
                to.isBefore(from)) {
              setState(() => _error = 'Description, comptes, montant et période requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref
                  .read(inventoryServiceProvider)
                  .addAccrual(
                    cabinet!.id,
                    widget.entity.id,
                    widget.fy.id,
                    kind: _kind,
                    description: _desc.text.trim(),
                    accountId: _account!,
                    counterpartAccountId: counterpart,
                    totalAmount: total,
                    from: from,
                    to: to,
                  );
              ref.invalidate(accrualsProvider(widget.fy.id));
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
    return AkPage(
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Cours de clôture'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Cours de clôture (l\'euro est à parité fixe 655,957). Les créances et dettes en devises non lettrées sont réévaluées au cours de clôture : écarts 478 / 479 et provision pour pertes de change, extournés au 1er janvier.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              Wrap(
                spacing: AkSpace.s2,
                runSpacing: AkSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 120,
                    child: AkTextField(
                      controller: _currency,
                      label: 'Devise',
                      mono: true,
                      inputFormatters: [TextInputFormatter.withFunction((old, v) => v.copyWith(text: v.text.toUpperCase()))],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: AkTextField(
                      controller: _rate,
                      label: 'Cours de clôture (FCFA)',
                      mono: true,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  AkButton.secondary(
                    'Enregistrer le cours',
                    onPressed: () async {
                      final r = double.tryParse(_rate.text.replaceAll(',', '.'));
                      if (r == null || _currency.text.trim().length != 3) return;
                      final cabinet = await ref.read(currentCabinetProvider.future);
                      await ref.read(inventoryServiceProvider).setClosingRate(cabinet!.id, _currency.text.trim().toUpperCase(), widget.fy.endDate, r);
                      if (context.mounted) showAkToast(context, 'Cours enregistré.');
                    },
                  ),
                  AkButton.primary(
                    'Générer les écarts',
                    icon: Icons.auto_awesome,
                    onPressed: () => runGeneration(
                      context,
                      ref,
                      () => ref.read(inventoryServiceProvider).generateFxRevaluation(widget.entity.id, widget.fy.id),
                      'Écarts de conversion',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
