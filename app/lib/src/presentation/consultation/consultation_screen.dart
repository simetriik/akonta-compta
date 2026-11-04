import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../widgets/error_display.dart';
import '../../core/formatting.dart';
import '../../domain/models.dart';
import '../widgets/require_entity.dart';
import '../../application/providers/entities_providers.dart';
import '../../domain/consultation_models.dart';
import '../../application/providers/consultation_providers.dart';
import '../../application/providers/services.dart';
import '../widgets/save_export.dart';
import 'aged_tab.dart';
import 'auxiliary_tab.dart';
import 'balance_tab.dart';
import 'centralization_tab.dart';
import 'ledger_tab.dart';

/// Consultation du dossier courant : grand livre, balances, balance âgée, centralisateur ; période libre, comparaison N-1, exports (§10.6).
class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _ConsultationBody(entity: entity));
}

class _ConsultationBody extends ConsumerStatefulWidget {
  const _ConsultationBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_ConsultationBody> createState() => _ConsultationBodyState();
}

class _ConsultationBodyState extends ConsumerState<_ConsultationBody> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);
  late final _from = TextEditingController(text: '01/01/${DateTime.now().year}');
  late final _to = TextEditingController(text: Fmt.date(DateTime.now()));
  final _accountFrom = TextEditingController();
  final _accountTo = TextEditingController();
  int? _classNo;
  String _side = 'debit';
  bool _compare = false;
  bool _exporting = false;

  /// Relit vraiment les données du serveur (et pas seulement l'écran).
  void _reload() {
    ref.invalidate(generalLedgerProvider);
    ref.invalidate(trialBalanceProvider);
    ref.invalidate(auxiliaryBalanceProvider);
    ref.invalidate(agedBalanceProvider);
    ref.invalidate(centralizationProvider);
    setState(() {});
  }

  ConsultationParams? _params() {
    final from = Fmt.parseDate(_from.text), to = Fmt.parseDate(_to.text);
    if (from == null || to == null || to.isBefore(from)) return null;
    final fys = ref.read(fiscalYearsProvider(widget.entity.id)).value ?? const [];
    final fy = fys.where((f) => !from.isBefore(f.startDate) && !from.isAfter(f.endDate)).firstOrNull;
    return ConsultationParams(
      entityId: widget.entity.id,
      from: from,
      to: to,
      accountFrom: _accountFrom.text.trim().isEmpty ? null : _accountFrom.text.trim(),
      accountTo: _accountTo.text.trim().isEmpty ? null : _accountTo.text.trim(),
      classNo: _classNo,
      side: _side,
      fiscalYearId: fy?.id,
    );
  }

  ConsultationParams? _previousYear(ConsultationParams p) {
    try {
      return ConsultationParams(
        entityId: p.entityId,
        from: DateTime(p.from.year - 1, p.from.month, p.from.day),
        to: DateTime(p.to.year - 1, p.to.month, p.to.day),
        accountFrom: p.accountFrom,
        accountTo: p.accountTo,
        classNo: p.classNo,
        side: p.side,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fiscalYearsProvider(widget.entity.id));
    final p = _params();
    final t = context.ak;
    final margin = akPageMargin(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AkSpace.s4, margin, AkSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AkPageHead(title: 'Consultation', subtitle: widget.entity.dossierLabel, actions: [_exportMenu(context)]),
          const SizedBox(height: AkSpace.s3),
          Expanded(
            child: AkCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
                    tabs: const [
                      Tab(text: 'Grand livre'),
                      Tab(text: 'Balance générale'),
                      Tab(text: 'Balance auxiliaire'),
                      Tab(text: 'Balance âgée'),
                      Tab(text: 'Centralisateur'),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.border)),
                    ),
                    child: _filters(context),
                  ),
                  Expanded(
                    child: p == null
                        ? Padding(
                            padding: const EdgeInsets.all(AkSpace.s4),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: AkBanner(kind: AkBannerKind.warning, child: const Text('Dates invalides (jj/mm/aaaa).')),
                            ),
                          )
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              LedgerTab(params: p),
                              BalanceTab(params: p, previous: _compare ? _previousYear(p) : null),
                              AuxiliaryTab(params: p),
                              AgedTab(params: p, side: _side, onSide: (s) => setState(() => _side = s)),
                              CentralizationTab(params: p),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtres de période, de comptes et de classe ; l'actualisation relit les champs.
  Widget _filters(BuildContext context) {
    Widget sized(double width, Widget child) => SizedBox(width: width, child: child);
    return Wrap(
      spacing: AkSpace.s3,
      runSpacing: AkSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        sized(176, AkDateField(controller: _from, label: 'Du', onSubmitted: (_) => setState(() {}))),
        sized(176, AkDateField(controller: _to, label: 'Au', onSubmitted: (_) => setState(() {}))),
        sized(136, AkTextField(controller: _accountFrom, label: 'Compte de', mono: true, onSubmitted: (_) => setState(() {}))),
        sized(136, AkTextField(controller: _accountTo, label: 'Compte à', mono: true, onSubmitted: (_) => setState(() {}))),
        sized(
          176,
          AkDropdown<int?>(
            label: 'Classe',
            value: _classNo,
            items: [const AkOption<int?>(null, 'Toutes classes'), for (var c = 1; c <= 8; c++) AkOption<int?>(c, 'Classe $c')],
            onChanged: (v) => setState(() => _classNo = v),
          ),
        ),
        SizedBox(
          height: akControlHeight(context),
          child: AkCheckbox(value: _compare, label: 'Comparer N-1', onChanged: (v) => setState(() => _compare = v)),
        ),
        AkButton.secondary('Actualiser', icon: Icons.refresh, onPressed: _reload),
      ],
    );
  }

  /// Menu d'export (PDF ou Excel) placé dans l'en-tête de l'écran.
  Widget _exportMenu(BuildContext context) {
    final t = context.ak;
    final h = akControlHeight(context);
    return PopupMenuButton<String>(
      tooltip: 'Exporter',
      enabled: !_exporting,
      onSelected: _export,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'trial_balance:pdf', child: Text('Balance — PDF')),
        PopupMenuItem(value: 'trial_balance:xlsx', child: Text('Balance — Excel')),
        PopupMenuItem(value: 'general_ledger:pdf', child: Text('Grand livre — PDF')),
        PopupMenuItem(value: 'general_ledger:xlsx', child: Text('Grand livre — Excel')),
        PopupMenuItem(value: 'aged_balance:pdf', child: Text('Balance âgée — PDF')),
      ],
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderControl),
          borderRadius: AkRadius.mdAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_exporting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.download_outlined, size: 18, color: t.text),
            const SizedBox(width: 6),
            Text('Exporter', style: AkText.bodyStrong.copyWith(color: t.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String choice) async {
    final p = _params();
    if (p == null) return;
    final parts = choice.split(':');
    setState(() => _exporting = true);
    try {
      final (name, bytes) = await ref.read(consultationServiceProvider).export(p: p, kind: parts[0], format: parts[1]);
      final uri = await saveExportedFile(dialogTitle: 'Enregistrer l\'export', fileName: name, bytes: bytes);
      if (mounted && uri != null) {
        showAkToast(context, 'Export enregistré : ${uri.scheme == 'file' ? uri.toFilePath() : uri}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
