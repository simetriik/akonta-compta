import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

import '../widgets/require_entity.dart';
import 'accounts_tab.dart';
import 'journals_tab.dart';
import 'tax_rates_tab.dart';
import 'templates_tab.dart';
import 'third_parties_tab.dart';

/// Référentiels du dossier courant : plan de comptes, tiers, journaux, modèles d'écritures, taux (§10.3).
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireEntity(
      builder: (entity) {
        final margin = akPageMargin(context);
        return DefaultTabController(
          length: 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AkPageHead(title: 'Référentiels', subtitle: entity.dossierLabel),
                const SizedBox(height: AkSpace.s3),
                Expanded(
                  child: AkCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Column(
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.symmetric(horizontal: AkSpace.s2),
                          tabs: [
                            Tab(text: 'Plan de comptes'),
                            Tab(text: 'Tiers'),
                            Tab(text: 'Journaux'),
                            Tab(text: 'Modèles d\'écritures'),
                            Tab(text: 'Taux'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              AccountsTab(entity: entity),
                              ThirdPartiesTab(entity: entity),
                              JournalsTab(entity: entity),
                              TemplatesTab(entity: entity),
                              const TaxRatesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Liste déroulante compacte de barre d'outils (largeur bornée).
