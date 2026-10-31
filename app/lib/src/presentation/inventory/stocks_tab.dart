import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

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
