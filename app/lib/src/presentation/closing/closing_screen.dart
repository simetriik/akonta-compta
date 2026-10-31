import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../domain/entity_models.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entities_providers.dart';
import 'checks_step.dart';
import 'closing_widgets.dart';
import 'final_step.dart';
import 'next_year_step.dart';
import 'provisional_step.dart';
import 'statements_step.dart';
import 'tax_step.dart';

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
                  if (ref.watch(entityProvider(widget.entity.id)).value?.accountingSystem == 'sycebnl') ...[
                    const AkBanner(
                      key: Key('sycebnl-closing-notice'),
                      kind: AkBannerKind.warning,
                      icon: Icons.info_outline,
                      child: Text(
                        'Dossier SYCEBNL : bilan, compte de résultat, à-nouveaux et affectation du résultat suivent le référentiel des entités à but non lucratif. '
                        'Export Excel : à venir.',
                      ),
                    ),
                    const SizedBox(height: AkSpace.s3),
                  ],
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
          padding: closingBodyPadding(context),
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
        if (ref.watch(entityProvider(widget.entity.id)).value?.accountingSystem == 'sycebnl') {
          return ListView(
            padding: closingBodyPadding(context),
            children: const [
              AkBanner(
                key: Key('sycebnl-tax-notice'),
                kind: AkBannerKind.info,
                icon: Icons.info_outline,
                child: Text('Impôt sur les sociétés : non applicable à une entité à but non lucratif. Passer à l\'étape suivante.'),
              ),
            ],
          );
        }
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? t.accent : (done ? t.successTint : t.surfaceSunken)),
        child: done
            ? Icon(Icons.check, size: 16, color: t.success)
            : Text(
                '${i + 1}',
                style: AkText.label.copyWith(color: active ? t.onAccent : t.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0),
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
                    color: active ? t.textStrong : (done ? t.text : t.textMuted),
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
