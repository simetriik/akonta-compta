import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/import_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../inventory/inventory_screen.dart' show akPagePadding, showErrorSnack;
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

/// Import Perfecto (§10.10) : fichier texte tabulé (Windows-1252) analysé par la base, correspondances éditables,
/// mode essai sans écriture, application en brouillard, rapport.
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) => RequireEntity(builder: (entity) => _ImportBody(entity: entity));
}

class _ImportBody extends ConsumerStatefulWidget {
  const _ImportBody({required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<_ImportBody> createState() => _ImportBodyState();
}

class _ImportBodyState extends ConsumerState<_ImportBody> {
  ImportBatch? _current;
  Map<String, dynamic>? _report;
  String _kind = 'journal';
  String? _journalId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(importBatchesProvider(widget.entity.id));
    final journals = (ref.watch(journalsProvider(widget.entity.id)).value ?? const []).where((j) => j.isActive).toList();
    final t = context.ak;
    return ListView(
      padding: akPagePadding(context),
      children: [
        const AkPageHead(title: 'Import Perfecto', subtitle: 'Journal, balance générale ou balance auxiliaire'),
        const SizedBox(height: AkSpace.s4),
        AkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nouvel import', style: AkText.heading.copyWith(color: t.text)),
            const SizedBox(height: AkSpace.s2),
            Text('Formats : export texte Perfecto (tabulations, Windows-1252) ou CSV. Les numéros de compte sont repris tels quels puis complétés à la longueur du plan ; les comptes de tiers collés (4110CHU) sont scindés en collectif + code tiers.', style: AkText.body.copyWith(color: t.textMuted)),
            const SizedBox(height: AkSpace.s3),
            Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DropdownButton<String>(
                value: _kind,
                items: const [
                  DropdownMenuItem(value: 'journal', child: Text('Journal Perfecto')),
                  DropdownMenuItem(value: 'balance', child: Text('Balance générale (soldes d\'ouverture)')),
                  DropdownMenuItem(value: 'aux_balance', child: Text('Balance auxiliaire')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'journal'),
              ),
              if (_kind == 'journal')
                DropdownButton<String?>(
                  value: _journalId,
                  hint: const Text('Journal cible'),
                  items: [for (final j in journals) DropdownMenuItem(value: j.id, child: Text('${j.code} · ${j.label}'))],
                  onChanged: (v) => setState(() => _journalId = v),
                ),
              FilledButton.icon(key: const Key('import-pick'), onPressed: _busy ? null : _pick, icon: const Icon(Icons.upload_file_outlined, size: 18), label: const Text('Choisir le fichier et analyser')),
              if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ]),
        ),
        if (_current != null) ...[
          const SizedBox(height: AkSpace.s4),
          _BatchPanel(entity: widget.entity, batch: _current!, report: _report, onChanged: (b, r) => setState(() {
            _current = b;
            _report = r;
          })),
        ],
        const SizedBox(height: AkSpace.s6),
        Text('Imports précédents', style: AkText.heading.copyWith(color: t.text)),
        const SizedBox(height: AkSpace.s2),
        AsyncView(
          value: batches,
          builder: (list) => AkCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.border),
                ListTile(
                  dense: true,
                  title: Text('${list[i].sourceFileName ?? list[i].kind} · ${list[i].statusLabel}', style: AkText.body.copyWith(color: t.text)),
                  subtitle: Text('${Fmt.date(list[i].createdAt)} · ${list[i].report['lines'] ?? 0} lignes · ${list[i].report['entries'] ?? 0} écritures · ${list[i].report['error_count'] ?? 0} erreur(s)', style: AkText.caption.copyWith(color: t.textMuted)),
                  onTap: list[i].status == 'applied' || list[i].status == 'cancelled' ? null : () => setState(() {
                    _current = list[i];
                    _report = list[i].report;
                  }),
                ),
              ],
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(AkSpace.s4), child: Text('Aucun import.', style: AkText.body.copyWith(color: t.textMuted))),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _pick() async {
    if (_kind == 'journal' && _journalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez le journal cible.')));
      return;
    }
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'csv', 'tsv']);
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = picked.first;
      final text = decodePerfectoText(await file.readAsBytes());
      final cabinet = await ref.read(currentCabinetProvider.future);
      final repo = ref.read(importRepositoryProvider);
      final batch = await repo.createBatch(cabinetId: cabinet!.id, entityId: widget.entity.id, kind: _kind, fileName: file.name, targetJournalId: _kind == 'journal' ? _journalId : null);
      Map<String, dynamic> report;
      if (_kind == 'journal') {
        report = await repo.parseJournalText(batch.id, text);
      } else {
        report = {'lines': await repo.loadLines(batch.id, _parseBalance(text))};
      }
      report = await repo.proposeMappings(batch.id);
      ref.invalidate(importBatchesProvider(widget.entity.id));
      final refreshed = (await repo.batches(widget.entity.id)).firstWhere((b) => b.id == batch.id);
      setState(() {
        _current = refreshed;
        _report = report;
      });
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Analyse impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Balance texte / CSV : Compte ; Intitulé ; Débit ; Crédit (ou soldes). Hypothèse Q-001.
  List<Map<String, dynamic>> _parseBalance(String text) {
    final lines = <Map<String, dynamic>>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      if (raw.trim().isEmpty) continue;
      final cols = raw.contains('\t') ? raw.split('\t') : raw.split(';');
      if (cols.length < 3 || !RegExp(r'^[1-9]').hasMatch(cols[0].trim())) continue;
      num parse(String s) => num.tryParse(s.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.')) ?? 0;
      final debit = parse(cols[cols.length >= 4 ? 2 : 2]);
      final credit = cols.length >= 4 ? parse(cols[3]) : 0;
      if (debit == 0 && credit == 0) continue;
      lines.add({'account': cols[0].trim(), 'account_label': cols[1].trim(), 'debit': debit, 'credit': credit, 'label': 'À-nouveaux'});
    }
    return lines;
  }
}

