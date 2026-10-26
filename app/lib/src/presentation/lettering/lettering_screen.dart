import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/lettering_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../inventory/inventory_screen.dart' show akPagePadding, showErrorSnack;
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
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.isLetterable && a.allowPosting && a.isActive).toList();
    final thirdParties = ref.watch(thirdPartiesProvider(widget.entity.id)).value ?? const <ThirdParty>[];
    final perms = ref.watch(permissionsProvider).value ?? PermissionSet.empty;
    final canLetter = perms.has('lettering.manage', entityId: widget.entity.id);
    final diff = _selectedDebit - _selectedCredit;
    final t = context.ak;
    final pad = akPagePadding(context);
    final debits = _lines.where((l) => l.debit > 0).toList();
    final credits = _lines.where((l) => l.debit <= 0).toList();
    final subtitle = _account == null ? null : '${_account!.code} ${_account!.label}${_thirdParty == null ? '' : ' · tiers ${_thirdParty!.code}'}';
    return ListView(
      padding: pad,
      children: [
        AkPageHead(title: 'Lettrage', subtitle: subtitle),
        const SizedBox(height: AkSpace.s4),
        Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              key: const Key('lettering-account'),
              isExpanded: true,
              initialValue: _account?.id,
              decoration: const InputDecoration(labelText: 'Compte lettrable'),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.label}', overflow: TextOverflow.ellipsis))],
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
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _thirdParty?.id,
              decoration: const InputDecoration(labelText: 'Tiers'),
              items: [const DropdownMenuItem(value: null, child: Text('Tous les tiers')), for (final t in thirdParties) DropdownMenuItem(value: t.id, child: Text('${t.code} · ${t.name}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                setState(() => _thirdParty = thirdParties.where((t) => t.id == v).firstOrNull);
                _load();
              },
            ),
          ),
          if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: AkSpace.s4),
        if (_account == null)
          AkBanner(kind: AkBannerKind.info, child: const Text('Choisissez un compte lettrable (clients, fournisseurs, 471…).'))
        else ...[
          if (_proposals.isNotEmpty) ...[
            Text('Propositions (${_proposals.length})', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            for (final p in _proposals)
              Padding(
                padding: const EdgeInsets.only(bottom: AkSpace.s2),
                child: AkBanner(
                  kind: AkBannerKind.info,
                  icon: Icons.auto_awesome,
                  action: Wrap(spacing: AkSpace.s2, children: [
                    TextButton(onPressed: () => setState(() => _selected
                      ..clear()
                      ..addAll(p.allLineIds)), child: const Text('Voir')),
                    if (canLetter) OutlinedButton.icon(onPressed: _busy ? null : () => _letter(p.allLineIds), icon: const Icon(Icons.check, size: 18), label: const Text('Confirmer')),
                  ]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.thirdPartyCode ?? ''} · ${Fmt.fcfa(p.amount, showZero: true)} · ${p.ruleLabel}', style: AkText.bodyStrong.copyWith(color: t.text)),
                    Text('${p.creditLineIds.length + 1} lignes', style: AkText.caption.copyWith(color: t.textMuted)),
                  ]),
                ),
              ),
            const SizedBox(height: AkSpace.s2),
          ],
          Text('Lignes non lettrées (${_lines.length})', style: AkText.heading.copyWith(color: t.text)),
          const SizedBox(height: AkSpace.s2),
          if (_lines.isEmpty)
            AkCard(child: Text('Aucune ligne non lettrée.', style: AkText.body.copyWith(color: t.textMuted)))
          else
            LayoutBuilder(builder: (context, c) {
              final side = _linesCard('Débit', debits, canLetter);
              final other = _linesCard('Crédit', credits, canLetter);
              if (c.maxWidth >= 900) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: side), const SizedBox(width: AkSpace.s4), Expanded(child: other)]);
              }
              return Column(children: [side, const SizedBox(height: AkSpace.s3), other]);
            }),
          if (canLetter) ...[
            const SizedBox(height: AkSpace.s4),
            AkCard(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3),
              child: Wrap(spacing: AkSpace.s4, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text.rich(TextSpan(children: [TextSpan(text: 'Débit sélectionné '), TextSpan(text: Fmt.fcfa(_selectedDebit, showZero: true), style: AkText.amount.copyWith(fontWeight: FontWeight.w600))]), style: AkText.body.copyWith(color: t.text)),
                Text.rich(TextSpan(children: [TextSpan(text: 'Crédit sélectionné '), TextSpan(text: Fmt.fcfa(_selectedCredit, showZero: true), style: AkText.amount.copyWith(fontWeight: FontWeight.w600))]), style: AkText.body.copyWith(color: t.text)),
                if (_selected.isEmpty)
                  AkBadge(key: const Key('lettering-diff'), label: 'Sélectionnez des lignes', color: t.textMuted, tint: t.surfaceSunken, icon: Icons.touch_app_outlined)
                else if (diff == 0)
                  AkBadge(key: const Key('lettering-diff'), label: 'Sélection soldée : ${Fmt.fcfa(_selectedDebit, showZero: true)}', color: t.success, tint: t.successTint, icon: Icons.check_circle_outline)
                else
                  AkBadge(key: const Key('lettering-diff'), label: 'Écart ${Fmt.fcfa(diff, showZero: true)}', color: t.warning, tint: t.warningTint, icon: Icons.link_off),
                FilledButton.icon(key: const Key('letter-selected'), onPressed: _selected.length < 2 || _busy ? null : () => _letter(_selected.toList(), allowPartial: diff != 0), icon: const Icon(Icons.link, size: 18), label: Text(diff == 0 ? 'Lettrer' : 'Lettrer partiellement')),
              ]),
            ),
          ],
          const SizedBox(height: AkSpace.s6),
          Text('Lettrages en cours (${_groups.length})', style: AkText.heading.copyWith(color: t.text)),
          const SizedBox(height: AkSpace.s2),
          AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(children: [
              for (var i = 0; i < _groups.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.border),
                _groupRow(_groups[i], canLetter),
              ],
              if (_groups.isEmpty) Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Text('Aucun lettrage.', style: AkText.body.copyWith(color: t.textMuted))),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _groupRow(LetteringGroup g, bool canLetter) {
    final t = context.ak;
    return ListTile(
      dense: true,
      leading: AkBadge(label: g.code, color: g.isPartial ? t.warning : t.success, tint: g.isPartial ? t.warningTint : t.successTint, icon: g.isPartial ? Icons.link_off : Icons.link),
      title: Text('${g.isPartial ? 'Partiel' : 'Soldé'} · D ${Fmt.fcfa(g.totalDebit, showZero: true)} · C ${Fmt.fcfa(g.totalCredit, showZero: true)}', style: AkText.body.copyWith(color: t.text)),
      subtitle: Text(Fmt.date(g.createdAt), style: AkText.caption.copyWith(color: t.textMuted)),
      trailing: canLetter ? TextButton.icon(onPressed: () => _unletter(g), icon: const Icon(Icons.link_off, size: 18), label: const Text('Délettrer')) : null,
    );
  }

  /// Carte des lignes d'un sens (débit ou crédit) : case, date, n° de pièce, tiers, libellé, montant.
  Widget _linesCard(String title, List<UnletteredLine> lines, bool canLetter) {
    final t = context.ak;
    final showTier = _thirdParty == null;
    final isDebit = title == 'Débit';
    Widget head(String label, {double? width, bool right = false}) {
      final w = Text(label, textAlign: right ? TextAlign.right : TextAlign.left, style: AkText.label.copyWith(color: t.textMuted));
      return width == null ? Expanded(child: w) : SizedBox(width: width, child: w);
    }

    return AkCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s3), child: Text('$title (${lines.length})', style: AkText.heading.copyWith(color: t.text))),
        Divider(height: 1, color: t.border),
        Container(
          color: t.surfaceSunken,
          padding: const EdgeInsets.fromLTRB(AkSpace.s2, 6, AkSpace.s3, 6),
          child: Row(children: [
            const SizedBox(width: 36),
            head('Date', width: 84),
            head('N°', width: 100),
            if (showTier) head('Tiers', width: 70),
            head('Libellé'),
            head('Montant', width: 100, right: true),
          ]),
        ),
        for (final l in lines) ...[
          Divider(height: 1, color: t.border),
          InkWell(
            onTap: !canLetter ? null : () => setState(() => _selected.contains(l.lineId) ? _selected.remove(l.lineId) : _selected.add(l.lineId)),
            child: Container(
              color: _selected.contains(l.lineId) ? t.brandTint : null,
              padding: const EdgeInsets.fromLTRB(AkSpace.s2, 2, AkSpace.s3, 2),
              constraints: const BoxConstraints(minHeight: AkSpace.rowCompact),
              child: Row(children: [
                SizedBox(
                  width: 36,
                  child: Checkbox(value: _selected.contains(l.lineId), onChanged: !canLetter ? null : (v) => setState(() => v == true ? _selected.add(l.lineId) : _selected.remove(l.lineId))),
                ),
                SizedBox(width: 84, child: Text(Fmt.date(l.entryDate), style: AkText.table.copyWith(color: t.text))),
                SizedBox(width: 100, child: Text('${l.journalCode}-${l.number}', style: AkText.code.copyWith(color: t.text))),
                if (showTier) SizedBox(width: 70, child: Text(l.thirdPartyCode ?? '', style: AkText.code.copyWith(color: t.text))),
                Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis, style: AkText.table.copyWith(color: t.text))),
                SizedBox(width: 100, child: AkAmountText(Fmt.fcfa(isDebit ? l.debit : l.credit))),
              ]),
            ),
          ),
        ],
        if (lines.isEmpty) ...[Divider(height: 1, color: t.border), Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Text('Aucune ligne.', style: AkText.body.copyWith(color: t.textMuted)))],
      ]),
    );
  }

  Future<void> _letter(List<String> ids, {bool allowPartial = false}) async {
    if (allowPartial) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lettrage partiel'),
          content: const Text('La sélection n\'est pas soldée. Confirmer un lettrage partiel ? Les lignes resteront rattachées à ce code jusqu\'au solde.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lettrer partiellement'))],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(letteringRepositoryProvider).letter(ids, allowPartial: allowPartial);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lignes lettrées.')));
    } catch (e) {
      if (mounted) showErrorSnack(context, _french(e));
    }
    await _load();
  }

  Future<void> _unletter(LetteringGroup g) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Délettrer ${g.code}'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Délettrer'))],
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
