import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/entities_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entity_models.dart';
import 'entity_detail_screen.dart';
import 'entity_form.dart';

/// Assistant d'ouverture en 5 étapes : fiche entité → exercice → plan de comptes → journaux → soldes d'ouverture (§10.2).
class EntityWizardScreen extends ConsumerStatefulWidget {
  const EntityWizardScreen({super.key});

  @override
  ConsumerState<EntityWizardScreen> createState() => _EntityWizardScreenState();
}

class _EntityWizardScreenState extends ConsumerState<EntityWizardScreen> {
  int _step = 0;
  EntityDetail? _entity;
  FiscalYear? _fiscalYear;
  int? _accountCount;
  final Set<String> _journalCodes = {};
  final Map<String, String?> _treasuryAccounts = {}; // code journal → compte de trésorerie
  List<AccountRef> _class5 = const [];
  String? _error;

  static const titles = ['Fiche entité', 'Exercice', 'Plan de comptes', 'Journaux', 'Soldes d\'ouverture'];

  @override
  Widget build(BuildContext context) {
    final cabinet = ref.watch(currentCabinetProvider).value;
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              for (var i = 0; i < titles.length; i++) ...[
                CircleAvatar(radius: 12, backgroundColor: i <= _step ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))),
                const SizedBox(width: 6),
                Text(titles[i], style: TextStyle(fontWeight: i == _step ? FontWeight.w600 : FontWeight.normal)),
                if (i < titles.length - 1) const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.chevron_right, size: 18)),
              ],
            ]),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        Expanded(child: _body(cabinet?.id)),
      ],
    );
  }

  Widget _body(String? cabinetId) {
    switch (_step) {
      case 0:
        return EntityForm(
          submitLabel: 'Créer le dossier et continuer',
          onSubmit: (input) async {
            if (cabinetId == null) throw Exception('Cabinet inconnu');
            final e = await ref.read(entitiesRepositoryProvider).create(cabinetId, input);
            final count = await ref.read(entitiesRepositoryProvider).accountCount(e.id);
            ref.invalidate(entitiesListProvider);
            ref.invalidate(entityDashboardProvider);
            setState(() {
              _entity = e;
              _accountCount = count;
              _step = 1;
            });
          },
        );
      case 1:
        return _StepCard(
          title: 'Premier exercice',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fiscalYear == null ? 'Définissez les dates du premier exercice, le capital et l\'effectif.' : 'Exercice ${_fiscalYear!.label} créé : 12 périodes mensuelles générées.'),
            const SizedBox(height: 12),
            Row(children: [
              if (_fiscalYear == null)
                FilledButton(
                  key: const Key('wizard-create-fy'),
                  onPressed: () async {
                    final fy = await showDialog<FiscalYear>(context: context, builder: (_) => FiscalYearDialog(entity: _entity!));
                    if (fy != null) setState(() => _fiscalYear = fy);
                  },
                  child: const Text('Créer l\'exercice'),
                ),
              if (_fiscalYear != null) FilledButton(onPressed: () => setState(() => _step = 2), child: const Text('Continuer')),
            ]),
          ]),
        );
      case 2:
        return _StepCard(
          title: 'Plan de comptes',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Le plan de référence SYSCOHADA révisé a été copié : ${_accountCount ?? '…'} comptes à ${_entity!.accountLength} chiffres. Vous pourrez le subdiviser à tout moment dans Référentiels.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final templates = await ref.read(entitiesRepositoryProvider).journalTemplates();
                final accounts = await ref.read(entitiesRepositoryProvider).treasuryAccounts(_entity!.id);
                setState(() {
                  _journalCodes.addAll(templates.where((t) => t.isDefaultChecked && t.type != 'opening').map((t) => t.code));
                  _class5 = accounts;
                  _step = 3;
                });
              },
              child: const Text('Continuer'),
            ),
          ]),
        );
      case 3:
        final templates = ref.watch(journalTemplatesProvider).value ?? const <JournalTemplate>[];
        return _StepCard(
          title: 'Journaux',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Modèle du cabinet, coché par défaut et modifiable. Le journal des à-nouveaux est imposé. Un journal de banque ou de caisse est relié à son compte de trésorerie.'),
            const SizedBox(height: 8),
            for (final t in templates.where((t) => t.type != 'opening'))
              Row(children: [
                Checkbox(value: _journalCodes.contains(t.code), onChanged: (v) => setState(() => v == true ? _journalCodes.add(t.code) : _journalCodes.remove(t.code))),
                SizedBox(width: 60, child: Text(t.code, style: const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 180, child: Text(t.label)),
                if (t.isTreasury && _journalCodes.contains(t.code))
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Compte de trésorerie'),
                      value: _treasuryAccounts[t.code],
                      items: [for (final a in _class5) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.label}', overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => setState(() => _treasuryAccounts[t.code] = v),
                    ),
                  ),
              ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final repo = ref.read(entitiesRepositoryProvider);
                try {
                  final plain = templates.where((t) => _journalCodes.contains(t.code) && !t.isTreasury).map((t) => t.code).toList();
                  await repo.createJournalsFromTemplate(_entity!.id, plain);
                  for (final t in templates.where((t) => _journalCodes.contains(t.code) && t.isTreasury)) {
                    final acc = _treasuryAccounts[t.code];
                    if (acc == null) throw Exception('Choisissez le compte de trésorerie du journal ${t.code}');
                    await repo.createTreasuryJournal(_entity!.cabinetId, _entity!.id, code: t.code, label: t.label, type: t.type, accountId: acc);
                  }
                  setState(() {
                    _error = null;
                    _step = 4;
                  });
                } catch (e) {
                  setState(() => _error = '$e');
                }
              },
              child: const Text('Créer les journaux et continuer'),
            ),
          ]),
        );
      default:
        return _StepCard(
          title: 'Soldes d\'ouverture',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Comment reprendre les soldes d\'ouverture ?'),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () => context.go('/import'), icon: const Icon(Icons.upload_file_outlined), label: const Text('Importer depuis Perfecto')),
              OutlinedButton.icon(onPressed: () => context.go('/saisie'), icon: const Icon(Icons.edit_note_outlined), label: const Text('Saisir les à-nouveaux')),
              OutlinedButton.icon(onPressed: () => context.go('/dossiers/${_entity!.id}'), icon: const Icon(Icons.schedule), label: const Text('Plus tard')),
            ]),
            const SizedBox(height: 8),
            const Text('La reprise automatique depuis N-1 n\'est possible que pour les exercices suivants.', style: TextStyle(fontSize: 12)),
          ]),
        );
    }
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              child,
            ]),
          ),
        ),
      ],
    );
  }
}
