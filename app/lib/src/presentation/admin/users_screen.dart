import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_repository.dart';
import '../../domain/models.dart';
import '../widgets/async_view.dart';

/// Utilisateurs et sécurité (administrateur technique) : invitation, import CSV eABC, désactivation (§10.1).
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('invite-user'),
        onPressed: () => showDialog(context: context, builder: (_) => const InviteUserDialog()),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Inviter'),
      ),
      body: AsyncView(
        value: profiles,
        onRetry: () => ref.invalidate(profilesProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Collaborateurs', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context, ref),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importer un CSV eABC'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final p in list)
                    ListTile(
                      leading: CircleAvatar(child: Text(p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?')),
                      title: Text(p.fullName.isEmpty ? p.email : p.fullName, style: TextStyle(decoration: p.isActive ? null : TextDecoration.lineThrough)),
                      subtitle: Text([p.email, if (p.jobTitle != null) p.jobTitle!].join(' · ')),
                      trailing: Switch(
                        value: p.isActive,
                        onChanged: (v) async {
                          final ok = v || await _confirm(context, 'Désactiver ${p.fullName.isEmpty ? p.email : p.fullName} ? Le compte est conservé (aucune suppression), la connexion devient impossible.');
                          if (!ok) return;
                          await ref.read(adminRepositoryProvider).setActive(p.id, v);
                          ref.invalidate(profilesProvider);
                        },
                      ),
                    ),
                  if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucun collaborateur.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (picked.isEmpty || !context.mounted) return;
    final bytes = await picked.first.readAsBytes();
    if (!context.mounted) return;
    final csv = utf8.decode(bytes, allowMalformed: true);
    final result = await ref.read(adminRepositoryProvider).invite(csv: csv);
    ref.invalidate(profilesProvider);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Résultat de l\'import'),
        content: SingleChildScrollView(
          child: Text([
            '${result.invited.length} invitation(s) envoyée(s).',
            if (result.failed.isNotEmpty) '\nÉchecs :\n${result.failed.join('\n')}',
            if (result.parseErrors.isNotEmpty) '\nLignes ignorées :\n${result.parseErrors.join('\n')}',
          ].join('\n')),
        ),
      ),
    );
  }
}

/// Invitation d'un collaborateur : e-mail, nom, fonction. Sans mot de passe : l'invité le choisit via le lien reçu.
class InviteUserDialog extends ConsumerStatefulWidget {
  const InviteUserDialog({super.key});

  @override
  ConsumerState<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<InviteUserDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _job = TextEditingController();
  bool _busy = false;
  String? _error;

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Adresse e-mail invalide';
    return null;
  }

  static String? validateName(String? v) => (v ?? '').trim().length < 2 ? 'Nom requis' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(adminRepositoryProvider).invite(email: _email.text.trim(), fullName: _name.text.trim(), jobTitle: _job.text.trim().isEmpty ? null : _job.text.trim());
      ref.invalidate(profilesProvider);
      if (!mounted) return;
      if (r.failed.isNotEmpty) {
        setState(() => _error = r.failed.join('\n'));
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyée à ${_email.text.trim()}')));
    } catch (e) {
      setState(() => _error = 'Invitation impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inviter un collaborateur'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, key: const Key('invite-name'), decoration: const InputDecoration(labelText: 'Nom complet'), validator: validateName, autofocus: true),
              const SizedBox(height: 10),
              TextFormField(controller: _email, key: const Key('invite-email'), decoration: const InputDecoration(labelText: 'Adresse e-mail'), validator: validateEmail, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              TextFormField(controller: _job, decoration: const InputDecoration(labelText: 'Fonction (facultatif)')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(key: const Key('invite-submit'), onPressed: _busy ? null : _submit, child: const Text('Envoyer l\'invitation')),
      ],
    );
  }
}

/// Petit profil éditable par chacun (nom), utilisé plus tard dans un écran « Mon compte ».
class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => ListTile(title: Text(profile.fullName), subtitle: Text(profile.email));
}