class _BatchPanel extends ConsumerStatefulWidget {
  const _BatchPanel({required this.entity, required this.batch, required this.report, required this.onChanged});

  final EntitySummary entity;
  final ImportBatch batch;
  final Map<String, dynamic>? report;
  final void Function(ImportBatch, Map<String, dynamic>) onChanged;

  @override
  ConsumerState<_BatchPanel> createState() => _BatchPanelState();
}

class _BatchPanelState extends ConsumerState<_BatchPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final r = widget.report ?? b.report;
    final t = context.ak;
    final mappings = ref.watch(importMappingsProvider((widget.entity.id, b.id)));
    final errors = (r['errors'] as List?) ?? (r['parse_errors'] as List?) ?? const [];
    return AkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lot ${b.sourceFileName ?? ''} · ${b.statusLabel}', style: AkText.title.copyWith(color: t.text)),
        const SizedBox(height: AkSpace.s1),
        Text([
          if (b.sourceJournal != null) 'journal source ${b.sourceJournal}',
          if (b.periodFrom != null) 'du ${Fmt.date(b.periodFrom)} au ${Fmt.date(b.periodTo)}',
          '${r['lines'] ?? 0} lignes',
          if (r['pieces'] != null) '${r['pieces']} pièces',
          '${r['accounts'] ?? 0} comptes dont ${r['unknown_accounts'] ?? 0} inconnus',
          '${r['new_third_parties'] ?? 0} tiers à créer',
          if (r['subtotal_errors'] != null) '${r['subtotal_errors']} sous-totaux incohérents',
        ].join(' · '), style: AkText.table.copyWith(color: t.textMuted)),
        const SizedBox(height: AkSpace.s4),
        Text('Correspondances (modifiables avant l\'import)', style: AkText.heading.copyWith(color: t.text)),
        const SizedBox(height: AkSpace.s2),
        AsyncView(
          value: mappings,
          builder: (list) => Container(
            decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: AkRadius.lgAll),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [DataColumn(label: Text('Compte Perfecto')), DataColumn(label: Text('Compte Akonta')), DataColumn(label: Text('Code tiers')), DataColumn(label: Text('Nom du tiers')), DataColumn(label: Text('Créer le tiers')), DataColumn(label: Text('Remarque'))],
                rows: [
                  for (final m in list)
                    DataRow(cells: [
                      DataCell(Text(m.rawAccount, style: AkText.code)),
                      DataCell(_Editable(value: m.accountCode, hint: 'ex. 4452000', mono: true, onSaved: (v) => _update(m.id, accountCode: v))),
                      DataCell(_Editable(value: m.thirdPartyCode, hint: '—', mono: true, onSaved: (v) => _update(m.id, thirdPartyCode: v))),
                      DataCell(_Editable(value: m.thirdPartyName, hint: '—', onSaved: (v) => _update(m.id, thirdPartyName: v))),
                      DataCell(Checkbox(value: m.createThirdParty, onChanged: m.thirdPartyCode == null ? null : (v) => _update(m.id, createThirdParty: v))),
                      DataCell(m.note == null || m.note!.isEmpty
                          ? const SizedBox.shrink()
                          : Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline, size: 16, color: t.danger), const SizedBox(width: 4), Text(m.note!, style: AkText.caption.copyWith(color: t.danger))])),
                    ]),
                ],
              ),
            ),
          ),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s3),
          AkBanner(
            kind: AkBannerKind.danger,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Erreurs (${errors.length})', style: AkText.bodyStrong.copyWith(color: t.text)),
              for (final e in errors.take(30)) Text('• ${e is Map ? [if (e['piece'] != null) 'pièce ${e['piece']}', if (e['line'] != null) 'ligne ${e['line']}', e['error']].join(' · ') : e}', style: AkText.caption.copyWith(color: t.text)),
              if (errors.length > 30) Text('… et ${errors.length - 30} autres', style: AkText.caption.copyWith(color: t.text)),
            ]),
          ),
        ],
        const SizedBox(height: AkSpace.s3),
        Wrap(spacing: AkSpace.s3, runSpacing: AkSpace.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(key: const Key('import-dry-run'), onPressed: _busy ? null : () => _apply(dryRun: true), icon: const Icon(Icons.science_outlined, size: 18), label: const Text('Essai (sans écriture)')),
          FilledButton.icon(
            key: const Key('import-apply'),
            onPressed: _busy || b.status != 'dry_run' || (r['error_count'] ?? 0) != 0 ? null : () => _apply(dryRun: false),
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('Importer en brouillard'),
          ),
          if (b.status == 'dry_run') Text('Essai : ${r['entries']} écriture(s), ${r['third_parties_created']} tiers, ${r['error_count']} erreur(s).', style: AkText.table.copyWith(color: t.text)),
          if (b.status == 'applied') Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_outline, size: 16, color: t.success), const SizedBox(width: 4), Text('Importé : ${r['entries']} brouillard(s) à valider par le chef de mission.', style: AkText.table.copyWith(color: t.success))]),
        ]),
        const SizedBox(height: AkSpace.s1),
        Text('L\'import réel n\'est possible qu\'après un essai sans erreur. Les écritures arrivent en brouillard, marquées « générée ».', style: AkText.caption.copyWith(color: t.textMuted)),
      ]),
    );
  }

  Future<void> _update(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty}) async {
    await ref.read(importRepositoryProvider).updateMapping(id, accountCode: accountCode, thirdPartyCode: thirdPartyCode, thirdPartyName: thirdPartyName, createThirdParty: createThirdParty);
    ref.invalidate(importMappingsProvider((widget.entity.id, widget.batch.id)));
  }

  Future<void> _apply({required bool dryRun}) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(importRepositoryProvider);
      final report = await repo.apply(widget.batch.id, dryRun: dryRun);
      ref.invalidate(importBatchesProvider(widget.entity.id));
      ref.invalidate(entityDashboardProvider);
      final refreshed = (await repo.batches(widget.entity.id)).firstWhere((x) => x.id == widget.batch.id);
      widget.onChanged(refreshed, report);
    } catch (e) {
      if (mounted) showErrorSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Editable extends StatelessWidget {
  const _Editable({required this.value, required this.hint, required this.onSaved, this.mono = false});

  final String? value;
  final String hint;
  final ValueChanged<String> onSaved;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: value ?? '');
    return SizedBox(
      width: 150,
      child: TextField(controller: c, style: mono ? AkText.code : AkText.table, decoration: InputDecoration(isDense: true, hintText: hint, border: InputBorder.none), onSubmitted: onSaved, onTapOutside: (_) => c.text != (value ?? '') ? onSaved(c.text) : null),
    );
  }
}
