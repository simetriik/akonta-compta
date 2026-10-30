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
        'texte de marque / surface': (t.textStrong, t.surface),
        'texte de marque / teinte': (t.textStrong, t.rowSelected),
        'sur marque': (t.onAccent, t.accent),
        'sur danger plein': (t.onDanger, t.dangerSolid),
        'succès / teinte': (t.success, t.successTint),
        'alerte / teinte': (t.warning, t.warningTint),
        'erreur / teinte': (t.danger, t.dangerTint),
        'info / teinte': (t.info, t.infoTint),
        'succès / surface': (t.success, t.surface),
        'erreur / surface': (t.danger, t.surface),
        'texte / sélection': (t.text, t.rowSelected),
        'texte / en-tête de tableau': (t.text, t.tableHead),
        'texte atténué / en-tête de tableau': (t.textMuted, t.tableHead),
        'texte / ligne active': (t.text, t.rowActive),
        'titre / surface': (t.textStrong, t.surface),
        'titre / fond': (t.textStrong, t.bg),
        'rail : texte / fond': (t.railText, t.railBg),
        'rail : entrée active': (t.railActiveText, t.railActiveBg),
        'rail : texte / entrée survolée': (t.railText, t.railActiveBg),
        'brouillard': (t.draftFg, t.draftBg),
        'revue': (t.reviewFg, t.reviewBg),
        'validée': (t.success, t.successTint),
        'à corriger': (t.danger, t.dangerTint),
        'toast': (t.toastFg, t.toastBg),
        'accent doux / texte': (t.text, t.accentSoft),
      };
      final failing = [for (final e in pairs.entries) if (contrast(e.value.$1, e.value.$2) < 4.5) '${e.key} : ${contrast(e.value.$1, e.value.$2).toStringAsFixed(2)}'];
      expect(failing, isEmpty);
    });
  }

  for (final (name, t) in [('clair', AkTokens.light), ('sombre', AkTokens.dark)]) {
    test('contrôles, focus et indicateurs à 3:1, thème $name', () {
      final pairs = <String, (Color, Color)>{
        'bordure de contrôle / surface': (t.borderControl, t.surface),
        'anneau de focus / surface': (t.focus, t.surface),
        'anneau de focus / fond': (t.focus, t.bg),
        'indicateur du rail / fond du rail': (t.railIndicator, t.railBg),
      };
      final failing = [for (final e in pairs.entries) if (contrast(e.value.$1, e.value.$2) < 3) '${e.key} : ${contrast(e.value.$1, e.value.$2).toStringAsFixed(2)}'];
      expect(failing, isEmpty);
    });
  }

  test('l\'orange d\'action n\'est jamais un texte sur fond clair (< 4,5:1)', () {
    expect(contrast(AkTokens.light.accent, AkTokens.light.surface), lessThan(4.5));
  });

  test('échelle typographique : 14 px minimum, montants en Plex Mono', () {
    for (final s in [AkText.title, AkText.heading, AkText.tableHead, AkText.amountTotal, AkText.keyFigure, AkText.body, AkText.bodyStrong, AkText.label, AkText.caption, AkText.table, AkText.amount, AkText.code]) {
      expect(s.fontSize, greaterThanOrEqualTo(14));
    }
    expect(AkText.amount.fontFamily, AkFonts.mono);
    expect(AkText.titleLg.fontFamily, AkFonts.display);
  });

  test('espacements sur une base de 4', () {
    for (final v in [AkSpace.s1, AkSpace.s2, AkSpace.s3, AkSpace.s4, AkSpace.s5, AkSpace.s6, AkSpace.s8, AkSpace.s10, AkSpace.s12, AkSpace.s16, AkSpace.control, AkSpace.controlTouch, AkSpace.controlDense, AkSpace.rowComfort, AkSpace.railWidth, AkSpace.railCollapsed, AkSpace.topbarHeight]) {
      expect(v % 4, 0);
    }
  });

  test('points de rupture et largeurs de dialogue', () {
    expect([AkBreakpoint.medium, AkBreakpoint.expanded, AkBreakpoint.wide], [600, 900, 1440]);
    expect([AkDialogSize.s.width, AkDialogSize.m.width, AkDialogSize.l.width], [400, 560, 800]);
  });
}
