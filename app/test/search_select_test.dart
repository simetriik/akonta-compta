import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final many = [
    for (var i = 1; i <= 30; i++) AkOption<String>('id$i', '41100${i.toString().padLeft(2, '0')} Client numéro $i'),
    const AkOption<String>('chu', '4110CHU Centre hospitalier Étoile'),
  ];

  group('akFilterOptions', () {
    test('ignore la casse et les accents', () {
      final r = akFilterOptions(many, 'ETOILE');
      expect(r.map((o) => o.value), ['chu']);
    });

    test('tous les mots saisis doivent figurer, dans n\'importe quel ordre', () {
      expect(akFilterOptions(many, 'hospitalier centre').map((o) => o.value), ['chu']);
      expect(akFilterOptions(many, 'client zzz'), isEmpty);
    });

    test('un libellé qui commence par la saisie passe avant celui qui la contient', () {
      const items = [AkOption<int>(1, 'Banque locale'), AkOption<int>(2, 'Locations'), AkOption<int>(3, 'Autres locaux')];
      expect(akFilterOptions(items, 'loc').map((o) => o.value), [2, 1, 3]);
    });

    test('saisie vide : toutes les options, ordre d\'origine', () {
      expect(akFilterOptions(many, '  '), many);
    });
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

  testWidgets('jusqu\'à 12 options : liste déroulante classique', (tester) async {
    await tester.pumpWidget(host(AkDropdown<String>(items: many.take(12).toList(), value: 'id1', label: 'Tiers', onChanged: (_) {})));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(AkSearchSelect<String>), findsNothing);
  });

  testWidgets('au-delà de 12 options : champ à recherche affichant l\'option retenue', (tester) async {
    await tester.pumpWidget(host(AkDropdown<String>(items: many, value: 'chu', label: 'Tiers', onChanged: (_) {})));
    expect(find.byType(AkSearchSelect<String>), findsOneWidget);
    expect(find.text('4110CHU Centre hospitalier Étoile'), findsOneWidget);
  });

  testWidgets('taper filtre la liste, choisir une option appelle onChanged', (tester) async {
    String? picked;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => AkDropdown<String>(items: many, value: picked, label: 'Tiers', onChanged: (v) => setState(() => picked = v)),
    )));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.textContaining('Client numéro 3'), findsWidgets); // liste ouverte dès l'entrée dans le champ

    await tester.enterText(find.byType(TextFormField), 'hospital');
    await tester.pumpAndSettle();
    expect(find.textContaining('Client numéro'), findsNothing);
    await tester.tap(find.text('4110CHU Centre hospitalier Étoile').last);
    await tester.pumpAndSettle();
    expect(picked, 'chu');
  });

  testWidgets('quitter le champ : une seule correspondance est retenue, sinon l\'option précédente revient', (tester) async {
    String? picked = 'id1';
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          AkDropdown<String>(items: many, value: picked, label: 'Tiers', onChanged: (v) => setState(() => picked = v)),
          const TextField(key: Key('autre')),
        ],
      ),
    )));
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'etoile');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(picked, 'chu');

    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'zzzz');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(picked, 'chu'); // inchangé
    expect(find.text('4110CHU Centre hospitalier Étoile'), findsOneWidget); // texte rétabli
  });

  testWidgets('une option de valeur nulle (« Tous les tiers ») reste sélectionnable', (tester) async {
    String? picked = 'id1';
    final items = <AkOption<String?>>[const AkOption<String?>(null, 'Tous les tiers'), for (final o in many) AkOption<String?>(o.value, o.label)];
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => AkDropdown<String?>(items: items, value: picked, label: 'Tiers', onChanged: (v) => setState(() => picked = v)),
    )));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'tous');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous les tiers').last);
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('searchable: false conserve la liste déroulante même très longue', (tester) async {
    await tester.pumpWidget(host(AkDropdown<String>(items: many, searchable: false, onChanged: (_) {})));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}
