import 'package:akonta/design/design.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/admin/error_log_screen.dart';
import 'package:akonta/src/presentation/widgets/async_view.dart';
import 'package:akonta/src/presentation/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/infrastructure/supabase/supabase_error_classifier.dart';

AssignedRole role(String code) => AssignedRole(roleId: 'r', code: code, name: code, entityId: null, requiresMfa: false, grantsAllEntities: true, accountingAccess: code != 'tech_admin');

Widget app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: home)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  setUpAll(() => ErrorClassifiers.register(classifier: classifySupabaseError, describer: describeSupabaseError));
  setUp(ErrorLog.instance.clear);

  group('AsyncView', () {
    testWidgets('une erreur de la base s\'affiche en français, sans vocabulaire technique', (tester) async {
      const error = PostgrestException(message: 'relation "public.entities" does not exist', code: '42P01');
      await tester.pumpWidget(app(AsyncView<int>(value: const AsyncValue.error(error, StackTrace.empty), builder: (_) => const Text('ok'))));
      expect(find.textContaining('momentanément indisponible'), findsOneWidget);
      expect(find.textContaining('relation'), findsNothing);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('réf. AK-'), findsOneWidget);
    });

    testWidgets('« Réessayer » n\'est proposé que lorsqu\'une nouvelle tentative a un sens', (tester) async {
      var calls = 0;
      await tester.pumpWidget(app(AsyncView<int>(value: AsyncValue.error(Exception('ClientException: Failed to fetch'), StackTrace.empty), builder: (_) => const Text('ok'), onRetry: () => calls++)));
      expect(find.text('Connexion impossible. Vérifiez votre réseau, puis réessayez.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(calls, 1);

      await tester.pumpWidget(app(AsyncView<int>(
        value: const AsyncValue.error(PostgrestException(message: 'new row violates row-level security policy for table "x"', code: '42501'), StackTrace.empty),
        builder: (_) => const Text('ok'),
        onRetry: () => calls++,
      )));
      expect(find.textContaining('droits nécessaires'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });
  });

  testWidgets('showError affiche un toast sans détail technique, avec l\'action tentée', (tester) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showError(context, const PostgrestException(message: 'duplicate key value violates unique constraint "entities_tax_id_unique"', code: '23505'), action: 'Enregistrement impossible'),
        child: const Text('go'),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Enregistrement impossible : Cet IFU existe déjà dans le cabinet.'), findsOneWidget);
    expect(find.textContaining('constraint'), findsNothing);
  });

  group('journal des erreurs', () {
    List<Override> asRole(String code) => [permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [role(code)]))];

    testWidgets('l\'administrateur technique retrouve le détail à partir de la référence', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shown = humanizeError(const PostgrestException(message: 'relation "public.secret" does not exist', code: '42P01'));
      await tester.pumpWidget(app(const ErrorLogScreen(), overrides: asRole('tech_admin')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('error-log-${shown.reference}')), findsOneWidget);
      expect(find.textContaining('public.secret'), findsOneWidget);
      await tester.tap(find.byKey(const Key('error-log-clear')));
      await tester.pump();
      expect(find.text('Aucune erreur enregistrée sur cet appareil.'), findsOneWidget);
    });

    testWidgets('les autres rôles ne voient pas le journal', (tester) async {
      humanizeError(StateError('secret interne'));
      await tester.pumpWidget(app(const ErrorLogScreen(), overrides: asRole('partner')));
      await tester.pumpAndSettle();
      expect(find.text('Cet écran est réservé à l\'administrateur technique.'), findsOneWidget);
      expect(find.textContaining('secret interne'), findsNothing);
    });
  });
}
