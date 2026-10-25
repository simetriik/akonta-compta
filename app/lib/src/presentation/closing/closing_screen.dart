import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/closing_repository.dart';
import '../../data/entities_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../inventory/inventory_screen.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

/// Assistant de clôture (§10.9) : contrôles → inventaire → fiscalité → états financiers → clôture provisoire → arrêté définitif → N+1.
class ClosingScreen extends StatelessWidget {
  const ClosingScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _ClosingBody(entity: entity));
}

class _ClosingBody extends ConsumerStatefulWidget {
  const _ClosingBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_ClosingBody> createState() => _ClosingBodyState();
}

class _ClosingBodyState extends ConsumerState<_ClosingBody> {
  FiscalYear? _fy;
  int _step = 0;

  static const steps = ['Contrôles', 'Inventaire', 'Fiscalité', 'États financiers', 'Clôture provisoire', 'Arrêté définitif', 'Exercice N+1'];

  @override
  Widget build(BuildContext context) {
    final fys = ref.watch(fiscalYearsProvider(widget.entity.id));
    return AsyncView(
      value: fys,
      builder: (list) {
        _fy ??= list.where((f) => f.status != 'closed').firstOrNull ?? list.lastOrNull;
        final fy = _fy;
        if (fy == null) return const Center(child: Text('Aucun exercice.'));
        return Column(children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Clôture de l\'exercice', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: fy.id,
                    items: [for (final f in list) DropdownMenuItem(value: f.id, child: Text('${f.label} · ${f.statusLabel}'))],
                    onChanged: (v) => setState(() => _fy = list.where((f) => f.id == v).firstOrNull),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [for (var i = 0; i < steps.length; i++) ChoiceChip(label: Text('${i + 1}. ${steps[i]}'), selected: _step == i, onSelected: (_) => setState(() => _step = i))]),
              ]),
            ),
          ),
          Expanded(child: _stepBody(fy, list)),
        ]);
      },
    );
  }

  Widget _stepBody(FiscalYear fy, List<FiscalYear> all) {
    switch (_step) {
      case 0:
        return ChecksStep(entity: widget.entity, fy: fy);
      case 1:
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Les travaux d\'inventaire (amortissements, stocks, provisions, régularisations, écarts de conversion) se préparent dans le module dédié ; leurs brouillards se valident dans Saisie.'), const SizedBox(height: 12), FilledButton(onPressed: () => context.go('/inventaire'), child: const Text('Ouvrir les travaux d\'inventaire'))]));
      case 2:
        return TaxStep(entity: widget.entity, fy: fy);
      case 3:
        return StatementsStep(entity: widget.entity, fy: fy);
      case 4:
        return ProvisionalStep(entity: widget.entity, fy: fy, onChanged: () => ref.invalidate(fiscalYearsProvider(widget.entity.id)));
      case 5:
        return FinalStep(entity: widget.entity, fy: fy, onChanged: () => ref.invalidate(fiscalYearsProvider(widget.entity.id)));
      default:
        return NextYearStep(entity: widget.entity, fy: fy, next: all.where((f) => f.startDate == fy.endDate.add(const Duration(days: 1))).firstOrNull);
    }
  }
}

class ChecksStep extends ConsumerStatefulWidget {
  const ChecksStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<ChecksStep> createState() => _ChecksStepState();
}

class _ChecksStepState extends ConsumerState<ChecksStep> {
  late Future<List<ClosingCheck>> _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id);

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canWaive = perms.has('closing.override_alerts', entityId: widget.entity.id);
    return FutureBuilder<List<ClosingCheck>>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text(frenchRpcError(snap.error!)));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final checks = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Text('Contrôles de clôture', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(onPressed: () => setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id)), icon: const Icon(Icons.refresh), label: const Text('Relancer')),
            ]),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                for (final c in checks)
                  ListTile(
                    leading: Icon(
                      c.status == 'passed' ? Icons.check_circle : (c.status == 'waived' ? Icons.remove_circle_outline : (c.severity == 'blocking' ? Icons.error : Icons.warning_amber)),
                      color: c.status == 'passed' ? AkColors.validated : (c.status == 'waived' ? AkColors.reviewed : (c.severity == 'blocking' ? AkColors.toCorrect : AkColors.draft)),
                    ),
                    title: Text(c.label),
                    subtitle: Text('${c.severity == 'blocking' ? 'Bloquant' : 'Alerte'} · ${c.status == 'passed' ? 'conforme' : c.status == 'waived' ? 'levée' : 'en échec'}${c.details.isEmpty ? '' : ' · ${c.details}'}'),
                    trailing: c.status == 'failed' && c.severity == 'warning' && canWaive
                        ? TextButton(
                            onPressed: () async {
                              final ctrl = TextEditingController();
                              final comment = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text('Lever : ${c.label}'), content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Commentaire (obligatoire)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Lever l\'alerte'))]));
                              if (comment == null || comment.trim().isEmpty) return;
                              try {
                                await ref.read(closingRepositoryProvider).waive(widget.fy.id, c.code, comment.trim());
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                              }
                              setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id));
                            },
                            child: const Text('Lever'),
                          )
                        : null,
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class TaxStep extends ConsumerStatefulWidget {
  const TaxStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<TaxStep> createState() => _TaxStepState();
}

