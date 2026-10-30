import 'package:flutter/material.dart';

import '../../src/core/formatting.dart';
import '../../src/domain/reference_models.dart';
import '../design.dart';

/// Catalogue des composants du système de design (mode développement : route `/catalogue`).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _text = TextEditingController(text: 'Valeur saisie');
  final _amount = TextEditingController(text: '1 250 000');
  final _date = TextEditingController(text: '26/10/2026');
  String? _choice = 'a';
  bool _check = true;
  bool _switch = false;
  String _segment = 'debit';

  static const _accounts = [
    Account(id: '1', code: '4111000', label: 'Clients', classNo: 4, normalSide: 'debit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true),
    Account(id: '2', code: '5210000', label: 'Banques locales', classNo: 5, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true),
  ];

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AkSpace.s4),
        child: AkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AkSectionTitle(title), const SizedBox(height: AkSpace.s3), child])),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Scaffold(
      body: AkPage(children: [
        const AkPageHead(title: 'Catalogue des composants', subtitle: 'Système de design Akonta'),
        const SizedBox(height: AkSpace.s4),
        _section(
          'Palette',
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
            for (final (n, c) in [('brand', t.accent), ('brandTint', t.rowSelected), ('success', t.success), ('warning', t.warning), ('danger', t.danger), ('info', t.info), ('surfaceSunken', t.surfaceSunken), ('border', t.border), ('text', t.text), ('textMuted', t.textMuted)])
              Column(children: [Container(width: 72, height: 40, decoration: BoxDecoration(color: c, borderRadius: AkRadius.mdAll, border: Border.all(color: t.border))), Text(n, style: AkText.caption)]),
          ]),
        ),
        _section(
          'Typographie',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Titre d\'écran (Poppins)', style: AkText.titleLg),
            Text('Titre de section', style: AkText.title),
            Text('Corps de texte IBM Plex Sans 14 px', style: AkText.body),
            Text('Libellé de champ', style: AkText.label),
            Text('1 234 567 890 (Plex Mono, chiffres tabulaires)', style: AkText.amount),
          ]),
        ),
        _section(
          'Boutons',
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
            AkButton.primary('Primaire', onPressed: () {}),
            AkButton.secondary('Secondaire', onPressed: () {}),
            AkButton.danger('Danger', onPressed: () {}),
            AkButton.dangerOutline('Danger secondaire', onPressed: () {}),
            AkButton.ghost('Discret', onPressed: () {}),
            AkButton.primary('Avec icône', icon: Icons.add, onPressed: () {}),
            const AkButton.primary('Désactivé', onPressed: null),
            AkButton.primary('Chargement', loading: true, onPressed: () {}),
            AkIconButton(icon: Icons.delete_outline, tooltip: 'Supprimer', onPressed: () {}),
          ]),
        ),
        _section(
          'Champs',
          Wrap(spacing: AkSpace.s4, runSpacing: AkSpace.s4, children: [
            SizedBox(width: 280, child: AkTextField(controller: _text, label: 'Champ texte', helper: 'Texte d\'aide')),
            SizedBox(width: 280, child: AkTextField(label: 'Champ en erreur', errorText: 'Ce champ est obligatoire', required: true)),
            SizedBox(width: 280, child: AkAmountField(controller: _amount, label: 'Montant')),
            SizedBox(width: 280, child: AkDateField(controller: _date, label: 'Date')),
            SizedBox(
              width: 280,
              child: AkDropdown<String>(label: 'Liste déroulante', value: _choice, items: const [AkOption('a', 'Option A'), AkOption('b', 'Option B')], onChanged: (v) => setState(() => _choice = v)),
            ),
            SizedBox(width: 280, child: AkAccountField(label: 'Compte', accounts: _accounts, onSelected: (_) {})),
            SizedBox(width: 280, child: AkTextField(label: 'Désactivé', enabled: false, initialValue: 'Lecture seule')),
          ]),
        ),
        _section(
          'Choix',
          Wrap(spacing: AkSpace.s4, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            AkCheckbox(value: _check, label: 'Case à cocher', onChanged: (v) => setState(() => _check = v)),
            AkSwitch(value: _switch, label: 'Interrupteur', onChanged: (v) => setState(() => _switch = v)),
            AkSegmented<String>(options: const [AkOption('debit', 'Débit'), AkOption('credit', 'Crédit')], selected: _segment, onChanged: (v) => setState(() => _segment = v)),
          ]),
        ),
        _section(
          'Statuts et badges',
          Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [for (final s in AkEntryStatus.values) AkStatusBadge(s), const AkKbd('Ctrl B')]),
        ),
        _section(
          'Messages',
          Column(spacing: AkSpace.s2, children: [
            for (final k in AkBannerKind.values) AkBanner(kind: k, child: Text('Message de type ${k.name}')),
            SizedBox(height: 160, child: AkEmptyState('Aucune écriture pour cette période.', title: 'Rien à afficher', action: AkButton.secondary('Nouvelle écriture', onPressed: () {}))),
            SizedBox(height: 120, child: AkErrorMessage('Erreur : réseau indisponible', onRetry: () {})),
          ]),
        ),
        _section(
          'Tableau dense',
          AkTable<(String, String, int)>(
            minWidth: 480,
            footerLabel: 'Totaux',
            columns: [
              AkColumn.text(label: 'Compte', width: 120, text: (r) => r.$1),
              AkColumn.text(label: 'Intitulé', text: (r) => r.$2),
              AkColumn.text(label: 'Solde', width: 140, numeric: true, text: (r) => Fmt.fcfa(r.$3), footer: '1 650 000'),
            ],
            rows: const [('4111000', 'Clients', 1250000), ('5210000', 'Banques locales', 400000)],
          ),
        ),
        _section(
          'Dialogue',
          AkButton.secondary('Ouvrir un dialogue', onPressed: () => showAkConfirm(context, title: 'Confirmer', message: 'Voulez-vous continuer ?')),
        ),
      ]),
    );
  }
}
