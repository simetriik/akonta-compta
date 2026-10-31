import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'src/app.dart';
import 'src/composition/compose_app.dart';
import 'src/core/errors/errors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  installErrorHooks();
  final composition = await composeApp();
  runApp(ProviderScope(overrides: composition.overrides, child: const AkontaApp()));
}