class _TaxStepState extends ConsumerState<TaxStep> {
  List<TaxAdjustment>? _adjustments;
  TaxComputation? _result;
  int? _accounting;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(closingRepositoryProvider);
    final adj = await repo.proposeAdjustments(widget.entity.id, widget.fy.id);
    final acc = await repo.accountingResult(widget.entity.id, widget.fy.id);
    final res = await repo.taxComputation(widget.fy.id);
    if (!mounted) return;
    setState(() {
      _adjustments = adj;
      _accounting = acc;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final adj = _adjustments;
    if (adj == null) return const Center(child: CircularProgressIndicator());
    final addBacks = adj.where((a) => a.kind == 'add_back').fold<int>(0, (s, a) => s + a.amount);
    final deductions = adj.where((a) => a.kind == 'deduction').fold<int>(0, (s, a) => s + a.amount);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tableau de passage du résultat comptable au résultat fiscal', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Résultat comptable avant impôt : ${Fmt.fcfa(_accounting, showZero: true)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final a in adj)
                Row(children: [
                  SizedBox(width: 120, child: Text(a.kind == 'add_back' ? 'Réintégration' : 'Déduction', style: TextStyle(color: a.kind == 'add_back' ? AkColors.toCorrect : AkColors.validated, fontSize: 12))),
                  Expanded(child: Text(a.label)),
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      initialValue: a.amount == 0 ? '' : '${a.amount}',
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => setState(() => a.amount = Fmt.parseAmount(v) ?? 0),
                    ),
                  ),
                ]),
              const Divider(),
              Text('Résultat fiscal : ${Fmt.fcfa((_accounting ?? 0) + addBacks - deductions, showZero: true)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final r = await ref.read(closingRepositoryProvider).computeTax(widget.entity.id, widget.fy.id, adj);
                          setState(() => _result = r);
                          ref.invalidate(entityDashboardProvider);
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calculer l\'IS et générer l\'écriture (brouillard)'),
              ),
            ]),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Impôt sur les sociétés', style: Theme.of(context).textTheme.titleMedium),
                Text('IS au taux de ${(_result!.isRate * 100).toStringAsFixed(0)} % : ${Fmt.fcfa(_result!.computedTax, showZero: true)}'),
                Text('Minimum d\'impôt (sur CA ${Fmt.fcfa(_result!.revenue, showZero: true)}, plancher 250 000) : ${Fmt.fcfa(_result!.minimumTax, showZero: true)}'),
                Text('IS dû : ${Fmt.fcfa(_result!.taxDue, showZero: true)} · acomptes 4492 : ${Fmt.fcfa(_result!.prepayments, showZero: true)} · solde à payer : ${Fmt.fcfa(_result!.balanceDue, showZero: true)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_result!.entryId != null) TextButton(onPressed: () => context.go('/saisie/${_result!.entryId}'), child: const Text('Ouvrir l\'écriture d\'IS')),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

class StatementsStep extends ConsumerStatefulWidget {
  const StatementsStep({super.key, required this.entity, required this.fy});

  final EntitySummary entity;
  final FiscalYear fy;

  @override
  ConsumerState<StatementsStep> createState() => _StatementsStepState();
}

class _StatementsStepState extends ConsumerState<StatementsStep> {
  FinancialStatements? _fs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(closingRepositoryProvider).latestStatements(widget.fy.id).then((v) {
      if (mounted) setState(() => _fs = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fs = _fs;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('États financiers SYSCOHADA (système normal)', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final v = await ref.read(closingRepositoryProvider).generateStatements(widget.entity.id, widget.fy.id);
                      setState(() => _fs = v);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Générer les états'),
          ),
        ]),
        if (fs == null) const Padding(padding: EdgeInsets.all(16), child: Text('Aucun état généré pour cet exercice.')),
        if (fs != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Généré le ${Fmt.date(fs.generatedAt)}${fs.isFinal ? ' · arrêté' : ''}'),
                for (final c in fs.checks)
                  Row(children: [
                    Icon((c['passed'] as bool?) == true ? Icons.check_circle : Icons.error, size: 16, color: (c['passed'] as bool?) == true ? AkColors.validated : AkColors.toCorrect),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${c['label']}')),
                  ]),
                const SizedBox(height: 8),
                const Text('Export : modèle Excel DGI (macros conservées) et PDF via Consultation → Exporter → États financiers (lot 3, service de documents).', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _PostsTable(title: 'Bilan — Actif', posts: fs.assets, previous: fs.previous?['assets']),
          const SizedBox(height: 12),
          _PostsTable(title: 'Bilan — Passif', posts: fs.liabilities, previous: fs.previous?['liabilities']),
          const SizedBox(height: 12),
          _PostsTable(title: 'Compte de résultat', posts: fs.income, previous: fs.previous?['income']),
        ],
      ],
    );
  }
}

