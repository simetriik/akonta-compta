import 'package:flutter/material.dart';

/// Logo Akonta d'après le kit `outputs/logo-akonta` (PNG transparents embarqués dans `assets/logo/`).
/// Horizontal (symbole + nom) par défaut ; symbole seul avec [symbolOnly] (version petite taille sous 32 px).
class AkLogo extends StatelessWidget {
  const AkLogo({super.key, this.height = 40, this.symbolOnly = false});

  final double height;
  final bool symbolOnly;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final String asset;
    if (symbolOnly) {
      asset = height < 32
          ? 'assets/logo/akonta-symbol-small-${dark ? 'white' : 'black'}-48.png'
          : 'assets/logo/akonta-symbol-${dark ? 'white' : 'black'}-128.png';
    } else {
      asset = 'assets/logo/akonta-lockup-horizontal-${dark ? 'white' : 'black'}-1200.png';
    }
    return Semantics(
      label: 'Akonta',
      image: true,
      child: Image.asset(asset, height: height, fit: BoxFit.contain, filterQuality: FilterQuality.high, excludeFromSemantics: true),
    );
  }
}
