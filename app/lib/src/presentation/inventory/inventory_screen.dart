import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entities_providers.dart';
import 'accruals_tab.dart';
import 'assets_tab.dart';
import 'fx_tab.dart';
import 'provisions_tab.dart';
import 'stocks_tab.dart';

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
