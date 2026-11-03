import 'package:akonta/design/design.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simule le presse-papiers de la plateforme ; `fail` fait échouer l'écriture comme un navigateur qui la refuse.
List<String> _mockClipboard({bool fail = false}) {
  final copied = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      if (fail) throw PlatformException(code: 'unavailable');
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  return copied;
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAkontaTheme(),
      home: Scaffold(
        body: TemporaryAccessDialog(title: 'Compte client créé', accesses: [const TemporaryAccess(email: 'zanta@client.bj', password: 'Provisoire-123')]),
      ),
    ),
  );
}

void main() {
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  testWidgets('« Copier le mot de passe » ne copie que le mot de passe', (tester) async {
    final copied = _mockClipboard();
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('copy-password-zanta@client.bj')));
    await tester.pump();
    expect(copied, ['Provisoire-123']);
    expect(find.text('Mot de passe copié'), findsOneWidget);
  });

  testWidgets('« Copier le message » copie le message complet', (tester) async {
    final copied = _mockClipboard();
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('copy-message-zanta@client.bj')));
    await tester.pump();
    expect(copied.single, contains('Identifiant : zanta@client.bj'));
    expect(copied.single, contains('Mot de passe provisoire : Provisoire-123'));
    expect(find.text('Message copié'), findsOneWidget);
  });

  testWidgets('si la copie échoue, aucun « copié » n\'est affiché', (tester) async {
    _mockClipboard(fail: true);
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('copy-password-zanta@client.bj')));
    await tester.pump();
    expect(find.text('Mot de passe copié'), findsNothing);
    expect(find.textContaining('Copie impossible'), findsOneWidget);
  });
}
