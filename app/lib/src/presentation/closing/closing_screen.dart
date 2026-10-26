import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/closing_repository.dart';
import '../../data/consultation_repository.dart';
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
  void didUpdateWidget(covariant _ClosingBody old) {
    super.didUpdateWidget(old);
    // Changement de dossier : on repart de l'exercice ouvert et de la première étape.
    if (old.entity.id != widget.entity.id) {
      _fy = null;
      _step = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fys = ref.watch(fiscalYearsProvider(widget.entity.id));
    return AsyncView(
      value: fys,
      builder: (list) {
        _fy ??= list.where((f) => f.status != 'closed').firstOrNull ?? list.lastOrNull;
        final fy = _fy;
        if (fy == null) return const Center(child: Text('Aucun exercice.'));
        final pad = akPagePadding(context);
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AkPageHead(
                title: 'Clôture de l\'exercice',
                subtitle: widget.entity.name,
                actions: [
                  DropdownButton<String>(
                    value: fy.id,
                    items: [for (final f in list) DropdownMenuItem(value: f.id, child: Text('${f.label} · ${f.statusLabel}'))],
                    onChanged: (v) => setState(() => _fy = list.where((f) => f.id == v).firstOrNull),
                  ),
                ],
              ),
              const SizedBox(height: AkSpace.s4),
              _Stepper(steps: steps, current: _step, onTap: (i) => setState(() => _step = i)),
            ]),
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
        return ListView(padding: _bodyPad(context), children: [
          AkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Travaux d\'inventaire', style: AkText.heading.copyWith(color: context.ak.text)),
              const SizedBox(height: AkSpace.s2),
              Text('Les travaux d\'inventaire (amortissements, stocks, provisions, régularisations, écarts de conversion) se préparent dans le module dédié ; leurs brouillards se valident dans Saisie.', style: AkText.body.copyWith(color: context.ak.textMuted)),
              const SizedBox(height: AkSpace.s3),
              FilledButton.icon(onPressed: () => context.go('/inventaire'), icon: const Icon(Icons.inventory_2_outlined, size: 18), label: const Text('Ouvrir les travaux d\'inventaire')),
            ]),
          ),
        ]);
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

/// Marge des corps d'étape : latérale selon la taille d'écran, 16 px en haut et en bas.
EdgeInsets _bodyPad(BuildContext context) => EdgeInsets.symmetric(horizontal: akPagePadding(context).left, vertical: AkSpace.s4);