class _PostsTable extends StatelessWidget {
  const _PostsTable({required this.title, required this.posts, this.previous});

  final String title;
  final List<StatementPost> posts;
  final List<StatementPost>? previous;

  @override
  Widget build(BuildContext context) {
    final prev = {for (final p in previous ?? const <StatementPost>[]) '${p.code}/${p.columnRole}': p.amount};
    final byCode = <String, Map<String, dynamic>>{};
    for (final p in posts) {
      final e = byCode.putIfAbsent(p.code, () => {'label': p.label, 'gross': 0, 'dep': 0, 'amount': 0});
      if (p.columnRole == 'gross') {
        e['gross'] = p.amount;
      } else if (p.columnRole == 'depreciation') {
        e['dep'] = p.amount;
      } else {
        e['amount'] = p.amount;
      }
    }
    final hasGross = posts.any((p) => p.columnRole == 'gross');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final e in byCode.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 40, child: Text(e.key, style: const TextStyle(fontFamily: 'monospace'))),
                Expanded(child: Text(e.value['label'] as String, overflow: TextOverflow.ellipsis)),
                if (hasGross) ...[
                  SizedBox(width: 130, child: Text(Fmt.fcfa(e.value['gross'] as int), textAlign: TextAlign.right)),
                  SizedBox(width: 130, child: Text(Fmt.fcfa(e.value['dep'] as int), textAlign: TextAlign.right)),
                  SizedBox(width: 130, child: Text(Fmt.fcfa((e.value['gross'] as int) - (e.value['dep'] as int), showZero: true), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                ] else
                  SizedBox(width: 130, child: Text(Fmt.fcfa(e.value['amount'] as int, showZero: true), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (previous != null) SizedBox(width: 130, child: Text(Fmt.fcfa(prev['${e.key}/${hasGross ? 'gross' : 'amount'}'] ?? 0), textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
              SizedBox(
                width: 130,
                child: Text(Fmt.fcfa(hasGross ? byCode.values.fold<int>(0, (s, e) => s + (e['gross'] as int) - (e['dep'] as int)) : byCode.values.fold<int>(0, (s, e) => s + (e['amount'] as int)), showZero: true), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ProvisionalStep extends ConsumerWidget {
  const ProvisionalStep({super.key, required this.entity, required this.fy, required this.onChanged});

  final EntitySummary entity;
  final FiscalYear fy;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(closingRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exercice ${fy.label} · ${fy.statusLabel}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('1. Générer et valider l\'écriture de détermination du résultat (soldes des classes 6, 7, 8 vers 131 / 139).\n2. Clôture provisoire : tous les contrôles bloquants conformes, alertes levées avec commentaire ; les périodes sont verrouillées.\n3. Réouverture possible avec motif tant que l\'arrêté définitif n\'est pas prononcé.'),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => runGeneration(context, ref, () => repo.generateResultEntry(entity.id, fy.id), 'Détermination du résultat'), icon: const Icon(Icons.functions), label: const Text('Écriture de résultat')),
                FilledButton.icon(
                  onPressed: fy.status != 'open'
                      ? null
                      : () async {
                          try {
                            await repo.closeProvisional(entity.id, fy.id);
                            onChanged();
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clôture provisoire prononcée.')));
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                          }
                        },
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Clôture provisoire'),
                ),
                OutlinedButton.icon(
                  onPressed: fy.status != 'closing'
                      ? null
                      : () async {
                          final ctrl = TextEditingController();
                          final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Réouvrir l\'exercice'), content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Réouvrir'))]));
                          if (reason == null || reason.trim().isEmpty) return;
                          try {
                            await repo.reopen(entity.id, fy.id, reason.trim());
                            onChanged();
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                          }
                        },
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Réouvrir (motif)'),
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class FinalStep extends ConsumerStatefulWidget {
  const FinalStep({super.key, required this.entity, required this.fy, required this.onChanged});

  final EntitySummary entity;
  final FiscalYear fy;
  final VoidCallback onChanged;

  @override
  ConsumerState<FinalStep> createState() => _FinalStepState();
}

class _FinalStepState extends ConsumerState<FinalStep> {
  final _confirm = TextEditingController();
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final can = perms.has('closing.final');
    final expected = 'ARRETER ${widget.fy.label}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arrêté définitif de l\'exercice ${widget.fy.label}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Réservé à l\'associé (TOTP vérifié). L\'exercice devient intangible : aucune réouverture. Les états financiers, le grand livre et la balance sont archivés avec leurs empreintes SHA-256.'),
              const SizedBox(height: 12),
              CheckboxListTile(value: _acknowledged, onChanged: can ? (v) => setState(() => _acknowledged = v ?? false) : null, title: const Text('J\'ai vérifié les états financiers et je comprends que cette action est irréversible.'), contentPadding: EdgeInsets.zero),
              TextField(controller: _confirm, enabled: can && _acknowledged, decoration: InputDecoration(labelText: 'Tapez « $expected » pour confirmer'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AkColors.toCorrect),
                onPressed: !can || !_acknowledged || _confirm.text.trim() != expected || widget.fy.status != 'closing'
                    ? null
                    : () async {
                        try {
                          final archive = await ref.read(closingRepositoryProvider).closeFinal(widget.entity.id, widget.fy.id, _confirm.text.trim());
                          widget.onChanged();
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exercice arrêté. Archive $archive.')));
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(frenchRpcError(e)), backgroundColor: AkColors.toCorrect));
                        }
                      },
                icon: const Icon(Icons.gavel),
                label: const Text('Arrêter définitivement'),
              ),
              if (widget.fy.status != 'closing') const Padding(padding: EdgeInsets.only(top: 8), child: Text('L\'exercice doit être en clôture provisoire.', style: TextStyle(fontSize: 12))),
              if (!can) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Votre rôle ne permet pas l\'arrêté définitif.', style: TextStyle(fontSize: 12))),
            ]),
          ),
        ),
      ],
    );
  }
}

