import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/lettering_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../inventory/inventory_screen.dart' show showErrorSnack;
import '../widgets/require_entity.dart';

/// Lettrage par compte de tiers (§10.7) : débits et crédits non lettrés, sélection, écart, propositions, partiel, délettrage.
class LetteringScreen extends StatelessWidget {
  const LetteringScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _LetteringBody(entity: entity));
}

class _LetteringBody extends ConsumerStatefulWidget {
  const _LetteringBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_LetteringBody> createState() => _LetteringBodyState();
}

class _LetteringBodyState extends ConsumerState<_LetteringBody> {
  Account? _account;
  ThirdParty? _thirdParty;
  List<UnletteredLine> _lines = const [];
  List<LetteringProposal> _proposals = const [];
  List<LetteringGroup> _groups = const [];
  final Set<String> _selected = {};
  bool _busy = false;

  Future<void> _load() async {
    final a = _account;
    if (a == null) return;
    setState(() => _busy = true);
    final repo = ref.read(letteringRepositoryProvider);
    final lines = await repo.unlettered(widget.entity.id, a.id, thirdPartyId: _thirdParty?.id);
    final proposals = await repo.proposals(widget.entity.id, a.id, thirdPartyId: _thirdParty?.id);
    final groups = await repo.groups(widget.entity.id, a.id, thirdPartyId: _thirdParty?.id);
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _proposals = proposals;
      _groups = groups;
      _selected.clear();
      _busy = false;
    });
  }

  int get _selectedDebit => _lines.where((l) => _selected.contains(l.lineId)).fold(0, (s, l) => s + l.debit);
  int get _selectedCredit => _lines.where((l) => _selected.contains(l.lineId)).fold(0, (s, l) => s + l.credit);

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[])
        .where((a) => a.isLetterable && a.allowPosting && a.isActive)
        .toList();
    final thirdParties = ref.watch(thirdPartiesProvider(widget.entity.id)).value ?? const <ThirdParty>[];
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canLetter = perms.has('lettering.manage', entityId: widget.entity.id);
    final diff = _selectedDebit - _selectedCredit;
    final t = context.ak;
    final debits = _lines.where((l) => l.debit > 0).toList();
    final credits = _lines.where((l) => l.debit <= 0).toList();
    final subtitle = _account == null ? null : '${_account!.code} ${_account!.label}${_thirdParty == null ? '' : ' · tiers ${_thirdParty!.code}'}';
    return AkPage(
      children: [
        AkPageHead(title: 'Lettrage', subtitle: subtitle),
        const SizedBox(height: AkSpace.s4),
        Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 320,
              child: AkDropdown<String>(
                key: const Key('lettering-account'),
                label: 'Compte lettrable',
                value: _account?.id,
                items: [for (final a in accounts) AkOption(a.id, '${a.code} ${a.label}')],
                onChanged: (v) {
                  setState(() {
                    _account = accounts.where((a) => a.id == v).firstOrNull;
                    _thirdParty = null;
                  });
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 260,
              child: AkDropdown<String?>(
                label: 'Tiers',
                value: _thirdParty?.id,
                items: [const AkOption<String?>(null, 'Tous les tiers'), for (final t in thirdParties) AkOption<String?>(t.id, '${t.code} · ${t.name}')],
                onChanged: (v) {
                  setState(() => _thirdParty = thirdParties.where((t) => t.id == v).firstOrNull);
                  _load();
                },
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: AkSpace.s2),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        const SizedBox(height: AkSpace.s4),
        if (_account == null)
          const AkBanner(kind: AkBannerKind.info, child: Text('Choisissez un compte lettrable (clients, fournisseurs, 471…).'))
        else ...[
          if (_proposals.isNotEmpty) ...[
            AkSectionTitle('Propositions (${_proposals.length})'),
            const SizedBox(height: AkSpace.s2),
            for (final p in _proposals)
              Padding(
                padding: const EdgeInsets.only(bottom: AkSpace.s2),
                child: AkBanner(
                  kind: AkBannerKind.info,
                  icon: Icons.auto_awesome,
                  action: Wrap(
                    spacing: AkSpace.s2,
                    children: [
                      AkButton.ghost(
                        'Voir',
                        dense: true,
                        onPressed: () => setState(
                          () => _selected
                            ..clear()
                            ..addAll(p.allLineIds),
                        ),
                      ),
                      if (canLetter) AkButton.secondary('Confirmer', dense: true, icon: Icons.check, onPressed: _busy ? null : () => _letter(p.allLineIds)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.thirdPartyCode ?? ''} · ${Fmt.fcfa(p.amount, showZero: true)} · ${p.ruleLabel}',
                        style: AkText.bodyStrong.copyWith(color: t.text),
                      ),
                      Text('${p.creditLineIds.length + 1} lignes', style: AkText.caption.copyWith(color: t.textMuted)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AkSpace.s2),
          ],
          AkSectionTitle('Lignes non lettrées (${_lines.length})'),
          const SizedBox(height: AkSpace.s2),
          if (_lines.isEmpty)
            AkCard(child: AkEmptyState('Aucune ligne non lettrée.'))
          else
            LayoutBuilder(
              builder: (context, c) {
                final side = _linesTable('Débit', debits, canLetter);
                final other = _linesTable('Crédit', credits, canLetter);
                if (c.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: side),
                      const SizedBox(width: AkSpace.s4),
                      Expanded(child: other),
                    ],
                  );
                }
                return Column(
                  children: [
                    side,
                    const SizedBox(height: AkSpace.s3),
                    other,
                  ],
                );
              },
            ),
          if (canLetter) ...[
            const SizedBox(height: AkSpace.s4),
            AkCard(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
              child: Wrap(
                spacing: AkSpace.s4,
                runSpacing: AkSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Débit sélectionné '),
                        TextSpan(
                          text: Fmt.fcfa(_selectedDebit, showZero: true),
                          style: AkText.amount.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: AkText.body.copyWith(color: t.text),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Crédit sélectionné '),
                        TextSpan(
                          text: Fmt.fcfa(_selectedCredit, showZero: true),
                          style: AkText.amount.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: AkText.body.copyWith(color: t.text),
                  ),
                  if (_selected.isEmpty)
                    AkBadge(
                      key: const Key('lettering-diff'),
                      label: 'Sélectionnez des lignes',
                      color: t.textMuted,
                      tint: t.surfaceSunken,
                      icon: Icons.touch_app_outlined,
                    )
                  else if (diff == 0)
                    AkBadge(
                      key: const Key('lettering-diff'),
                      label: 'Sélection soldée : ${Fmt.fcfa(_selectedDebit, showZero: true)}',
                      color: t.success,
                      tint: t.successTint,
                      icon: Icons.check_circle_outline,
                    )
                  else
                    AkBadge(
                      key: const Key('lettering-diff'),
                      label: 'Écart ${Fmt.fcfa(diff, showZero: true)}',
                      color: t.warning,
                      tint: t.warningTint,
                      icon: Icons.link_off,
                    ),
                  AkButton.primary(
                    diff == 0 ? 'Lettrer' : 'Lettrer partiellement',
                    key: const Key('letter-selected'),
                    icon: Icons.link,
                    onPressed: _selected.length < 2 || _busy ? null : () => _letter(_selected.toList(), allowPartial: diff != 0),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AkSpace.s6),
          AkSectionTitle('Lettrages en cours (${_groups.length})'),
          const SizedBox(height: AkSpace.s2),
          AkTable<LetteringGroup>(
            rows: _groups,
            minWidth: 560,
            emptyMessage: 'Aucun lettrage.',
            columns: [
              AkColumn<LetteringGroup>(
                label: 'Lettrage',
                width: 120,
                cell: (context, g) => AkBadge(
                  label: g.code,
                  color: g.isPartial ? t.warning : t.success,
                  tint: g.isPartial ? t.warningTint : t.successTint,
                  icon: g.isPartial ? Icons.link_off : Icons.link,
                ),
              ),
              AkColumn<LetteringGroup>.text(
                label: 'Totaux',
                flex: 3,
                text: (g) =>
                    '${g.isPartial ? 'Partiel' : 'Soldé'} · D ${Fmt.fcfa(g.totalDebit, showZero: true)} · C ${Fmt.fcfa(g.totalCredit, showZero: true)}',
              ),
              AkColumn<LetteringGroup>.text(label: 'Date', width: 96, text: (g) => Fmt.date(g.createdAt)),
              if (canLetter)
                AkColumn<LetteringGroup>(
                  label: '',
                  width: 120,
                  cell: (context, g) => AkButton.ghost('Délettrer', dense: true, icon: Icons.link_off, onPressed: () => _unletter(g)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Tableau des lignes d'un sens (débit ou crédit) : case, date, n° de pièce, tiers, libellé, montant.
  Widget _linesTable(String title, List<UnletteredLine> lines, bool canLetter) {
    final showTier = _thirdParty == null;
    final isDebit = title == 'Débit';
    void toggle(UnletteredLine l) => setState(() => _selected.contains(l.lineId) ? _selected.remove(l.lineId) : _selected.add(l.lineId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s2),
          child: AkSectionTitle('$title (${lines.length})'),
        ),
        AkTable<UnletteredLine>(
          rows: lines,
          minWidth: 520,
          emptyMessage: 'Aucune ligne.',
          onRowTap: canLetter ? toggle : null,
          rowColor: (l) => _selected.contains(l.lineId) ? context.ak.rowSelected : null,
          columns: [
            AkColumn<UnletteredLine>(
              label: '',
              width: 40,
              cell: (context, l) => AkCheckbox(dense: true, value: _selected.contains(l.lineId), onChanged: canLetter ? (_) => toggle(l) : null),
            ),
            AkColumn<UnletteredLine>.text(label: 'Date', width: 84, text: (l) => Fmt.date(l.entryDate)),
            AkColumn<UnletteredLine>(
              label: 'N°',
              width: 100,
              cell: (context, l) => Text('${l.journalCode}-${l.number}', style: AkText.code.copyWith(color: context.ak.text)),
            ),
            if (showTier)
              AkColumn<UnletteredLine>(
                label: 'Tiers',
                width: 70,
                cell: (context, l) => Text(l.thirdPartyCode ?? '', style: AkText.code.copyWith(color: context.ak.text)),
              ),
            AkColumn<UnletteredLine>(
              label: 'Libellé',
              cell: (context, l) => Tooltip(
                message: l.label,
                child: Text(
                  l.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AkText.table.copyWith(color: context.ak.text),
                ),
              ),
            ),
            AkColumn<UnletteredLine>(label: 'Montant', width: 100, numeric: true, cell: (context, l) => AkAmountText(Fmt.fcfa(isDebit ? l.debit : l.credit))),
          ],
        ),
      ],
    );
  }

  Future<void> _letter(List<String> ids, {bool allowPartial = false}) async {
    if (allowPartial) {
      final ok = await showAkConfirm(
        context,
        title: 'Lettrage partiel',
        message: 'La sélection n\'est pas soldée. Confirmer un lettrage partiel ? Les lignes resteront rattachées à ce code jusqu\'au solde.',
        confirmLabel: 'Lettrer partiellement',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(letteringRepositoryProvider).letter(ids, allowPartial: allowPartial);
      if (mounted) showAkToast(context, 'Lignes lettrées.');
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _unletter(LetteringGroup g) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AkDialog(
        title: 'Délettrer ${g.code}',
        content: AkTextField(controller: c, autofocus: true, label: 'Motif (obligatoire)'),
        actions: [
          AkButton.secondary('Annuler', onPressed: () => Navigator.pop(ctx)),
          AkButton.primary('Délettrer', onPressed: () => Navigator.pop(ctx, c.text)),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref.read(letteringRepositoryProvider).unletter(g.id, reason.trim());
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  static String _french(Object e) => RegExp(r'message: ([^,}]+)').firstMatch(e.toString())?.group(1) ?? e.toString();
}
