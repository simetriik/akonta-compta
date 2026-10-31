import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/entry_models.dart';
import '../../domain/suggestion_models.dart';
import '../../application/providers/repositories.dart';

/// Suggestions de saisie sans modèle (palier 0) sous le libellé : écritures proches, modèles proches, comptes habituels
/// du libellé et du tiers, alerte de doublon. Rien n'est appliqué sans un geste du collaborateur.
class EntrySuggestionsPanel extends ConsumerStatefulWidget {
  const EntrySuggestionsPanel({
    super.key,
    required this.entityId,
    required this.labelController,
    required this.referenceController,
    required this.currentDraft,
    required this.onUseEntry,
    required this.onUseTemplate,
    required this.onUseAccount,
    this.enabled = true,
    this.debounce = const Duration(milliseconds: 400),
  });

  final String entityId;
  final TextEditingController labelController;
  final TextEditingController referenceController;

  /// Brouillon en cours : fournit le tiers saisi, le total des débits et l'identifiant (exclu des doublons).
  final EntryDraft Function() currentDraft;
  final ValueChanged<EntrySuggestion> onUseEntry;
  final ValueChanged<TemplateSuggestion> onUseTemplate;
  final ValueChanged<AccountSuggestion> onUseAccount;
  final bool enabled;
  final Duration debounce;

  @override
  ConsumerState<EntrySuggestionsPanel> createState() => _EntrySuggestionsPanelState();
}

class _EntrySuggestionsPanelState extends ConsumerState<EntrySuggestionsPanel> {
  Timer? _timer;
  String _lastKey = '';
  List<EntrySuggestion> _entries = const [];
  List<TemplateSuggestion> _templates = const [];
  List<AccountSuggestion> _accounts = const [];
  List<DuplicateEntry> _duplicates = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.labelController.addListener(_schedule);
    widget.referenceController.addListener(_schedule);
  }

  @override
  void didUpdateWidget(EntrySuggestionsPanel old) {
    super.didUpdateWidget(old);
    // Le brouillon change hors des champs texte (tiers, montants) : on réévalue après la reconstruction.
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.labelController.removeListener(_schedule);
    widget.referenceController.removeListener(_schedule);
    super.dispose();
  }

  String? get _thirdPartyId => widget.currentDraft().lines.where((l) => l.thirdPartyId != null).map((l) => l.thirdPartyId).firstOrNull;

  String _key() {
    final d = widget.currentDraft();
    return '${widget.labelController.text.trim()}|${widget.referenceController.text.trim()}|${_thirdPartyId ?? ''}|${d.totalDebit}';
  }

  void _schedule() {
    if (!widget.enabled || !mounted) return;
    final key = _key();
    if (key == _lastKey) return;
    _lastKey = key;
    _timer?.cancel();
    if (!_hasQuestion()) {
      if (_entries.isNotEmpty || _templates.isNotEmpty || _accounts.isNotEmpty || _duplicates.isNotEmpty || _failed) {
        setState(() {
          _entries = const [];
          _templates = const [];
          _accounts = const [];
          _duplicates = const [];
          _failed = false;
        });
      }
      return;
    }
    _timer = Timer(widget.debounce, _load);
  }

  /// Rien à demander tant qu'il n'y a ni libellé de 3 caractères, ni tiers, ni référence avec un montant.
  bool _hasQuestion() {
    final d = widget.currentDraft();
    return widget.labelController.text.trim().length >= 3 || _thirdPartyId != null || (widget.referenceController.text.trim().isNotEmpty && d.totalDebit > 0);
  }

  Future<void> _load() async {
    final label = widget.labelController.text.trim();
    final reference = widget.referenceController.text.trim();
    final draft = widget.currentDraft();
    final thirdPartyId = _thirdPartyId;
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final enough = label.length >= 3;
      final results = await Future.wait<Object>([
        enough ? repo.entries(widget.entityId, label) : Future.value(const <EntrySuggestion>[]),
        enough ? repo.templates(widget.entityId, label) : Future.value(const <TemplateSuggestion>[]),
        enough || thirdPartyId != null ? repo.accounts(widget.entityId, label, thirdPartyId: thirdPartyId) : Future.value(const <AccountSuggestion>[]),
        reference.isNotEmpty && draft.totalDebit > 0
            ? repo.duplicates(widget.entityId, reference: reference, amount: draft.totalDebit, thirdPartyId: thirdPartyId, excludeEntryId: draft.id)
            : Future.value(const <DuplicateEntry>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<EntrySuggestion>;
        _templates = results[1] as List<TemplateSuggestion>;
        _accounts = results[2] as List<AccountSuggestion>;
        _duplicates = results[3] as List<DuplicateEntry>;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final t = context.ak;
    final empty = _entries.isEmpty && _templates.isEmpty && _accounts.isEmpty && _duplicates.isEmpty;
    if (empty && !_failed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_duplicates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s2),
              child: AkBanner(
                key: const Key('duplicate-warning'),
                kind: AkBannerKind.warning,
                icon: Icons.content_copy_outlined,
                child: Text(
                  'Doublon possible : même référence et même montant que '
                  '${_duplicates.map((d) => '${d.numberLabel} du ${Fmt.date(d.entryDate)}').join(', ')}.',
                ),
              ),
            ),
          if (_failed)
            Text(
              'Suggestions indisponibles pour le moment.',
              key: const Key('suggestions-failed'),
              style: AkText.caption.copyWith(color: t.textMuted),
            ),
          if (_entries.isNotEmpty)
            _Group(
              title: 'Écritures proches',
              chips: [
                for (final e in _entries)
                  _Chip(
                    key: Key('suggest-entry-${e.entryId}'),
                    label: '${e.label} · ${Fmt.date(e.entryDate)}',
                    hint: 'Reprendre les comptes et les tiers de cette écriture',
                    onTap: () => widget.onUseEntry(e),
                  ),
              ],
            ),
          if (_templates.isNotEmpty)
            _Group(
              title: 'Modèles proches',
              chips: [
                for (final m in _templates)
                  _Chip(
                    key: Key('suggest-template-${m.code}'),
                    label: '${m.code} — ${m.label}',
                    hint: 'Appliquer ce modèle',
                    onTap: () => widget.onUseTemplate(m),
                  ),
              ],
            ),
          if (_accounts.isNotEmpty)
            _Group(
              title: 'Comptes habituels',
              chips: [
                for (final a in _accounts)
                  _Chip(
                    key: Key('suggest-account-${a.accountCode}'),
                    label: '${a.accountCode} ${a.accountLabel} · ${a.uses} fois${a.fromThirdParty ? ' avec ce tiers' : ''}',
                    hint: 'Placer ce compte sur la première ligne sans compte',
                    onTap: () => widget.onUseAccount(a),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s2),
      child: Wrap(
        spacing: AkSpace.s2,
        runSpacing: AkSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: AkText.label.copyWith(color: t.textMuted)),
          ...chips,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.hint, required this.onTap});

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Tooltip(
      message: hint,
      child: InkWell(
        onTap: onTap,
        borderRadius: AkRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s1 + 2),
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: AkRadius.mdAll,
            border: Border.all(color: t.border),
          ),
          child: Text(label, style: AkText.caption.copyWith(color: t.text)),
        ),
      ),
    );
  }
}