/// Indicateur d'étapes : cercles numérotés (coche pour les étapes passées), reliés par un filet.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.steps, required this.current, required this.onTap});

  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    Widget item(int i) {
      final done = i < current;
      final active = i == current;
      final circle = Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? t.brand : (done ? t.successTint : t.surfaceSunken)),
        child: done
            ? Icon(Icons.check, size: 16, color: t.success)
            : Text('${i + 1}', style: AkText.label.copyWith(color: active ? t.onBrand : t.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0)),
      );
      return Semantics(
        button: true,
        selected: active,
        child: InkWell(
          borderRadius: AkRadius.mdAll,
          onTap: () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              circle,
              const SizedBox(width: AkSpace.s2),
              Text('${i + 1}. ${steps[i]}', style: AkText.table.copyWith(color: active ? t.brandText : (done ? t.text : t.textMuted), fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }

    Widget line(int i, {required bool flex}) {
      final bar = Container(height: 2, width: flex ? null : 20, color: i < current ? t.success : t.border);
      return flex ? Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2), child: bar)) : Padding(padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2), child: bar);
    }

    return AkCard(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1080;
        final row = Row(mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min, children: [
          for (var i = 0; i < steps.length; i++) ...[
            item(i),
            if (i < steps.length - 1) line(i, flex: wide),
          ],
        ]);
        return wide ? row : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
      }),
    );
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
        final t = context.ak;
        final blocking = checks.where((c) => c.status == 'failed' && c.severity == 'blocking').length;
        return ListView(
          padding: _bodyPad(context),
          children: [
            Row(children: [
              Text('Contrôles de clôture', style: AkText.heading.copyWith(color: t.text)),
              const Spacer(),
              OutlinedButton.icon(onPressed: () => setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id)), icon: const Icon(Icons.refresh, size: 18), label: const Text('Relancer')),
            ]),
            const SizedBox(height: AkSpace.s3),
            if (blocking > 0) ...[
              AkBanner(
                kind: AkBannerKind.danger,
                icon: Icons.block,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$blocking contrôle${blocking > 1 ? 's bloquants empêchent' : ' bloquant empêche'}', style: AkText.bodyStrong),
                  const TextSpan(text: ' de prononcer la clôture. Les alertes peuvent être levées avec un commentaire.'),
                ])),
              ),
              const SizedBox(height: AkSpace.s3),
            ],
            akRowsCard(context, [
              for (final c in checks)
                _checkRow(context, c, canWaive),
            ]),
          ],
        );
      },
    );
  }

  Widget _checkRow(BuildContext context, ClosingCheck c, bool canWaive) {
    final t = context.ak;
    final passed = c.status == 'passed';
    final waived = c.status == 'waived';
    final blocking = c.severity == 'blocking';
    final (icon, color) = passed ? (Icons.check_circle, t.success) : (waived ? (Icons.remove_circle_outline, t.info) : (blocking ? (Icons.cancel, t.danger) : (Icons.warning_amber, t.warning)));
    final badge = passed
        ? AkBadge(label: 'Conforme', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
        : waived
            ? AkBadge(label: 'Levée', color: t.info, tint: t.infoTint, icon: Icons.remove_circle_outline)
            : blocking
                ? AkBadge(label: 'Bloquant', color: t.danger, tint: t.dangerTint, icon: Icons.block)
                : AkBadge(label: 'Alerte', color: t.warning, tint: t.warningTint, icon: Icons.warning_amber);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(c.label, style: AkText.bodyStrong.copyWith(color: t.text)),
      subtitle: Text('${blocking ? 'Bloquant' : 'Alerte'} · ${passed ? 'conforme' : waived ? 'levée' : 'en échec'}${c.details.isEmpty ? '' : ' · ${c.details}'}', style: AkText.caption.copyWith(color: t.textMuted)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        badge,
        if (c.status == 'failed' && c.severity == 'warning' && canWaive) ...[
          const SizedBox(width: AkSpace.s2),
          TextButton(
            onPressed: () async {
              final ctrl = TextEditingController();
              final comment = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text('Lever : ${c.label}'), content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Commentaire (obligatoire)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Lever l\'alerte'))]));
              if (comment == null || comment.trim().isEmpty) return;
              try {
                await ref.read(closingRepositoryProvider).waive(widget.fy.id, c.code, comment.trim());
              } catch (e) {
                if (context.mounted) showErrorSnack(context, frenchRpcError(e));
              }
              setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id));
            },
            child: const Text('Lever'),
          ),
        ],
      ]),
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
    final t = context.ak;
    final adj = _adjustments;
    if (adj == null) return const Center(child: CircularProgressIndicator());
    final addBacks = adj.where((a) => a.kind == 'add_back').fold<int>(0, (s, a) => s + a.amount);
    final deductions = adj.where((a) => a.kind == 'deduction').fold<int>(0, (s, a) => s + a.amount);
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tableau de passage du résultat comptable au résultat fiscal', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            Text('Résultat comptable avant impôt : ${Fmt.fcfa(_accounting, showZero: true)} FCFA', style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text)),
            const SizedBox(height: AkSpace.s2),
            for (final a in adj)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                    width: 130,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: a.kind == 'add_back'
                          ? AkBadge(label: 'Réintégration', color: t.warning, tint: t.warningTint, icon: Icons.add)
                          : AkBadge(label: 'Déduction', color: t.success, tint: t.successTint, icon: Icons.remove),
                    ),
                  ),
                  Expanded(child: Text(a.label, style: AkText.body.copyWith(color: t.text))),
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      initialValue: a.amount == 0 ? '' : '${a.amount}',
                      textAlign: TextAlign.right,
                      style: AkText.amount,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => setState(() => a.amount = Fmt.parseAmount(v) ?? 0),
                    ),
                  ),
                ]),
              ),
            Divider(height: AkSpace.s6, color: t.border),
            Text('Résultat fiscal : ${Fmt.fcfa((_accounting ?? 0) + addBacks - deductions, showZero: true)} FCFA', style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text)),
            const SizedBox(height: AkSpace.s3),
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
                        if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Calculer l\'IS et générer l\'écriture (brouillard)'),
            ),
          ]),
        ),
        if (_result != null) ...[
          const SizedBox(height: AkSpace.s3),
          AkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Impôt sur les sociétés', style: AkText.heading.copyWith(color: t.text)),
              const SizedBox(height: AkSpace.s2),
              Text('IS au taux de ${(_result!.isRate * 100).toStringAsFixed(0)} % : ${Fmt.fcfa(_result!.computedTax, showZero: true)}', style: AkText.body.copyWith(color: t.text)),
              Text('Minimum d\'impôt (sur CA ${Fmt.fcfa(_result!.revenue, showZero: true)}, plancher 250 000) : ${Fmt.fcfa(_result!.minimumTax, showZero: true)}', style: AkText.body.copyWith(color: t.text)),
              Text('IS dû : ${Fmt.fcfa(_result!.taxDue, showZero: true)} · acomptes 4492 : ${Fmt.fcfa(_result!.prepayments, showZero: true)} · solde à payer : ${Fmt.fcfa(_result!.balanceDue, showZero: true)}', style: AkText.bodyStrong.copyWith(color: t.text)),
              if (_result!.entryId != null) TextButton(onPressed: () => context.go('/saisie/${_result!.entryId}'), child: const Text('Ouvrir l\'écriture d\'IS')),
            ]),
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

  Future<void> _export(BuildContext context, String kind, String format) async {
    setState(() => _busy = true);
    try {
      final p = ConsultationParams(entityId: widget.entity.id, from: widget.fy.startDate, to: widget.fy.endDate);
      final (name, bytes) = await ref.read(consultationRepositoryProvider).export(p: p, kind: kind, format: format);
      final uri = await FilePicker.saveFile(dialogTitle: 'Enregistrer', fileName: name, bytes: bytes);
      if (uri != null && uri.scheme == 'file') {
        final f = File(uri.toFilePath());
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, frenchRpcError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final fs = _fs;
    return ListView(
      padding: _bodyPad(context),
      children: [
        Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('États financiers SYSCOHADA (système normal)', style: AkText.heading.copyWith(color: t.text)),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final v = await ref.read(closingRepositoryProvider).generateStatements(widget.entity.id, widget.fy.id);
                      setState(() => _fs = v);
                    } catch (e) {
                      if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Générer les états'),
          ),
        ]),
        const SizedBox(height: AkSpace.s3),
        if (fs == null) AkBanner(kind: AkBannerKind.info, child: const Text('Aucun état généré pour cet exercice.')),
        if (fs != null) ...[
          AkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Généré le ${Fmt.date(fs.generatedAt)}${fs.isFinal ? ' · arrêté' : ''}', style: AkText.bodyStrong.copyWith(color: t.text)),
              const SizedBox(height: AkSpace.s2),
              for (final c in fs.checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon((c['passed'] as bool?) == true ? Icons.check_circle : Icons.cancel, size: 16, color: (c['passed'] as bool?) == true ? t.success : t.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${c['label']}', style: AkText.table.copyWith(color: t.text))),
                  ]),
                ),
              const SizedBox(height: AkSpace.s3),
              Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
                OutlinedButton.icon(onPressed: () => _export(context, 'financial_statements', 'pdf'), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('États financiers PDF')),
                OutlinedButton.icon(onPressed: () => _export(context, 'dgi', 'xlsm'), icon: const Icon(Icons.table_view_outlined, size: 18), label: const Text('Liasse DGI (Excel, macros conservées)')),
              ]),
              const SizedBox(height: AkSpace.s1),
              Text('La liasse DGI reprend fiche R1/R2, bilan et compte de résultat (N et N-1) ; TFT et notes se complètent dans le classeur.', style: AkText.caption.copyWith(color: t.textMuted)),
            ]),
          ),
          const SizedBox(height: AkSpace.s3),
          _PostsTable(title: 'Bilan — Actif', posts: fs.assets, previous: fs.previous?['assets']),
          const SizedBox(height: AkSpace.s3),
          _PostsTable(title: 'Bilan — Passif', posts: fs.liabilities, previous: fs.previous?['liabilities']),
          const SizedBox(height: AkSpace.s3),
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
    final t = context.ak;
    return AkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AkText.heading.copyWith(color: t.text)),
        const SizedBox(height: AkSpace.s2),
        for (final e in byCode.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 44, child: Text(e.key, style: AkText.code.copyWith(color: t.text))),
              Expanded(child: Text(e.value['label'] as String, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
              if (hasGross) ...[
                SizedBox(width: 130, child: AkAmountText(Fmt.fcfa(e.value['gross'] as int))),
                SizedBox(width: 130, child: AkAmountText(Fmt.fcfa(e.value['dep'] as int))),
                SizedBox(width: 130, child: AkAmountText(Fmt.fcfa((e.value['gross'] as int) - (e.value['dep'] as int), showZero: true), bold: true)),
              ] else
                SizedBox(width: 130, child: AkAmountText(Fmt.fcfa(e.value['amount'] as int, showZero: true), bold: true)),
              if (previous != null) SizedBox(width: 130, child: AkAmountText(Fmt.fcfa(prev['${e.key}/${hasGross ? 'gross' : 'amount'}'] ?? 0), color: t.textMuted)),
            ]),
          ),
        Divider(height: AkSpace.s4, color: t.border),
        Row(children: [
          Expanded(child: Text('Total', style: AkText.bodyStrong.copyWith(color: t.text))),
          SizedBox(
            width: 130,
            child: AkAmountText(Fmt.fcfa(hasGross ? byCode.values.fold<int>(0, (s, e) => s + (e['gross'] as int) - (e['dep'] as int)) : byCode.values.fold<int>(0, (s, e) => s + (e['amount'] as int)), showZero: true), bold: true),
          ),
        ]),
      ]),
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
    final t = context.ak;
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Exercice ${fy.label} · ${fy.statusLabel}', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            Text('1. Générer et valider l\'écriture de détermination du résultat (soldes des classes 6, 7, 8 vers 131 / 139).\n2. Clôture provisoire : tous les contrôles bloquants conformes, alertes levées avec commentaire ; les périodes sont verrouillées.\n3. Réouverture possible avec motif tant que l\'arrêté définitif n\'est pas prononcé.', style: AkText.body.copyWith(color: t.textMuted)),
            const SizedBox(height: AkSpace.s3),
            Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, children: [
              OutlinedButton.icon(onPressed: () => runGeneration(context, ref, () => repo.generateResultEntry(entity.id, fy.id), 'Détermination du résultat'), icon: const Icon(Icons.functions, size: 18), label: const Text('Écriture de résultat')),
              FilledButton.icon(
                onPressed: fy.status != 'open'
                    ? null
                    : () async {
                        try {
                          await repo.closeProvisional(entity.id, fy.id);
                          onChanged();
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clôture provisoire prononcée.')));
                        } catch (e) {
                          if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                        }
                      },
                icon: const Icon(Icons.lock_outline, size: 18),
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
                          if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                        }
                      },
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Réouvrir (motif)'),
              ),
            ]),
          ]),
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
    final t = context.ak;
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final can = perms.has('closing.final');
    final expected = 'ARRETER ${widget.fy.label}';
    if (widget.fy.status == 'closed') {
      final when = widget.fy.finalClosedAt;
      return ListView(padding: _bodyPad(context), children: [
        AkBanner(
          kind: AkBannerKind.success,
          icon: Icons.lock,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Exercice ${widget.fy.label} arrêté définitivement', style: AkText.bodyStrong.copyWith(color: t.text)),
            Text('${when == null ? '' : 'Le ${Fmt.date(when)}. '}Aucune réouverture possible ; états financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.'),
          ]),
        ),
      ]);
    }
    final blocked = !can || !_acknowledged || _confirm.text.trim() != expected || widget.fy.status != 'closing';
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkBanner(
          kind: AkBannerKind.danger,
          icon: Icons.warning_amber_outlined,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Action irréversible. ', style: AkText.bodyStrong),
            const TextSpan(text: 'Après l\'arrêté, l\'exercice devient intangible : aucune réouverture, aucune écriture ajoutée ni modifiée.'),
          ])),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Arrêté définitif de l\'exercice ${widget.fy.label}', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            Text('Réservé à l\'associé (TOTP vérifié). L\'exercice devient intangible : aucune réouverture. Les états financiers, le grand livre et la balance sont archivés avec leurs empreintes SHA-256.', style: AkText.body.copyWith(color: t.textMuted)),
            const SizedBox(height: AkSpace.s3),
            CheckboxListTile(value: _acknowledged, onChanged: can ? (v) => setState(() => _acknowledged = v ?? false) : null, controlAffinity: ListTileControlAffinity.leading, title: Text('J\'ai vérifié les états financiers et je comprends que cette action est irréversible.', style: AkText.table.copyWith(color: t.text)), contentPadding: EdgeInsets.zero),
            const SizedBox(height: AkSpace.s2),
            TextField(controller: _confirm, enabled: can && _acknowledged, style: AkText.code, decoration: InputDecoration(labelText: 'Tapez « $expected » pour confirmer'), onChanged: (_) => setState(() {})),
            const SizedBox(height: AkSpace.s3),
            FilledButton.icon(
              style: akDangerFilledStyle(context),
              onPressed: blocked
                  ? null
                  : () async {
                      try {
                        final archive = await ref.read(closingRepositoryProvider).closeFinal(widget.entity.id, widget.fy.id, _confirm.text.trim());
                        widget.onChanged();
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exercice arrêté. Archive $archive.')));
                      } catch (e) {
                        if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                      }
                    },
              icon: const Icon(Icons.lock, size: 18),
              label: const Text('Arrêter définitivement'),
            ),
            if (widget.fy.status != 'closing') Padding(padding: const EdgeInsets.only(top: AkSpace.s2), child: Text('L\'exercice doit être en clôture provisoire.', style: AkText.caption.copyWith(color: t.textMuted))),
            if (!can) Padding(padding: const EdgeInsets.only(top: AkSpace.s2), child: Text('Votre rôle ne permet pas l\'arrêté définitif.', style: AkText.caption.copyWith(color: t.textMuted))),
          ]),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ce que fait l\'arrêté définitif', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            for (final (icon, text) in const [
              (Icons.lock_outline, 'L\'exercice passe en lecture seule, définitivement.'),
              (Icons.fingerprint, 'États financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: t.textMuted), const SizedBox(width: AkSpace.s2), Expanded(child: Text(text, style: AkText.table.copyWith(color: t.text)))]),
              ),
          ]),
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
    final t = context.ak;
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Exercice suivant', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            if (next == null)
              AkBanner(
                kind: AkBannerKind.warning,
                action: TextButton(onPressed: () => context.go('/dossiers/${widget.entity.id}'), child: const Text('Ouvrir le dossier')),
                child: const Text('Créez l\'exercice suivant dans Dossiers → Exercices avant de générer les à-nouveaux.'),
              ),
            if (next != null) ...[
              Text('À-nouveaux de ${next.label} : soldes de bilan à la clôture de ${widget.fy.label}, détaillés par tiers ; résultat repris en 1300. Recalculables tant que ${widget.fy.label} n\'est pas arrêté (brouillard remplacé).', style: AkText.body.copyWith(color: t.textMuted)),
              const SizedBox(height: AkSpace.s2),
              FilledButton.icon(onPressed: () => runGeneration(context, ref, () => repo.generateOpeningBalances(widget.entity.id, widget.fy.id), 'À-nouveaux ${next.label}'), icon: const Icon(Icons.auto_awesome, size: 18), label: Text('Générer les à-nouveaux ${next.label}')),
              Divider(height: AkSpace.s6, color: t.border),
              Text('Affectation du résultat de ${widget.fy.label} (en ${next.label})', style: AkText.bodyStrong.copyWith(color: t.text)),
              const SizedBox(height: AkSpace.s2),
              Wrap(spacing: AkSpace.s2, runSpacing: AkSpace.s2, children: [
                SizedBox(width: 160, child: TextField(controller: _legal, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Réserve légale (111)'))),
                SizedBox(width: 160, child: TextField(controller: _free, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Réserves libres (118)'))),
                SizedBox(width: 160, child: TextField(controller: _div, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Dividendes (465)'))),
                SizedBox(width: 160, child: TextField(controller: _carry, style: AkText.amount, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Report à nouveau (121)'))),
                SizedBox(width: 130, child: TextField(controller: _date, decoration: const InputDecoration(labelText: 'Date'))),
              ]),
              const SizedBox(height: AkSpace.s2),
              OutlinedButton.icon(
                onPressed: () {
                  final d = Fmt.parseDate(_date.text);
                  if (d == null) return;
                  runGeneration(context, ref, () => repo.allocateResult(widget.entity.id, next.id, d, legalReserve: Fmt.parseAmount(_legal.text) ?? 0, freeReserve: Fmt.parseAmount(_free.text) ?? 0, dividends: Fmt.parseAmount(_div.text) ?? 0, carryForward: Fmt.parseAmount(_carry.text) ?? 0), 'Affectation du résultat');
                },
                icon: const Icon(Icons.call_split, size: 18),
                label: const Text('Générer l\'écriture d\'affectation'),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
