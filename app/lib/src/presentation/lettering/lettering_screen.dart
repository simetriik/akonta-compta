import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/lettering_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
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
    return Column(children: [
      Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
            if (_account != null && canLetter) ...[
              Chip(
                key: const Key('lettering-diff'),
                label: Text(_selected.isEmpty ? 'Sélectionnez des lignes' : (diff == 0 ? 'Sélection soldée : ${Fmt.fcfa(_selectedDebit, showZero: true)}' : 'Écart ${Fmt.fcfa(diff, showZero: true)}')),
                backgroundColor: (diff == 0 && _selected.isNotEmpty ? AkColors.validated : AkColors.draft).withValues(alpha: 0.12),
              ),
              FilledButton.icon(key: const Key('letter-selected'), onPressed: _selected.length < 2 || _busy ? null : () => _letter(_selected.toList(), allowPartial: diff != 0), icon: const Icon(Icons.link), label: Text(diff == 0 ? 'Lettrer' : 'Lettrer partiellement')),
            ],
          ]),
        ),
      ),
      Expanded(
        child: _account == null
            ? const Center(child: Text('Choisissez un compte lettrable (clients, fournisseurs, 471…).'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_proposals.isNotEmpty) ...[
                    Text('Propositions (${_proposals.length})', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Card(
                      child: Column(children: [
                        for (final p in _proposals)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.auto_awesome, color: AkColors.terracotta),
                            title: Text('${p.thirdPartyCode ?? ''} · ${Fmt.fcfa(p.amount, showZero: true)} · ${p.ruleLabel}'),
                            subtitle: Text('${p.creditLineIds.length + 1} lignes'),
                            trailing: Wrap(spacing: 8, children: [
                              TextButton(onPressed: () => setState(() => _selected
                                ..clear()
                                ..addAll(p.allLineIds)), child: const Text('Voir')),
                              if (canLetter) FilledButton.tonal(onPressed: _busy ? null : () => _letter(p.allLineIds), child: const Text('Confirmer')),
                            ]),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Lignes non lettrées (${_lines.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Card(
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(children: const [
                          SizedBox(width: 40),
                          SizedBox(width: 90, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 80, child: Text('N°', style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 80, child: Text('Tiers', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(child: Text('Libellé', style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 120, child: Text('Débit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 120, child: Text('Crédit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                      const Divider(height: 1),
                      for (final l in _lines)
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(l.lineId),
                          onChanged: !canLetter ? null : (v) => setState(() => v == true ? _selected.add(l.lineId) : _selected.remove(l.lineId)),
                          title: Row(children: [
                            SizedBox(width: 90, child: Text(Fmt.date(l.entryDate))),
                            SizedBox(width: 80, child: Text('${l.journalCode}-${l.number}', style: const TextStyle(fontFamily: 'monospace'))),
                            SizedBox(width: 80, child: Text(l.thirdPartyCode ?? '')),
                            Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 120, child: Text(Fmt.fcfa(l.debit), textAlign: TextAlign.right)),
                            SizedBox(width: 120, child: Text(Fmt.fcfa(l.credit), textAlign: TextAlign.right)),
                          ]),
                        ),
                      if (_lines.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucune ligne non lettrée.')),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('Lettrages en cours (${_groups.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Card(
                    child: Column(children: [
                      for (final g in _groups)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(radius: 14, backgroundColor: g.isPartial ? AkColors.draft : AkColors.validated, child: Text(g.code, style: const TextStyle(color: Colors.white, fontSize: 11))),
                          title: Text('${g.isPartial ? 'Partiel' : 'Soldé'} · D ${Fmt.fcfa(g.totalDebit, showZero: true)} · C ${Fmt.fcfa(g.totalCredit, showZero: true)}'),
                          subtitle: Text(Fmt.date(g.createdAt)),
                          trailing: canLetter ? TextButton(onPressed: () => _unletter(g), child: const Text('Délettrer')) : null,
                        ),
                      if (_groups.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucun lettrage.')),
                    ]),
                  ),
                ],
              ),
      ),
    ]);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_french(e)), backgroundColor: AkColors.toCorrect));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_french(e)), backgroundColor: AkColors.toCorrect));
    }
    await _load();
  }

  static String _french(Object e) => RegExp(r'message: ([^,}]+)').firstMatch(e.toString())?.group(1) ?? e.toString();
}
