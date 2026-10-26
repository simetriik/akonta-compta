import 'dart:io';

import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Taille d'écran desktop des captures.
const desktopSize = Size(1280, 800);

/// Taille d'écran mobile des captures.
const mobileSize = Size(390, 844);

/// Charge les polices embarquées (sinon les tests rendent des blocs « Ahem » illisibles).
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  // Icônes Material : police du SDK Flutter (sinon des carrés vides à la place des icônes).
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
  await load('IBMPlexSans', ['IBMPlexSans-Regular.ttf', 'IBMPlexSans-Medium.ttf', 'IBMPlexSans-SemiBold.ttf']);
  await load('IBMPlexMono', ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf']);
  await load('Poppins', ['Poppins-SemiBold.ttf']);
}

/// Initialisation commune : polices et formats de dates français.
Future<void> setUpGolden() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await initializeDateFormatting('fr_FR');
}

/// Fixe la surface de rendu (densité 1) pour la durée du test.
void useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Enveloppe un écran dans l'application : thème Akonta, locale fr, surcharges de providers.
Widget goldenApp({required Widget home, List<Override> overrides = const [], bool scaffold = true}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAkontaTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: scaffold ? Scaffold(body: home) : home,
    ),
  );
}

/// Compare la capture au golden `goldens/<name>.png`.
Future<void> expectGolden(WidgetTester tester, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

/// Affiche l'écran puis attend la fin des animations et le décodage des logos (hors horloge simulée).
Future<void> pumpScreen(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final name in ['akonta-lockup-horizontal-black-1200', 'akonta-symbol-black-128', 'akonta-symbol-small-black-48']) {
      await precacheImage(AssetImage('assets/logo/$name.png'), context);
    }
  });
  await tester.pumpAndSettle();
}
