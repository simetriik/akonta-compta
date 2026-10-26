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
        if (fy == null) return const AkEmptyState('Aucun exercice.');
        final margin = akPageMargin(context);
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AkPageHead(
                    title: 'Clôture de l\'exercice',
                    subtitle: widget.entity.name,
                    actions: [
                      SizedBox(
                        width: 280,
                        child: AkDropdown<String>(
                          value: fy.id,
                          items: [for (final f in list) AkOption(f.id, '${f.label} · ${f.statusLabel}')],
                          onChanged: (v) => setState(() => _fy = list.where((f) => f.id == v).firstOrNull),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s4),
                  _Stepper(steps: steps, current: _step, onTap: (i) => setState(() => _step = i)),
                ],
              ),
            ),
            Expanded(child: _stepBody(fy, list)),
          ],
        );
      },
    );
  }

  Widget _stepBody(FiscalYear fy, List<FiscalYear> all) {
    switch (_step) {
      case 0:
        return ChecksStep(entity: widget.entity, fy: fy);
      case 1:
        return ListView(
          padding: _bodyPad(context),
          children: [
            AkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Travaux d\'inventaire', style: AkText.heading.copyWith(color: context.ak.text)),
                  const SizedBox(height: AkSpace.s2),
                  Text(
                    'Les travaux d\'inventaire (amortissements, stocks, provisions, régularisations, écarts de conversion) se préparent dans le module dédié ; leurs brouillards se valident dans Saisie.',
                    style: AkText.body.copyWith(color: context.ak.textMuted),
                  ),
                  const SizedBox(height: AkSpace.s3),
                  AkButton.primary('Ouvrir les travaux d\'inventaire', icon: Icons.inventory_2_outlined, onPressed: () => context.go('/inventaire')),
                ],
              ),
            ),
          ],
        );
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
EdgeInsets _bodyPad(BuildContext context) => EdgeInsets.symmetric(horizontal: akPageMargin(context), vertical: AkSpace.s4);