class NextYearStep extends ConsumerStatefulWidget {
  const NextYearStep({super.key, required this.entity, required this.fy, this.next});

  final EntitySummary entity;
  final FiscalYear fy;
  final FiscalYear? next;

  @override
  ConsumerState<NextYearStep> createState() => _NextYearStepState();
}

class _NextYearStepState extends ConsumerState<NextYearStep> {
  final _legal = TextEditingController(text: '0');
  final _free = TextEditingController(text: '0');
  final _div = TextEditingController(text: '0');
  final _carry = TextEditingController(text: '0');
  final _date = TextEditingController(text: Fmt.date(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(closingRepositoryProvider);
    final next = widget.next;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exercice suivant', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (next == null) Row(children: [const Expanded(child: Text('Créez l\'exercice suivant dans Dossiers → Exercices avant de générer les à-nouveaux.')), TextButton(onPressed: () => context.go('/dossiers/${widget.entity.id}'), child: const Text('Ouvrir le dossier'))]),
              if (next != null) ...[
                Text('À-nouveaux de ${next.label} : soldes de bilan à la clôture de ${widget.fy.label}, détaillés par tiers ; résultat repris en 1300. Recalculables tant que ${widget.fy.label} n\'est pas arrêté (brouillard remplacé).'),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: () => runGeneration(context, ref, () => repo.generateOpeningBalances(widget.entity.id, widget.fy.id), 'À-nouveaux ${next.label}'), icon: const Icon(Icons.auto_awesome), label: Text('Générer les à-nouveaux ${next.label}')),
                const Divider(height: 24),
                Text('Affectation du résultat de ${widget.fy.label} (en ${next.label})', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(width: 160, child: TextField(controller: _legal, decoration: const InputDecoration(labelText: 'Réserve légale (111)'))),
                  SizedBox(width: 160, child: TextField(controller: _free, decoration: const InputDecoration(labelText: 'Réserves libres (118)'))),
                  SizedBox(width: 160, child: TextField(controller: _div, decoration: const InputDecoration(labelText: 'Dividendes (465)'))),
                  SizedBox(width: 160, child: TextField(controller: _carry, decoration: const InputDecoration(labelText: 'Report à nouveau (121)'))),
                  SizedBox(width: 130, child: TextField(controller: _date, decoration: const InputDecoration(labelText: 'Date'))),
                ]),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final d = Fmt.parseDate(_date.text);
                    if (d == null) return;
                    runGeneration(context, ref, () => repo.allocateResult(widget.entity.id, next.id, d, legalReserve: Fmt.parseAmount(_legal.text) ?? 0, freeReserve: Fmt.parseAmount(_free.text) ?? 0, dividends: Fmt.parseAmount(_div.text) ?? 0, carryForward: Fmt.parseAmount(_carry.text) ?? 0), 'Affectation du résultat');
                  },
                  icon: const Icon(Icons.call_split),
                  label: const Text('Générer l\'écriture d\'affectation'),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
