import 'dart:math';

import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  for (final (name, t) in [('clair', AkTokens.light), ('sombre', AkTokens.dark)]) {
    test('contraste WCAG AA (4,5:1) des paires texte / fond, thème $name', () {
      final pairs = <String, (Color, Color)>{
        'texte / fond': (t.text, t.bg),
        'texte / surface': (t.text, t.surface),
        'texte / surface creuse': (t.text, t.surfaceSunken),
        'texte atténué / surface': (t.textMuted, t.surface),
        'texte atténué / fond': (t.textMuted, t.bg),
        'texte atténué / surface creuse': (t.textMuted, t.surfaceSunken),
        'texte de marque / surface': (t.brandText, t.surface),
        'texte de marque / teinte': (t.brandText, t.brandTint),
        'sur marque': (t.onBrand, t.brand),
        'sur danger plein': (t.onDanger, t.dangerSolid),
        'succès / teinte': (t.success, t.successTint),
        'alerte / teinte': (t.warning, t.warningTint),
        'erreur / teinte': (t.danger, t.dangerTint),
        'info / teinte': (t.info, t.infoTint),
        'succès / surface': (t.success, t.surface),
        'erreur / surface': (t.danger, t.surface),
        'texte / teinte de marque': (t.text, t.brandTint),
      };
      final failing = [for (final e in pairs.entries) if (contrast(e.value.$1, e.value.$2) < 4.5) '${e.key} : ${contrast(e.value.$1, e.value.$2).toStringAsFixed(2)}'];
      expect(failing, isEmpty);
    });
  }

  test('échelle typographique : 14 px minimum, montants en Plex Mono', () {
    for (final s in [AkText.title, AkText.heading, AkText.body, AkText.bodyStrong, AkText.label, AkText.caption, AkText.table, AkText.amount, AkText.code]) {
      expect(s.fontSize, greaterThanOrEqualTo(14));
    }
    expect(AkText.amount.fontFamily, AkFonts.mono);
    expect(AkText.titleLg.fontFamily, AkFonts.display);
  });

  test('espacements sur une base de 4', () {
    for (final v in [AkSpace.s1, AkSpace.s2, AkSpace.s3, AkSpace.s4, AkSpace.s5, AkSpace.s6, AkSpace.s8, AkSpace.s12, AkSpace.control, AkSpace.controlTouch, AkSpace.controlDense]) {
      expect(v % 4, 0);
    }
  });
}