/// Liste de lignes séparées par des filets, dans une carte sans marge interne.
Widget _rowsCard(BuildContext context, List<Widget> rows) {
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

/// Dialogue à un seul champ texte obligatoire (commentaire de levée d'alerte, motif de réouverture).
/// Renvoie le texte saisi, ou null si l'utilisateur annule.
Future<String?> _askText(BuildContext context, {required String title, required String label, required String confirmLabel}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(title: title, label: label, confirmLabel: confirmLabel),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label, required this.confirmLabel});

  final String title;
  final String label;
  final String confirmLabel;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AkDialog(
      title: widget.title,
      content: AkTextField(controller: _ctrl, autofocus: true, label: widget.label),
      actions: [
        AkButton.secondary('Annuler', onPressed: () => Navigator.pop(context)),
        AkButton.primary(widget.confirmLabel, onPressed: () => Navigator.pop(context, _ctrl.text)),
      ],
    );
  }
}

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
            : Text(
                '${i + 1}',
                style: AkText.label.copyWith(color: active ? t.onBrand : t.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0),
              ),
      );
      return Semantics(
        button: true,
        selected: active,
        child: InkWell(
          borderRadius: AkRadius.mdAll,
          onTap: () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                circle,
                const SizedBox(width: AkSpace.s2),
                Text(
                  '${i + 1}. ${steps[i]}',
                  style: AkText.table.copyWith(
                    color: active ? t.brandText : (done ? t.text : t.textMuted),
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget line(int i, {required bool flex}) {
      final bar = Container(height: 2, width: flex ? null : 20, color: i < current ? t.success : t.border);
      return flex
          ? Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                child: bar,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
              child: bar,
            );
    }

    return AkCard(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1080;
          final row = Row(
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (var i = 0; i < steps.length; i++) ...[item(i), if (i < steps.length - 1) line(i, flex: wide)],
            ],
          );
          return wide ? row : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
        },
      ),
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
        if (snap.hasError) return AkErrorMessage(frenchRpcError(snap.error!));
        if (!snap.hasData) return const AkLoading();
        final checks = snap.data!;
        final blocking = checks.where((c) => c.status == 'failed' && c.severity == 'blocking').length;
        return ListView(
          padding: _bodyPad(context),
          children: [
            AkSectionTitle(
              'Contrôles de clôture',
              trailing: AkButton.secondary(
                'Relancer',
                icon: Icons.refresh,
                onPressed: () => setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id)),
              ),
            ),
            const SizedBox(height: AkSpace.s3),
            if (blocking > 0) ...[
              AkBanner(
                kind: AkBannerKind.danger,
                icon: Icons.block,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$blocking contrôle${blocking > 1 ? 's bloquants empêchent' : ' bloquant empêche'}', style: AkText.bodyStrong),
                      const TextSpan(text: ' de prononcer la clôture. Les alertes peuvent être levées avec un commentaire.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AkSpace.s3),
            ],
            _rowsCard(context, [for (final c in checks) _checkRow(context, c, canWaive)]),
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
    final (icon, color) = passed
        ? (Icons.check_circle, t.success)
        : (waived ? (Icons.remove_circle_outline, t.info) : (blocking ? (Icons.cancel, t.danger) : (Icons.warning_amber, t.warning)));
    final badge = passed
        ? AkBadge(label: 'Conforme', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
        : waived
        ? AkBadge(label: 'Levée', color: t.info, tint: t.infoTint, icon: Icons.remove_circle_outline)
        : blocking
        ? AkBadge(label: 'Bloquant', color: t.danger, tint: t.dangerTint, icon: Icons.block)
        : AkBadge(label: 'Alerte', color: t.warning, tint: t.warningTint, icon: Icons.warning_amber);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AkSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label, style: AkText.bodyStrong.copyWith(color: t.text)),
                Text(
                  '${blocking ? 'Bloquant' : 'Alerte'} · ${passed
                      ? 'conforme'
                      : waived
                      ? 'levée'
                      : 'en échec'}${c.details.isEmpty ? '' : ' · ${c.details.entries.map((e) => '${e.key} : ${e.value}').join(', ')}'}',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          badge,
          if (c.status == 'failed' && c.severity == 'warning' && canWaive) ...[
            const SizedBox(width: AkSpace.s2),
            AkButton.ghost(
              'Lever',
              dense: true,
              onPressed: () async {
                final comment = await _askText(context, title: 'Lever : ${c.label}', label: 'Commentaire (obligatoire)', confirmLabel: 'Lever l\'alerte');
                if (comment == null || comment.trim().isEmpty) return;
                try {
                  await ref.read(closingRepositoryProvider).waive(widget.fy.id, c.code, comment.trim());
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                }
                setState(() => _future = ref.read(closingRepositoryProvider).runChecks(widget.entity.id, widget.fy.id));
              },
            ),
          ],
        ],
      ),
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
  final _amountControllers = <TaxAdjustment, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

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
    if (adj == null) return const AkLoading();
    final addBacks = adj.where((a) => a.kind == 'add_back').fold<int>(0, (s, a) => s + a.amount);
    final deductions = adj.where((a) => a.kind == 'deduction').fold<int>(0, (s, a) => s + a.amount);
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Tableau de passage du résultat comptable au résultat fiscal'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Résultat comptable avant impôt : ${Fmt.fcfa(_accounting, showZero: true)} FCFA',
                style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text),
              ),
              const SizedBox(height: AkSpace.s2),
              for (final a in adj)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: a.kind == 'add_back'
                              ? AkBadge(label: 'Réintégration', color: t.warning, tint: t.warningTint, icon: Icons.add)
                              : AkBadge(label: 'Déduction', color: t.success, tint: t.successTint, icon: Icons.remove),
                        ),
                      ),
                      Expanded(
                        child: Text(a.label, style: AkText.body.copyWith(color: t.text)),
                      ),
                      SizedBox(
                        width: 160,
                        child: AkAmountField(
                          controller: _amountControllers.putIfAbsent(a, () => TextEditingController(text: a.amount == 0 ? '' : Fmt.fcfa(a.amount))),
                          dense: true,
                          showCurrency: false,
                          onChanged: (v) => setState(() => a.amount = v),
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: AkSpace.s6, color: t.border),
              Text(
                'Résultat fiscal : ${Fmt.fcfa((_accounting ?? 0) + addBacks - deductions, showZero: true)} FCFA',
                style: AkText.amount.copyWith(fontWeight: FontWeight.w600, color: t.text),
              ),
              const SizedBox(height: AkSpace.s3),
              AkButton.primary(
                'Calculer l\'IS et générer l\'écriture (brouillard)',
                icon: Icons.calculate_outlined,
                loading: _busy,
                onPressed: () async {
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
              ),
            ],
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: AkSpace.s3),
          AkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AkSectionTitle('Impôt sur les sociétés'),
                const SizedBox(height: AkSpace.s2),
                Text(
                  'IS au taux de ${(_result!.isRate * 100).toStringAsFixed(0)} % : ${Fmt.fcfa(_result!.computedTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'Minimum d\'impôt (sur CA ${Fmt.fcfa(_result!.revenue, showZero: true)}, plancher 250 000) : ${Fmt.fcfa(_result!.minimumTax, showZero: true)}',
                  style: AkText.body.copyWith(color: t.text),
                ),
                Text(
                  'IS dû : ${Fmt.fcfa(_result!.taxDue, showZero: true)} · acomptes 4492 : ${Fmt.fcfa(_result!.prepayments, showZero: true)} · solde à payer : ${Fmt.fcfa(_result!.balanceDue, showZero: true)}',
                  style: AkText.bodyStrong.copyWith(color: t.text),
                ),
                if (_result!.entryId != null) AkButton.ghost('Ouvrir l\'écriture d\'IS', onPressed: () => context.go('/saisie/${_result!.entryId}')),
              ],
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
        Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('États financiers SYSCOHADA (système normal)', style: AkText.heading.copyWith(color: t.text)),
            AkButton.primary(
              'Générer les états',
              icon: Icons.auto_awesome,
              loading: _busy,
              onPressed: () async {
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
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s3),
        if (fs == null) const AkBanner(kind: AkBannerKind.info, child: Text('Aucun état généré pour cet exercice.')),
        if (fs != null) ...[
          AkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Généré le ${Fmt.date(fs.generatedAt)}${fs.isFinal ? ' · arrêté' : ''}', style: AkText.bodyStrong.copyWith(color: t.text)),
                const SizedBox(height: AkSpace.s2),
                for (final c in fs.checks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                    child: Row(
                      children: [
                        Icon(
                          (c['passed'] as bool?) == true ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: (c['passed'] as bool?) == true ? t.success : t.danger,
                        ),
                        const SizedBox(width: AkSpace.s2),
                        Expanded(
                          child: Text('${c['label']}', style: AkText.table.copyWith(color: t.text)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AkSpace.s3),
                Wrap(
                  spacing: AkSpace.s2,
                  runSpacing: AkSpace.s2,
                  children: [
                    AkButton.secondary(
                      'États financiers PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: () => _export(context, 'financial_statements', 'pdf'),
                    ),
                    AkButton.secondary(
                      'Liasse DGI (Excel, macros conservées)',
                      icon: Icons.table_view_outlined,
                      onPressed: () => _export(context, 'dgi', 'xlsm'),
                    ),
                  ],
                ),
                const SizedBox(height: AkSpace.s2),
                Text(
                  'La liasse DGI reprend fiche R1/R2, bilan et compte de résultat (N et N-1) ; TFT et notes se complètent dans le classeur.',
                  style: AkText.caption.copyWith(color: t.textMuted),
                ),
              ],
            ),
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
    final hasPrevious = previous != null;
    final t = context.ak;
    int gross(Map<String, dynamic> e) => e['gross'] as int;
    int dep(Map<String, dynamic> e) => e['dep'] as int;
    int net(Map<String, dynamic> e) => hasGross ? gross(e) - dep(e) : e['amount'] as int;
    final netTotal = Fmt.fcfa(byCode.values.fold<int>(0, (s, e) => s + net(e)), showZero: true);
    AkColumn<MapEntry<String, Map<String, dynamic>>> amountColumn(
      String label,
      int Function(MapEntry<String, Map<String, dynamic>>) value, {
      bool bold = false,
      bool muted = false,
      bool showZero = false,
      String? footer,
    }) => AkColumn(
      label: label,
      width: 130,
      numeric: true,
      footer: footer,
      cell: (_, e) => AkAmountText(
        Fmt.fcfa(value(e), showZero: showZero),
        bold: bold,
        color: muted ? t.textMuted : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkSectionTitle(title),
        const SizedBox(height: AkSpace.s2),
        AkTable<MapEntry<String, Map<String, dynamic>>>(
          minWidth: 560,
          rows: byCode.entries.toList(),
          footerLabel: 'Total',
          columns: [
            AkColumn.text(label: 'Code', width: 56, text: (e) => e.key),
            AkColumn.text(label: 'Libellé', text: (e) => e.value['label'] as String),
            if (hasGross) ...[
              amountColumn('Brut', (e) => gross(e.value)),
              amountColumn('Amortissements', (e) => dep(e.value)),
              amountColumn('Net', (e) => net(e.value), bold: true, showZero: true, footer: netTotal),
            ] else
              amountColumn('Montant', (e) => net(e.value), bold: true, showZero: true, footer: netTotal),
            if (hasPrevious) amountColumn('Exercice précédent', (e) => prev['${e.key}/${hasGross ? 'gross' : 'amount'}'] ?? 0, muted: true),
          ],
        ),
      ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkSectionTitle('Exercice ${fy.label} · ${fy.statusLabel}'),
              const SizedBox(height: AkSpace.s2),
              Text(
                '1. Générer et valider l\'écriture de détermination du résultat (soldes des classes 6, 7, 8 vers 131 / 139).\n2. Clôture provisoire : tous les contrôles bloquants conformes, alertes levées avec commentaire ; les périodes sont verrouillées.\n3. Réouverture possible avec motif tant que l\'arrêté définitif n\'est pas prononcé.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              Wrap(
                spacing: AkSpace.s3,
                runSpacing: AkSpace.s2,
                children: [
                  AkButton.secondary(
                    'Écriture de résultat',
                    icon: Icons.functions,
                    onPressed: () => runGeneration(context, ref, () => repo.generateResultEntry(entity.id, fy.id), 'Détermination du résultat'),
                  ),
                  AkButton.primary(
                    'Clôture provisoire',
                    icon: Icons.lock_outline,
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
                  ),
                  AkButton.secondary(
                    'Réouvrir (motif)',
                    icon: Icons.lock_open,
                    onPressed: fy.status != 'closing'
                        ? null
                        : () async {
                            final reason = await _askText(context, title: 'Réouvrir l\'exercice', label: 'Motif (obligatoire)', confirmLabel: 'Réouvrir');
                            if (reason == null || reason.trim().isEmpty) return;
                            try {
                              await repo.reopen(entity.id, fy.id, reason.trim());
                              onChanged();
                            } catch (e) {
                              if (context.mounted) showErrorSnack(context, frenchRpcError(e));
                            }
                          },
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
      return ListView(
        padding: _bodyPad(context),
        children: [
          AkBanner(
            kind: AkBannerKind.success,
            icon: Icons.lock,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exercice ${widget.fy.label} arrêté définitivement', style: AkText.bodyStrong.copyWith(color: t.text)),
                Text(
                  '${when == null ? '' : 'Le ${Fmt.date(when)}. '}Aucune réouverture possible ; états financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.',
                ),
              ],
            ),
          ),
        ],
      );
    }
    final blocked = !can || !_acknowledged || _confirm.text.trim() != expected || widget.fy.status != 'closing';
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkBanner(
          kind: AkBannerKind.danger,
          icon: Icons.warning_amber_outlined,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Action irréversible. ', style: AkText.bodyStrong),
                const TextSpan(text: 'Après l\'arrêté, l\'exercice devient intangible : aucune réouverture, aucune écriture ajoutée ni modifiée.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkSectionTitle('Arrêté définitif de l\'exercice ${widget.fy.label}'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Réservé à l\'associé (TOTP vérifié). L\'exercice devient intangible : aucune réouverture. Les états financiers, le grand livre et la balance sont archivés avec leurs empreintes SHA-256.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              AkCheckbox(
                value: _acknowledged,
                onChanged: can ? (v) => setState(() => _acknowledged = v) : null,
                label: 'J\'ai vérifié les états financiers et je comprends que cette action est irréversible.',
              ),
              const SizedBox(height: AkSpace.s2),
              AkTextField(
                controller: _confirm,
                enabled: can && _acknowledged,
                mono: true,
                label: 'Tapez « $expected » pour confirmer',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AkSpace.s3),
              AkButton.danger(
                'Arrêter définitivement',
                icon: Icons.lock,
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
              ),
              if (widget.fy.status != 'closing')
                Padding(
                  padding: const EdgeInsets.only(top: AkSpace.s2),
                  child: Text('L\'exercice doit être en clôture provisoire.', style: AkText.caption.copyWith(color: t.textMuted)),
                ),
              if (!can)
                Padding(
                  padding: const EdgeInsets.only(top: AkSpace.s2),
                  child: Text('Votre rôle ne permet pas l\'arrêté définitif.', style: AkText.caption.copyWith(color: t.textMuted)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AkSpace.s3),
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Ce que fait l\'arrêté définitif'),
              const SizedBox(height: AkSpace.s2),
              for (final (icon, text) in const [
                (Icons.lock_outline, 'L\'exercice passe en lecture seule, définitivement.'),
                (Icons.fingerprint, 'États financiers, grand livre et balance sont archivés avec leurs empreintes SHA-256.'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AkSpace.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: t.textMuted),
                      const SizedBox(width: AkSpace.s2),
                      Expanded(
                        child: Text(text, style: AkText.table.copyWith(color: t.text)),
                      ),
                    ],
                  ),
                ),
            ],
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
    final t = context.ak;
    return ListView(
      padding: _bodyPad(context),
      children: [
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Exercice suivant'),
              const SizedBox(height: AkSpace.s2),
              if (next == null)
                AkBanner(
                  kind: AkBannerKind.warning,
                  action: AkButton.ghost('Ouvrir le dossier', dense: true, onPressed: () => context.go('/dossiers/${widget.entity.id}')),
                  child: const Text('Créez l\'exercice suivant dans Dossiers → Exercices avant de générer les à-nouveaux.'),
                ),
              if (next != null) ...[
                Text(
                  'À-nouveaux de ${next.label} : soldes de bilan à la clôture de ${widget.fy.label}, détaillés par tiers ; résultat repris en 1300. Recalculables tant que ${widget.fy.label} n\'est pas arrêté (brouillard remplacé).',
                  style: AkText.body.copyWith(color: t.textMuted),
                ),
                const SizedBox(height: AkSpace.s2),
                AkButton.primary(
                  'Générer les à-nouveaux ${next.label}',
                  icon: Icons.auto_awesome,
                  onPressed: () => runGeneration(context, ref, () => repo.generateOpeningBalances(widget.entity.id, widget.fy.id), 'À-nouveaux ${next.label}'),
                ),
                Divider(height: AkSpace.s6, color: t.border),
                Text('Affectation du résultat de ${widget.fy.label} (en ${next.label})', style: AkText.bodyStrong.copyWith(color: t.text)),
                const SizedBox(height: AkSpace.s2),
                Wrap(
                  spacing: AkSpace.s2,
                  runSpacing: AkSpace.s2,
                  children: [
                    SizedBox(
                      width: 200,
                      child: AkAmountField(controller: _legal, label: 'Réserve légale (111)', showCurrency: false),
                    ),
                    SizedBox(
                      width: 200,
                      child: AkAmountField(controller: _free, label: 'Réserves libres (118)', showCurrency: false),
                    ),
                    SizedBox(
                      width: 200,
                      child: AkAmountField(controller: _div, label: 'Dividendes (465)', showCurrency: false),
                    ),
                    SizedBox(
                      width: 200,
                      child: AkAmountField(controller: _carry, label: 'Report à nouveau (121)', showCurrency: false),
                    ),
                    SizedBox(
                      width: 160,
                      child: AkDateField(controller: _date, label: 'Date'),
                    ),
                  ],
                ),
                const SizedBox(height: AkSpace.s2),
                AkButton.secondary(
                  'Générer l\'écriture d\'affectation',
                  icon: Icons.call_split,
                  onPressed: () {
                    final d = Fmt.parseDate(_date.text);
                    if (d == null) return;
                    runGeneration(
                      context,
                      ref,
                      () => repo.allocateResult(
                        widget.entity.id,
                        next.id,
                        d,
                        legalReserve: Fmt.parseAmount(_legal.text) ?? 0,
                        freeReserve: Fmt.parseAmount(_free.text) ?? 0,
                        dividends: Fmt.parseAmount(_div.text) ?? 0,
                        carryForward: Fmt.parseAmount(_carry.text) ?? 0,
                      ),
                      'Affectation du résultat',
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
