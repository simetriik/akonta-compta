import 'package:flutter/material.dart';
import 'package:akonta/design/design.dart';

/// Aide : raccourcis clavier de la grille de saisie (F1).
class EntryShortcutsDialog extends StatelessWidget {
  const EntryShortcutsDialog({super.key});

  static const _rows = [
    ('Tab / Maj+Tab', 'Cellule suivante / précédente'),
    ('Entrée', 'Passe au champ suivant ; dans une liste de comptes, choisit la proposition surlignée'),
    ('Entrée (dernier montant)', 'Nouvelle ligne, avec la contrepartie déjà proposée si l\'écriture est déséquilibrée'),
    ('↑ ↓', 'Parcourir les propositions de compte ou de tiers'),
    ('Ctrl B', 'Contrepartie automatique sur la première ligne vide'),
    ('Ctrl S', 'Enregistrer le brouillard'),
    ('F1', 'Afficher cette aide'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return AkDialog(
      title: 'Raccourcis clavier',
      size: AkDialogSize.m,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, d) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 190,
                    child: Align(alignment: Alignment.centerLeft, child: AkKbd(k)),
                  ),
                  Expanded(
                    child: Text(d, style: AkText.body.copyWith(color: t.text)),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [AkButton.primary('Fermer', onPressed: () => Navigator.pop(context))],
    );
  }
}

/// Rappel des raccourcis clavier sous la grille (ordinateur uniquement).
class EntryShortcutHints extends StatelessWidget {
  const EntryShortcutHints({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s3),
      child: Wrap(
        spacing: AkSpace.s4,
        runSpacing: AkSpace.s1,
        children: [
          for (final (k, d) in const [
            ('Tab', 'cellule suivante'),
            ('Entrée', 'champ suivant ; en fin de ligne : nouvelle ligne'),
            ('Ctrl B', 'contrepartie'),
            ('Ctrl S', 'enregistrer le brouillard'),
            ('F1', 'tous les raccourcis'),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AkKbd(k),
                const SizedBox(width: 6),
                Text(d, style: AkText.caption.copyWith(color: t.textMuted)),
              ],
            ),
        ],
      ),
    );
  }
}
