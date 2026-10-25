import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/references_repository.dart';
import '../../data/supabase_providers.dart';
import '../../domain/models.dart';
import '../../domain/reference_models.dart';
import '../widgets/async_view.dart';
import '../widgets/require_entity.dart';

/// Référentiels du dossier courant : plan de comptes, tiers, journaux, modèles d'écritures, taux (§10.3).
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireEntity(
      builder: (entity) => DefaultTabController(
        length: 5,
        child: Column(children: [
          const Material(color: Colors.white, child: TabBar(isScrollable: true, tabs: [Tab(text: 'Plan de comptes'), Tab(text: 'Tiers'), Tab(text: 'Journaux'), Tab(text: 'Modèles d\'écritures'), Tab(text: 'Taux')])),
          Expanded(child: TabBarView(children: [AccountsTab(entity: entity), ThirdPartiesTab(entity: entity), JournalsTab(entity: entity), TemplatesTab(entity: entity), const TaxRatesTab()])),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan de comptes
// ---------------------------------------------------------------------------
class AccountsTab extends ConsumerStatefulWidget {
  const AccountsTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<AccountsTab> {
  String _search = '';
  int? _classFilter;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entity.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-account'),
        onPressed: () => showDialog(context: context, builder: (_) => AccountDialog(entity: widget.entity)),
        icon: const Icon(Icons.add),
        label: const Text('Subdiviser un compte'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Numéro ou intitulé'), onChanged: (v) => setState(() => _search = v.trim().toLowerCase()))),
            const SizedBox(width: 12),
            DropdownButton<int?>(
              value: _classFilter,
              hint: const Text('Classe'),
              items: [const DropdownMenuItem(value: null, child: Text('Toutes')), for (var c = 1; c <= 8; c++) DropdownMenuItem(value: c, child: Text('Classe $c'))],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
          ]),
        ),
        Expanded(
          child: AsyncView(
            value: accounts,
            onRetry: () => ref.invalidate(accountsProvider(widget.entity.id)),
            builder: (list) {
              final filtered = list.where((a) => (_classFilter == null || a.classNo == _classFilter) && (_search.isEmpty || a.code.startsWith(_search) || a.label.toLowerCase().contains(_search))).toList();
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  final depth = a.significant.length.clamp(1, 7) - 1;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: 8.0 + depth * 14, right: 8),
                    leading: SizedBox(width: 80, child: Text(a.code, style: TextStyle(fontFamily: 'monospace', fontWeight: a.allowPosting ? FontWeight.normal : FontWeight.bold))),
                    title: Text(a.label, style: TextStyle(decoration: a.isActive ? null : TextDecoration.lineThrough, fontWeight: a.allowPosting ? FontWeight.normal : FontWeight.w600)),
                    subtitle: Text([if (a.isCollective) 'collectif', if (a.isLetterable) 'lettrable', a.normalSide == 'debit' ? 'débiteur' : 'créditeur'].join(' · '), style: const TextStyle(fontSize: 11)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _action(v, a),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                        PopupMenuItem(value: 'toggle', child: Text(a.isActive ? 'Désactiver' : 'Réactiver')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer (sans mouvement)')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _action(String action, Account a) async {
    final repo = ref.read(referencesRepositoryProvider);
    try {
      switch (action) {
        case 'rename':
          final label = await _prompt(context, 'Nouvel intitulé', a.label);
          if (label != null && label.trim().isNotEmpty) await repo.renameAccount(a.id, label.trim());
        case 'toggle':
          await repo.setAccountActive(a.id, !a.isActive);
        case 'delete':
          await repo.deleteAccount(a.id);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_frenchError(e))));
    }
    ref.invalidate(accountsProvider(widget.entity.id));
  }
}

String _frenchError(Object e) {
  final m = e.toString();
  if (m.contains('subdivisions')) return 'Ce compte a des subdivisions : désactivez-le plutôt.';
  if (m.contains('mouvements')) return 'Ce compte a des mouvements : désactivez-le plutôt.';
  if (m.contains('duplicate key')) return 'Ce code existe déjà.';
  if (m.contains('42501') || m.contains('row-level security')) return 'Action non autorisée pour votre rôle.';
  return m;
}

Future<String?> _prompt(BuildContext context, String title, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider'))],
    ),
  );
}

/// Subdivision : numéro complété à la longueur de l'entité, parent trouvé par la base, sens hérité.
class AccountDialog extends ConsumerStatefulWidget {
  const AccountDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<AccountDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  bool _collective = false;
  String? _error;
  int _length = 7;

  @override
  void initState() {
    super.initState();
    ref.read(supabaseClientProvider).from('entities').select('account_length').eq('id', widget.entity.id).single().then((r) {
      if (mounted) setState(() => _length = (r['account_length'] as num).toInt());
    });
  }

  @override
  Widget build(BuildContext context) {
    final padded = padAccountCode(_code.text, _length);
    return AlertDialog(
      title: const Text('Nouveau compte (subdivision)'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _code, key: const Key('account-code'), autofocus: true, decoration: InputDecoration(labelText: 'Numéro', helperText: padded == null ? 'Chiffres uniquement, $_length au plus' : 'Sera enregistré : $padded'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          TextField(controller: _label, key: const Key('account-label'), decoration: const InputDecoration(labelText: 'Intitulé')),
          CheckboxListTile(value: _collective, onChanged: (v) => setState(() => _collective = v ?? false), title: const Text('Compte collectif (tiers rattachés)'), contentPadding: EdgeInsets.zero),
          if (_error != null) Text(_error!, key: const Key('account-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('account-submit'),
          onPressed: () async {
            if (padded == null || _label.text.trim().isEmpty) {
              setState(() => _error = 'Numéro et intitulé requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).createAccount(cabinet!.id, widget.entity.id, code: padded, label: _label.text.trim(), isCollective: _collective ? true : null);
              ref.invalidate(accountsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tiers
// ---------------------------------------------------------------------------
class ThirdPartiesTab extends ConsumerStatefulWidget {
  const ThirdPartiesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<ThirdPartiesTab> createState() => _ThirdPartiesTabState();
}

class _ThirdPartiesTabState extends ConsumerState<ThirdPartiesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final tps = ref.watch(thirdPartiesProvider(widget.entity.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => ThirdPartyDialog(entity: widget.entity)),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau tiers'),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Code ou nom'), onChanged: (v) => setState(() => _search = v.trim().toLowerCase()))),
        Expanded(
          child: AsyncView(
            value: tps,
            builder: (list) {
              final filtered = list.where((t) => _search.isEmpty || t.code.toLowerCase().contains(_search) || t.name.toLowerCase().contains(_search)).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final t in filtered)
                    ListTile(
                      dense: true,
                      leading: SizedBox(width: 90, child: Text(t.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                      title: Text(t.name, style: TextStyle(decoration: t.isActive ? null : TextDecoration.lineThrough)),
                      subtitle: Text([ThirdParty.typeLabels[t.type] ?? t.type, if (t.collectiveCodes.isNotEmpty) 'collectifs ${t.collectiveCodes.join(', ')}', if (t.taxId != null) 'IFU ${t.taxId}'].join(' · ')),
                      onTap: () => showDialog(context: context, builder: (_) => ThirdPartyDialog(entity: widget.entity, initial: t)),
                      trailing: Switch(value: t.isActive, onChanged: (v) async {
                        await ref.read(referencesRepositoryProvider).setThirdPartyActive(t.id, v);
                        ref.invalidate(thirdPartiesProvider(widget.entity.id));
                      }),
                    ),
                  if (filtered.isEmpty) const Text('Aucun tiers.'),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class ThirdPartyDialog extends ConsumerStatefulWidget {
  const ThirdPartyDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final ThirdParty? initial;

  @override
  ConsumerState<ThirdPartyDialog> createState() => _ThirdPartyDialogState();
}

class _ThirdPartyDialogState extends ConsumerState<ThirdPartyDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _taxId = TextEditingController(text: widget.initial?.taxId);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _email = TextEditingController(text: widget.initial?.email);
  late String _type = widget.initial?.type ?? 'customer';
  final Set<String> _collectives = {};
  bool _loaded = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[];
    final collectives = accounts.where((a) => a.isCollective && a.allowPosting && a.isActive).toList();
    if (!_loaded && widget.initial != null && accounts.isNotEmpty) {
      _collectives.addAll(collectives.where((a) => widget.initial!.collectiveCodes.contains(a.code)).map((a) => a.id));
      _loaded = true;
    }
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau tiers' : 'Tiers ${widget.initial!.code}'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                SizedBox(width: 140, child: TextFormField(controller: _code, key: const Key('tp-code'), enabled: widget.initial == null, decoration: const InputDecoration(labelText: 'Code'), validator: validateThirdPartyCode, textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _name, key: const Key('tp-name'), decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null)),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [for (final e in ThirdParty.typeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _type = v ?? 'other'),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: _taxId, decoration: const InputDecoration(labelText: 'IFU')),
              const SizedBox(height: 8),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'))),
              ]),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Comptes collectifs de rattachement', style: TextStyle(fontWeight: FontWeight.w600))),
              Wrap(
                spacing: 6,
                children: [
                  for (final a in collectives)
                    FilterChip(label: Text('${a.code} ${a.label}', style: const TextStyle(fontSize: 12)), selected: _collectives.contains(a.id), onSelected: (v) => setState(() => v ? _collectives.add(a.id) : _collectives.remove(a.id))),
                ],
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('tp-submit'),
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).saveThirdParty(cabinet!.id, widget.entity.id,
                  id: widget.initial?.id, code: _code.text, name: _name.text, type: _type, taxId: _taxId.text, address: _address.text, phone: _phone.text, email: _email.text, collectiveAccountIds: _collectives.toList());
              ref.invalidate(thirdPartiesProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Journaux
// ---------------------------------------------------------------------------
class JournalsTab extends ConsumerWidget {
  const JournalsTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalsProvider(entity.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => JournalDialog(entity: entity)),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau journal'),
      ),
      body: AsyncView(
        value: journals,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(children: [
                for (final j in list)
                  ListTile(
                    leading: SizedBox(width: 60, child: Text(j.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                    title: Text(j.label, style: TextStyle(decoration: j.isActive ? null : TextDecoration.lineThrough)),
                    subtitle: Text([Journal.typeLabels[j.type] ?? j.type, if (j.treasuryAccountCode != null) 'compte ${j.treasuryAccountCode}'].join(' · ')),
                    onTap: () => showDialog(context: context, builder: (_) => JournalDialog(entity: entity, initial: j)),
                    trailing: j.type == 'opening'
                        ? const Tooltip(message: 'Journal imposé', child: Icon(Icons.lock_outline))
                        : Switch(value: j.isActive, onChanged: (v) async {
                            await ref.read(referencesRepositoryProvider).setJournalActive(j.id, v);
                            ref.invalidate(journalsProvider(entity.id));
                          }),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class JournalDialog extends ConsumerStatefulWidget {
  const JournalDialog({super.key, required this.entity, this.initial});

  final EntitySummary entity;
  final Journal? initial;

  @override
  ConsumerState<JournalDialog> createState() => _JournalDialogState();
}

class _JournalDialogState extends ConsumerState<JournalDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _label = TextEditingController(text: widget.initial?.label);
  late String _type = widget.initial?.type ?? 'misc';
  late String? _account = widget.initial?.treasuryAccountId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entity.id)).value ?? const <Account>[]).where((a) => a.classNo == 5 && a.allowPosting && a.isActive).toList();
    final treasury = _type == 'bank' || _type == 'cash';
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau journal' : 'Journal ${widget.initial!.code}'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(width: 110, child: TextFormField(controller: _code, enabled: widget.initial == null, decoration: const InputDecoration(labelText: 'Code'), validator: validateJournalCode, textCapitalization: TextCapitalization.characters)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé'), validator: (v) => (v ?? '').trim().isEmpty ? 'Libellé requis' : null)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final e in Journal.typeLabels.entries.where((e) => e.key != 'opening')) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: widget.initial == null ? (v) => setState(() => _type = v ?? 'misc') : null,
            ),
            if (treasury) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _account,
                decoration: const InputDecoration(labelText: 'Compte de trésorerie (classe 5)'),
                items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.label}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _account = v),
                validator: (v) => v == null ? 'Compte requis pour un journal de trésorerie' : null,
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).saveJournal(cabinet!.id, widget.entity.id, id: widget.initial?.id, code: _code.text, label: _label.text, type: _type, treasuryAccountId: treasury ? _account : null);
              ref.invalidate(journalsProvider(widget.entity.id));
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Modèles d'écritures
// ---------------------------------------------------------------------------
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key, required this.entity});

  final EntitySummary entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider(entity.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => TemplateDialog(entity: entity)),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau modèle'),
      ),
      body: AsyncView(
        value: templates,
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text('${t.code} — ${t.label}'),
                  subtitle: Text([t.isCabinetLevel ? 'modèle du cabinet' : 'modèle du dossier', if (t.journalType != null) Journal.typeLabels[t.journalType] ?? t.journalType!, if (t.description != null) t.description!].join(' · ')),
                  children: [
                    for (final l in t.lines)
                      ListTile(
                        dense: true,
                        leading: Text('${l.lineNo}'),
                        title: Text('${l.accountCode}${l.usesThirdParty ? ' + tiers' : ''} · ${l.side == 'debit' ? 'Débit' : 'Crédit'}'),
                        subtitle: Text('${l.label ?? ''} · ${l.formulaLabel}'),
                      ),
                    if (!t.isCabinetLevel)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await ref.read(referencesRepositoryProvider).deactivateTemplate(t.id);
                            ref.invalidate(templatesProvider(entity.id));
                          },
                          child: const Text('Retirer ce modèle'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Création d'un modèle du dossier : lignes avec compte, sens, formule (saisie, % d'une ligne, solde).
class TemplateDialog extends ConsumerStatefulWidget {
  const TemplateDialog({super.key, required this.entity});

  final EntitySummary entity;

  @override
  ConsumerState<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<TemplateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  String? _journalType;
  final List<_LineDraft> _lines = [_LineDraft(), _LineDraft(formula: 'balance', side: 'credit')];
  String? _error;

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(taxRatesProvider).value ?? const <TaxRate>[];
    final rateCodes = rates.map((r) => r.code).toSet().toList()..sort();
    return AlertDialog(
      title: const Text('Nouveau modèle d\'écriture'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(width: 160, child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code'), textCapitalization: TextCapitalization.characters)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé'))),
              const SizedBox(width: 8),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  initialValue: _journalType,
                  decoration: const InputDecoration(labelText: 'Journal'),
                  items: [const DropdownMenuItem(value: null, child: Text('Tous')), for (final e in Journal.typeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _journalType = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            for (var i = 0; i < _lines.length; i++) _lineRow(i, rateCodes),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _lines.add(_LineDraft())), icon: const Icon(Icons.add), label: const Text('Ajouter une ligne'))),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }

  Widget _lineRow(int i, List<String> rateCodes) {
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 24, child: Text('${i + 1}')),
        SizedBox(width: 90, child: TextField(controller: l.account, decoration: const InputDecoration(labelText: 'Compte'))),
        const SizedBox(width: 6),
        Checkbox(value: l.thirdParty, onChanged: (v) => setState(() => l.thirdParty = v ?? false)),
        const Text('tiers', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        DropdownButton<String>(value: l.side, items: const [DropdownMenuItem(value: 'debit', child: Text('Débit')), DropdownMenuItem(value: 'credit', child: Text('Crédit'))], onChanged: (v) => setState(() => l.side = v ?? 'debit')),
        const SizedBox(width: 6),
        DropdownButton<String>(value: l.formula, items: const [DropdownMenuItem(value: 'input', child: Text('Saisie')), DropdownMenuItem(value: 'percent_of', child: Text('% d\'une ligne')), DropdownMenuItem(value: 'balance', child: Text('Solde'))], onChanged: (v) => setState(() => l.formula = v ?? 'input')),
        if (l.formula == 'percent_of') ...[
          const SizedBox(width: 6),
          SizedBox(width: 60, child: TextField(controller: l.refLine, decoration: const InputDecoration(labelText: 'Ligne'))),
          const SizedBox(width: 6),
          DropdownButton<String?>(value: l.rateCode, hint: const Text('Taux'), items: [const DropdownMenuItem(value: null, child: Text('% fixe')), for (final c in rateCodes) DropdownMenuItem(value: c, child: Text(c))], onChanged: (v) => setState(() => l.rateCode = v)),
          if (l.rateCode == null) ...[const SizedBox(width: 6), SizedBox(width: 70, child: TextField(controller: l.percent, decoration: const InputDecoration(labelText: '%')))],
        ],
        const SizedBox(width: 6),
        Expanded(child: TextField(controller: l.label, decoration: const InputDecoration(labelText: 'Libellé'))),
        IconButton(icon: const Icon(Icons.close), onPressed: _lines.length <= 2 ? null : () => setState(() => _lines.removeAt(i))),
      ]),
    );
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _label.text.trim().isEmpty) {
      setState(() => _error = 'Code et libellé requis');
      return;
    }
    final lines = <TemplateLine>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(l.account.text.trim())) {
        setState(() => _error = 'Ligne ${i + 1} : compte numérique requis');
        return;
      }
      final pct = l.percent.text.trim().isEmpty ? null : double.tryParse(l.percent.text.replaceAll(',', '.'));
      lines.add(TemplateLine(
        lineNo: i + 1,
        accountCode: l.account.text.trim(),
        usesThirdParty: l.thirdParty,
        side: l.side,
        formula: l.formula,
        refLineNo: l.formula == 'percent_of' ? int.tryParse(l.refLine.text.trim()) : null,
        percent: l.formula == 'percent_of' && l.rateCode == null && pct != null ? pct / 100 : null,
        taxRateCode: l.formula == 'percent_of' ? l.rateCode : null,
        label: l.label.text.trim().isEmpty ? null : l.label.text.trim(),
      ));
    }
    try {
      final cabinet = await ref.read(currentCabinetProvider.future);
      await ref.read(referencesRepositoryProvider).saveTemplate(cabinet!.id, widget.entity.id, code: _code.text, label: _label.text, journalType: _journalType, lines: lines);
      ref.invalidate(templatesProvider(widget.entity.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _frenchError(e));
    }
  }
}

class _LineDraft {
  _LineDraft({this.formula = 'input', this.side = 'debit'});

  final account = TextEditingController();
  final label = TextEditingController();
  final refLine = TextEditingController(text: '1');
  final percent = TextEditingController();
  bool thirdParty = false;
  String side;
  String formula;
  String? rateCode;
}

// ---------------------------------------------------------------------------
// Taux
// ---------------------------------------------------------------------------
class TaxRatesTab extends ConsumerWidget {
  const TaxRatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(taxRatesProvider);
    final canEdit = ref.watch(permissionsProvider).value?.has('cabinet.settings') ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(onPressed: () => showDialog(context: context, builder: (_) => const TaxRateDialog()), icon: const Icon(Icons.add), label: const Text('Nouveau taux'))
          : null,
      body: AsyncView(
        value: rates,
        builder: (list) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AkColors.sand),
            columns: const [DataColumn(label: Text('Code')), DataColumn(label: Text('Libellé')), DataColumn(label: Text('Taux')), DataColumn(label: Text('Valide du')), DataColumn(label: Text('au'))],
            rows: [
              for (final r in list)
                DataRow(cells: [DataCell(Text(r.code)), DataCell(Text(r.label)), DataCell(Text(r.percentLabel)), DataCell(Text(Fmt.date(r.validFrom))), DataCell(Text(r.validTo == null ? '—' : Fmt.date(r.validTo)))]),
            ],
          ),
        ),
      ),
    );
  }
}

class TaxRateDialog extends ConsumerStatefulWidget {
  const TaxRateDialog({super.key});

  @override
  ConsumerState<TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends ConsumerState<TaxRateDialog> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  final _rate = TextEditingController();
  final _from = TextEditingController(text: Fmt.date(DateTime.now()));
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau taux (ou nouvelle valeur d\'un taux existant)'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code (ex. TVA, AIB1)'), textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 8),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'Libellé')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Taux en % (ex. 18)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'Valide à partir du'))),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
            final from = Fmt.parseDate(_from.text);
            if (!RegExp(r'^[A-Z0-9_]{2,20}$').hasMatch(_code.text.trim().toUpperCase()) || _label.text.trim().isEmpty || rate == null || rate < 0 || rate > 100 || from == null) {
              setState(() => _error = 'Code, libellé, taux (0-100) et date valides requis');
              return;
            }
            try {
              final cabinet = await ref.read(currentCabinetProvider.future);
              await ref.read(referencesRepositoryProvider).addTaxRate(cabinet!.id, code: _code.text, label: _label.text, rate: rate / 100, validFrom: from);
              ref.invalidate(taxRatesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = _frenchError(e));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
