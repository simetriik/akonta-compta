import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

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
    final t = context.ak;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, AkSpace.s3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AkPageHead(title: 'Ouvrir un dossier', subtitle: 'Assistant d\'ouverture'),
            const SizedBox(height: AkSpace.s3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                for (var i = 0; i < titles.length; i++) ...[
                  _StepDot(index: i, current: _step),
                  Text(titles[i], style: (i == _step ? AkText.bodyStrong : AkText.body).copyWith(color: i <= _step ? t.text : t.textMuted)),
                  if (i < titles.length - 1) Icon(Icons.chevron_right, size: 18, color: t.borderControl),
                ],
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Text('Étape ${_step + 1} sur ${titles.length}', style: AkText.caption.copyWith(color: t.textMuted)),
          ]),
        ),
        if (_error != null) Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: AkBanner(kind: AkBannerKind.danger, child: Text(_error!))),
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
                SizedBox(width: 60, child: Text(t.code, style: AkText.code.copyWith(fontWeight: FontWeight.w600))),
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
            Text('La reprise automatique depuis N-1 n\'est possible que pour les exercices suivants.', style: AkText.caption.copyWith(color: context.ak.textMuted)),
          ]),
        );
    }
  }
}

/// Pastille numérotée d'étape : terracotta pour l'étape courante, coche pour les étapes terminées.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.current});

  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final done = index < current;
    final active = index <= current;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? t.brand : t.surfaceSunken, shape: BoxShape.circle, border: active ? null : Border.all(color: t.borderControl)),
      child: done ? Icon(Icons.check, size: 16, color: t.surface) : Text('${index + 1}', style: AkText.label.copyWith(color: active ? t.surface : t.textMuted, letterSpacing: 0)),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AkSpace.s2, pad, pad),
      children: [
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AkText.heading.copyWith(color: context.ak.text)),
            const SizedBox(height: AkSpace.s3),
            child,
          ]),
        ),
      ],
    );
  }
}
