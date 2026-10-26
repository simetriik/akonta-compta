import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'layout.dart';

enum AkBannerKind { info, success, warning, danger }

/// Bandeau d'information, de succès, d'alerte ou d'erreur (icône + texte + action facultative).
class AkBanner extends StatelessWidget {
  const AkBanner({super.key, required this.kind, required this.child, this.action, this.icon});

  final AkBannerKind kind;
  final Widget child;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (bg, fg, defaultIcon) = switch (kind) {
      AkBannerKind.info => (t.infoTint, t.info, Icons.info_outline),
      AkBannerKind.success => (t.successTint, t.success, Icons.check_circle_outline),
      AkBannerKind.warning => (t.warningTint, t.warning, Icons.warning_amber_outlined),
      AkBannerKind.danger => (t.dangerTint, t.danger, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AkRadius.lgAll,
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? defaultIcon, size: 20, color: fg),
          ),
          const SizedBox(width: AkSpace.s2),
          Expanded(
            child: DefaultTextStyle.merge(
              style: AkText.table.copyWith(color: t.text),
              child: child,
            ),
          ),
          if (action != null) ...[const SizedBox(width: AkSpace.s2), action!],
        ],
      ),
    );
  }
}

/// Message d'erreur d'un chargement : bandeau rouge avec action « Réessayer ».
class AkErrorMessage extends StatelessWidget {
  const AkErrorMessage(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(akPageMargin(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AkBanner(
            kind: AkBannerKind.danger,
            action: onRetry == null ? null : AkButton.ghost('Réessayer', onPressed: onRetry, dense: true),
            child: Text(message),
          ),
        ),
      ),
    );
  }
}

/// État vide : icône discrète, message et action facultative, centrés.
class AkEmptyState extends StatelessWidget {
  const AkEmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined, this.title, this.action});

  final String message;
  final IconData icon;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AkSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.textMuted),
            const SizedBox(height: AkSpace.s2),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AkText.heading.copyWith(color: t.text),
              ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AkText.body.copyWith(color: t.textMuted),
            ),
            if (action != null) ...[const SizedBox(height: AkSpace.s4), action!],
          ],
        ),
      ),
    );
  }
}

/// Indicateur de chargement centré.
class AkLoading extends StatelessWidget {
  const AkLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)));
}

/// Badge de statut générique (texte + icône, rayon 2) : toujours un mot en plus de la couleur.
class AkBadge extends StatelessWidget {
  const AkBadge({super.key, required this.label, required this.color, required this.tint, this.icon, this.outlined = false});

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: AkRadius.smAll,
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
          Text(label, style: AkText.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Statut coloré d'une écriture : brouillard, validée, revue, à corriger (conception §12.3).
enum AkEntryStatus { draft, validated, reviewed, toCorrect }

class AkStatusBadge extends StatelessWidget {
  const AkStatusBadge(this.status, {super.key});

  final AkEntryStatus status;

  /// Statut d'affichage d'après les colonnes `status` et `review_status` de l'écriture.
  static AkEntryStatus of({required String status, required String reviewStatus}) {
    if (status == 'draft') return AkEntryStatus.draft;
    return switch (reviewStatus) {
      'reviewed' => AkEntryStatus.reviewed,
      'to_correct' => AkEntryStatus.toCorrect,
      _ => AkEntryStatus.validated,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (label, color, tint, icon) = switch (status) {
      AkEntryStatus.draft => ('Brouillard', t.statusDraft, t.statusDraftTint, Icons.edit_outlined),
      AkEntryStatus.validated => ('Validée', t.statusValid, t.statusValidTint, Icons.check_circle_outline),
      AkEntryStatus.reviewed => ('Revue', t.statusReview, t.statusReviewTint, Icons.fact_check_outlined),
      AkEntryStatus.toCorrect => ('À corriger', t.statusFix, t.statusFixTint, Icons.error_outline),
    };
    return AkBadge(label: label, color: color, tint: tint, icon: icon);
  }
}

/// Raccourci clavier (ex. « Ctrl K »).
class AkKbd extends StatelessWidget {
  const AkKbd(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: AkRadius.smAll,
        border: Border(
          top: BorderSide(color: t.border),
          left: BorderSide(color: t.border),
          right: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border, width: 2),
        ),
      ),
      child: Text(text, style: AkText.code.copyWith(color: t.textMuted)),
    );
  }
}

/// Montant : Plex Mono à chiffres tabulaires, aligné à droite.
class AkAmountText extends StatelessWidget {
  const AkAmountText(this.text, {super.key, this.color, this.bold = false});

  final String text;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AkText.amount.copyWith(color: color ?? context.ak.text, fontWeight: bold ? FontWeight.w500 : FontWeight.w400),
    );
  }
}

/// Pastille de compte utilisateur (initiales).
class AkAvatar extends StatelessWidget {
  const AkAvatar(this.name, {super.key, this.size = 32});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.brandTint, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: AkText.label.copyWith(color: t.brandText, fontWeight: FontWeight.w600),
      ),
    );
  }
}
