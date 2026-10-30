import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Version du logo : [auto] bicolore (A orange) en thème clair et blanc en thème sombre ;
/// [blue] tout en bleu nuit (petites tailles, documents) ; [onDark] pour un fond sombre fixe (rail).
enum AkLogoTone { auto, blue, onDark }

/// Logo Akonta (SVG vectoriel du système de design). Horizontal par défaut ; symbole seul avec [symbolOnly].
/// Sous 32 px de hauteur, le symbole passe en version bleue (lisibilité).
class AkLogo extends StatelessWidget {
  const AkLogo({super.key, this.height = 40, this.symbolOnly = false, this.tone = AkLogoTone.auto});

  final double height;
  final bool symbolOnly;
  final AkLogoTone tone;

  static const _dir = 'assets/logo';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final variant = switch (tone) {
      AkLogoTone.onDark => 'sombre',
      AkLogoTone.blue => dark ? 'sombre' : 'bleu',
      AkLogoTone.auto => dark ? 'sombre' : (symbolOnly && height < 32 ? 'bleu' : 'bicolore'),
    };
    final asset = symbolOnly
        ? '$_dir/akonta-symbole-${variant == 'sombre' ? 'blanc' : variant}.svg'
        : '$_dir/akonta-logo-horizontal${variant == 'bicolore' ? '' : '-$variant'}.svg';
    return Semantics(
      label: 'Akonta',
      image: true,
      child: ExcludeSemantics(child: SvgPicture.asset(asset, height: height, fit: BoxFit.contain)),
    );
  }
}
