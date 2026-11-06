import 'package:flutter/material.dart';

import '../tokens.dart';
import 'layout.dart';

enum AkButtonVariant { primary, secondary, danger, dangerOutline, ghost }

/// Bouton unique de l'application : primaire (orange d'action), secondaire (contour), danger (cramoisi),
/// danger secondaire (contour cramoisi) et discret (texte). Même hauteur que les champs (40 px, 48 px sur mobile).
class AkButton extends StatefulWidget {
  const AkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AkButtonVariant.primary,
    this.icon,
    this.loading = false, this.loadingLabel,
    this.dense = false,
    this.expand = false,
  });

  const AkButton.primary(this.label, {super.key, required this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.dense = false, this.expand = false})
    : variant = AkButtonVariant.primary;
  const AkButton.secondary(this.label, {super.key, required this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.dense = false, this.expand = false})
    : variant = AkButtonVariant.secondary;
  const AkButton.danger(this.label, {super.key, required this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.dense = false, this.expand = false})
    : variant = AkButtonVariant.danger;
  const AkButton.dangerOutline(this.label, {super.key, required this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.dense = false, this.expand = false})
    : variant = AkButtonVariant.dangerOutline;
  const AkButton.ghost(this.label, {super.key, required this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.dense = false, this.expand = false})
    : variant = AkButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AkButtonVariant variant;
  final IconData? icon;

  /// Affiche un indicateur et désactive le bouton.
  final bool loading;

  /// Texte affiché à côté de l'indicateur pendant l'action (ex. « Création en cours… »).
  final String? loadingLabel;

  /// Hauteur de 32 px pour les barres d'outils et les lignes de tableau.
  final bool dense;

  /// Occupe toute la largeur disponible.
  final bool expand;

  @override
  State<AkButton> createState() => _AkButtonState();
}

/// Un bouton dont l'action est asynchrone se désactive seul jusqu'à sa fin (indicateur affiché) : un second clic
/// ne relance jamais l'action. Il redevient actif même si l'action échoue.
class _AkButtonState extends State<AkButton> {
  bool _pending = false;

  Future<void> _run() async {
    if (_pending) return; // deuxième clic avant que l'écran ait été redessiné
    // Une action `async` renvoie un Future même si le type déclaré est VoidCallback.
    final Object? result = (widget.onPressed as dynamic)();
    if (result is! Future) return;
    setState(() => _pending = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final (dense, expand, variant, label, icon, loadingLabel) = (widget.dense, widget.expand, widget.variant, widget.label, widget.icon, widget.loadingLabel);
    final loading = widget.loading;
    // Action asynchrone en cours sans `loading` explicite : bouton désactivé, sablier fixe (pas d'animation, car l'action
    // peut attendre une réponse de l'utilisateur, par ex. une confirmation).
    final waiting = _pending && !loading;
    final height = dense && !akIsTouch(context) ? AkSpace.controlDense : akControlHeight(context);
    final enabled = widget.onPressed != null && !loading && !waiting;
    final base = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : 0, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AkSpace.s4)),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AkRadius.mdAll)),
      textStyle: const WidgetStatePropertyAll(AkText.bodyStrong),
      elevation: const WidgetStatePropertyAll(0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
    final (Color fg, Color? bg, Color? border) = switch (variant) {
      AkButtonVariant.primary => (t.onAccent, t.accent, null),
      AkButtonVariant.secondary => (t.text, t.surface, t.borderControl),
      AkButtonVariant.danger => (t.onDanger, t.dangerSolid, null),
      AkButtonVariant.dangerOutline => (t.danger, t.surface, t.danger),
      AkButtonVariant.ghost => (t.textStrong, null, null),
    };
    final style = base.copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.textDisabled : fg),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return variant == AkButtonVariant.ghost || border != null ? null : t.disabledFill;
        final hover = s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed);
        if (variant == AkButtonVariant.primary) return hover ? t.accentHover : t.accent;
        if (variant == AkButtonVariant.danger) return hover ? t.dangerSolidHover : t.dangerSolid;
        return hover ? t.surfaceHover : bg;
      }),
      side: border == null ? null : WidgetStateProperty.resolveWith((s) => BorderSide(color: s.contains(WidgetState.disabled) ? t.border : border)),
    );
    final spinner = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg));
    final child = waiting
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 18),
              const SizedBox(width: AkSpace.s2),
              Flexible(child: Text(loadingLabel ?? label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          )
        : !loading
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : loadingLabel == null
        ? spinner
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinner,
              const SizedBox(width: AkSpace.s2),
              Flexible(child: Text(loadingLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    final leading = icon == null || loading || waiting ? null : Icon(icon, size: 18);
    final onTap = enabled ? _run : null;
    return switch (variant) {
      AkButtonVariant.primary || AkButtonVariant.danger =>
        leading == null
            ? FilledButton(style: style, onPressed: onTap, child: child)
            : FilledButton.icon(style: style, onPressed: onTap, icon: leading, label: child),
      AkButtonVariant.secondary || AkButtonVariant.dangerOutline =>
        leading == null
            ? OutlinedButton(style: style, onPressed: onTap, child: child)
            : OutlinedButton.icon(style: style, onPressed: onTap, icon: leading, label: child),
      AkButtonVariant.ghost =>
        leading == null
            ? TextButton(style: style, onPressed: onTap, child: child)
            : TextButton.icon(style: style, onPressed: onTap, icon: leading, label: child),
    };
  }
}

/// Bouton-icône avec infobulle obligatoire (accessibilité) ; zone de 40 px (48 px sur mobile).
class AkIconButton extends StatelessWidget {
  const AkIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.color, this.size = 20, this.dense = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final h = dense ? AkSpace.controlDense : akControlHeight(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size),
      color: color,
      style: IconButton.styleFrom(minimumSize: Size(h, h), maximumSize: Size(h, h), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.standard),
    );
  }
}
