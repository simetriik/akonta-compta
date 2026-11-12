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
import '../../application/rules/account_selection.dart';
import '../../application/rules/inventory_forms.dart';
import '../../application/rules/stock_hint.dart';
import '../../core/errors/error_mapper.dart';

class StocksTab extends ConsumerWidget {
  const StocksTab({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ak;
    final stocks = ref.watch(stocksProvider(fy.id));
    final accounts = ref.watch(accountsProvider(entity.id)).value ?? const <Account>[];
    final stockAccounts = AccountSelection.stocks(accounts);
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
              warning: StockHint.wrongAccount(a.code, opening),
              variationAccounts: AccountSelection.stockVariation(accounts),
              allCodes: [for (final a in accounts) a.code],
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
    required this.warning,
    required this.variationAccounts,
    required this.allCodes,
  });

  final EntitySummary entity;
  final FiscalYear fy;
  final Account account;
  final StockRow? existing;

  /// Stock initial lu dans les à-nouveaux (balance à l'ouverture).
  final int openingValue;

  /// Avertissement de cohérence du compte (AN-19), `null` si rien à signaler.
  final String? warning;
  final List<Account> variationAccounts;

  /// Codes de tous les comptes du plan, pour reconnaître un compte de regroupement.
  final List<String> allCodes;

  @override
  ConsumerState<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends ConsumerState<_StockRow> {
  late final _closing = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.closingValue}');
  String? _variation;

  @override
  Widget build(BuildContext context) {
    final prefix = StockHint.variationPrefix(widget.account.code);
    final def = widget.existing != null
        ? widget.variationAccounts.where((v) => v.code == widget.existing!.variationAccountCode).firstOrNull
        : widget.variationAccounts.where((v) => v.code.startsWith(prefix)).firstOrNull ??
            widget.variationAccounts.where((v) => v.code.startsWith(prefix.substring(0, prefix.length == 4 ? 3 : 2))).firstOrNull;
    _variation ??= def?.id;
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: AkCard(
        padding: const EdgeInsets.all(AkSpace.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
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
                final form = InventoryForms.stockValue(closing: _closing.text, variationAccountId: _variation);
                if (form.error != null) {
                  showErrorSnack(context, form.error!);
                  return;
                }
                try {
                  final cabinet = await ref.read(currentCabinetProvider.future);
                  await ref
                      .read(inventoryServiceProvider)
                      .upsertStock(
                        cabinet!.id,
                        widget.entity.id,
                        widget.fy.id,
                        stockAccountId: widget.account.id,
                        variationAccountId: _variation!,
                        closingValue: form.value!,
                      );
                  ref.invalidate(stocksProvider(widget.fy.id));
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, errorText(e));
                }
              },
            ),
          ],
          ),
          for (final message in [widget.warning, _groupingWarning()].whereType<String>())
            Padding(
              padding: const EdgeInsets.only(top: AkSpace.s2),
              child: AkBanner(kind: AkBannerKind.warning, child: Text(message)),
            ),
        ]),
      ),
    );
  }

  /// Avertissement si le compte de variation choisi est un compte de regroupement (AN-37).
  String? _groupingWarning() {
    final chosen = widget.variationAccounts.where((v) => v.id == _variation).firstOrNull;
    if (chosen == null) return null;
    return StockHint.groupingVariation(chosen.code, widget.allCodes);
  }
}
