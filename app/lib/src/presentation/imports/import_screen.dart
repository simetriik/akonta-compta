import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../data/import_repository.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../inventory/inventory_screen.dart' show showErrorSnack;
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
    return AkPage(
      children: [
        const AkPageHead(title: 'Import Perfecto', subtitle: 'Journal, balance générale ou balance auxiliaire'),
        const SizedBox(height: AkSpace.s4),
        AkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkSectionTitle('Nouvel import'),
              const SizedBox(height: AkSpace.s2),
              Text(
                'Formats : export texte Perfecto (tabulations, Windows-1252) ou CSV. Les numéros de compte sont repris tels quels puis complétés à la longueur du plan ; les comptes de tiers collés (4110CHU) sont scindés en collectif + code tiers.',
                style: AkText.body.copyWith(color: t.textMuted),
              ),
              const SizedBox(height: AkSpace.s3),
              Wrap(
                spacing: AkSpace.s3,
                runSpacing: AkSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 320,
                    child: AkDropdown<String>(
                      label: 'Type d\'import',
                      value: _kind,
                      items: const [
                        AkOption('journal', 'Journal Perfecto'),
                        AkOption('balance', 'Balance générale (soldes d\'ouverture)'),
                        AkOption('aux_balance', 'Balance auxiliaire'),
                      ],
                      onChanged: (v) => setState(() => _kind = v ?? 'journal'),
                    ),
                  ),
                  if (_kind == 'journal')
                    SizedBox(
                      width: 320,
                      child: AkDropdown<String>(
                        label: 'Journal cible',
                        value: _journalId,
                        items: [for (final j in journals) AkOption(j.id, '${j.code} · ${j.label}')],
                        onChanged: (v) => setState(() => _journalId = v),
                      ),
                    ),
                  AkButton.primary(
                    'Choisir le fichier et analyser',
                    key: const Key('import-pick'),
                    icon: Icons.upload_file_outlined,
                    loading: _busy,
                    onPressed: _busy ? null : _pick,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_current != null) ...[
          const SizedBox(height: AkSpace.s4),
          _BatchPanel(
            entity: widget.entity,
            batch: _current!,
            report: _report,
            onChanged: (b, r) => setState(() {
              _current = b;
              _report = r;
            }),
          ),
        ],
        const SizedBox(height: AkSpace.s6),
        const AkSectionTitle('Imports précédents'),
        const SizedBox(height: AkSpace.s2),
        AsyncView(
          value: batches,
          builder: (list) => AkTable<ImportBatch>(
            minWidth: 720,
            rows: list,
            emptyMessage: 'Aucun import.',
            onRowTap: (b) {
              if (b.status == 'applied' || b.status == 'cancelled') return;
              setState(() {
                _current = b;
                _report = b.report;
              });
            },
            columns: [
              AkColumn.text(label: 'Fichier', flex: 3, text: (b) => b.sourceFileName ?? b.kind),
              AkColumn.text(label: 'Statut', flex: 2, text: (b) => b.statusLabel),
              AkColumn.text(label: 'Date', width: 100, text: (b) => Fmt.date(b.createdAt)),
              AkColumn.text(label: 'Lignes', width: 80, numeric: true, text: (b) => '${b.report['lines'] ?? 0}'),
              AkColumn.text(label: 'Écritures', width: 90, numeric: true, text: (b) => '${b.report['entries'] ?? 0}'),
              AkColumn.text(label: 'Erreurs', width: 80, numeric: true, text: (b) => '${b.report['error_count'] ?? 0}'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pick() async {
    if (_kind == 'journal' && _journalId == null) {
      showAkToast(context, 'Choisissez le journal cible.', kind: AkToastKind.warning);
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
      final batch = await repo.createBatch(
        cabinetId: cabinet!.id,
        entityId: widget.entity.id,
        kind: _kind,
        fileName: file.name,
        targetJournalId: _kind == 'journal' ? _journalId : null,
      );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lot ${b.sourceFileName ?? ''} · ${b.statusLabel}', style: AkText.title.copyWith(color: t.text)),
          const SizedBox(height: AkSpace.s1),
          Text(
            [
              if (b.sourceJournal != null) 'journal source ${b.sourceJournal}',
              if (b.periodFrom != null) 'du ${Fmt.date(b.periodFrom)} au ${Fmt.date(b.periodTo)}',
              '${r['lines'] ?? 0} lignes',
              if (r['pieces'] != null) '${r['pieces']} pièces',
              '${r['accounts'] ?? 0} comptes dont ${r['unknown_accounts'] ?? 0} inconnus',
              '${r['new_third_parties'] ?? 0} tiers à créer',
              if (r['subtotal_errors'] != null) '${r['subtotal_errors']} sous-totaux incohérents',
            ].join(' · '),
            style: AkText.table.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: AkSpace.s4),
          const AkSectionTitle('Correspondances (modifiables avant l\'import)'),
          const SizedBox(height: AkSpace.s2),
          AsyncView(
            value: mappings,
            builder: (list) => AkTable<AccountMapping>(
              minWidth: 960,
              rows: list,
              columns: [
                AkColumn(
                  label: 'Compte Perfecto',
                  width: 130,
                  cell: (c, m) => Text(m.rawAccount, style: AkText.code.copyWith(color: c.ak.text)),
                ),
                AkColumn(
                  label: 'Compte Akonta',
                  width: 150,
                  cell: (c, m) => _Editable(
                    value: m.accountCode,
                    hint: 'ex. 4452000',
                    mono: true,
                    onSaved: (v) => _update(m.id, accountCode: v),
                  ),
                ),
                AkColumn(
                  label: 'Code tiers',
                  width: 150,
                  cell: (c, m) => _Editable(
                    value: m.thirdPartyCode,
                    hint: '—',
                    mono: true,
                    onSaved: (v) => _update(m.id, thirdPartyCode: v),
                  ),
                ),
                AkColumn(
                  label: 'Nom du tiers',
                  width: 180,
                  cell: (c, m) => _Editable(
                    value: m.thirdPartyName,
                    hint: '—',
                    onSaved: (v) => _update(m.id, thirdPartyName: v),
                  ),
                ),
                AkColumn(
                  label: 'Créer le tiers',
                  width: 120,
                  cell: (c, m) => AkCheckbox(
                    value: m.createThirdParty,
                    dense: true,
                    onChanged: m.thirdPartyCode == null ? null : (v) => _update(m.id, createThirdParty: v),
                  ),
                ),
                AkColumn(
                  label: 'Remarque',
                  flex: 1,
                  cell: (c, m) => m.note == null || m.note!.isEmpty
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 16, color: c.ak.danger),
                            const SizedBox(width: AkSpace.s1),
                            Flexible(
                              child: Text(m.note!, style: AkText.caption.copyWith(color: c.ak.danger)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: AkSpace.s3),
            AkBanner(
              kind: AkBannerKind.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Erreurs (${errors.length})', style: AkText.bodyStrong.copyWith(color: t.text)),
                  for (final e in errors.take(30))
                    Text(
                      '• ${e is Map ? [if (e['piece'] != null) 'pièce ${e['piece']}', if (e['line'] != null) 'ligne ${e['line']}', e['error']].join(' · ') : e}',
                      style: AkText.caption.copyWith(color: t.text),
                    ),
                  if (errors.length > 30) Text('… et ${errors.length - 30} autres', style: AkText.caption.copyWith(color: t.text)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AkSpace.s3),
          Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AkButton.secondary(
                'Essai (sans écriture)',
                key: const Key('import-dry-run'),
                icon: Icons.science_outlined,
                onPressed: _busy ? null : () => _apply(dryRun: true),
              ),
              AkButton.primary(
                'Importer en brouillard',
                key: const Key('import-apply'),
                icon: Icons.playlist_add_check,
                onPressed: _busy || b.status != 'dry_run' || (r['error_count'] ?? 0) != 0 ? null : () => _apply(dryRun: false),
              ),
              if (b.status == 'dry_run')
                Text(
                  'Essai : ${r['entries']} écriture(s), ${r['third_parties_created']} tiers, ${r['error_count']} erreur(s).',
                  style: AkText.table.copyWith(color: t.text),
                ),
              if (b.status == 'applied')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: t.success),
                    const SizedBox(width: 4),
                    Text('Importé : ${r['entries']} brouillard(s) à valider par le chef de mission.', style: AkText.table.copyWith(color: t.success)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AkSpace.s1),
          Text(
            'L\'import réel n\'est possible qu\'après un essai sans erreur. Les écritures arrivent en brouillard, marquées « générée ».',
            style: AkText.caption.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _update(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty}) async {
    await ref
        .read(importRepositoryProvider)
        .updateMapping(id, accountCode: accountCode, thirdPartyCode: thirdPartyCode, thirdPartyName: thirdPartyName, createThirdParty: createThirdParty);
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

/// Cellule éditable : enregistre à la validation (Entrée) ou à la perte du focus si le texte a changé.
class _Editable extends StatefulWidget {
  const _Editable({required this.value, required this.hint, required this.onSaved, this.mono = false});

  final String? value;
  final String hint;
  final ValueChanged<String> onSaved;
  final bool mono;

  @override
  State<_Editable> createState() => _EditableState();
}

class _EditableState extends State<_Editable> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        if (!focused && _controller.text != (widget.value ?? '')) widget.onSaved(_controller.text);
      },
      child: AkTextField(controller: _controller, dense: true, mono: widget.mono, hint: widget.hint, onSubmitted: widget.onSaved),
    );
  }
}
