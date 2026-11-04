import 'package:akonta/src/application/preferences/last_entity_store.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/auth_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/infrastructure/local/shared_prefs_last_entity_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => const AuthSession(userId: 'u1', email: 'u1@test');

  void signInAs(String? id) => state = id == null ? null : AuthSession(userId: id, email: '$id@test');
}

final _fakeSession = NotifierProvider<_FakeSession, AuthSession?>(_FakeSession.new);

class _MemoryStore implements LastEntityStore {
  final values = <String, String>{};
  bool failReads = false;

  @override
  Future<String?> read(String userId) async {
    if (failReads) throw StateError('stockage illisible');
    return values[userId];
  }

  @override
  Future<void> write(String userId, String? entityId) async => entityId == null ? values.remove(userId) : values[userId] = entityId;
}

const _a = EntitySummary(id: 'a', name: 'SARL A');
const _b = EntitySummary(id: 'b', name: 'SA B');

ProviderContainer _container(_MemoryStore store) {
  final c = ProviderContainer(overrides: [currentUserProvider.overrideWith((ref) => ref.watch(_fakeSession)), lastEntityStoreProvider.overrideWithValue(store)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('choisir un dossier le mémorise pour l\'utilisateur connecté', () async {
    final store = _MemoryStore();
    final c = _container(store);
    c.read(currentEntityProvider.notifier).select(_b);
    await Future<void>.delayed(Duration.zero);
    expect(store.values, {'u1': 'b'});
  });

  test('après rechargement, le dossier mémorisé est retrouvé parmi les dossiers accessibles', () async {
    final store = _MemoryStore()..values['u1'] = 'b';
    final c = _container(store);
    final saved = await c.read(savedEntityIdProvider.future);
    expect(restoreSavedEntity(const [_a, _b], saved)?.id, 'b');
  });

  test('un dossier supprimé ou dont l\'accès est retiré n\'est pas forcé', () {
    expect(restoreSavedEntity(const [_a], 'b'), isNull);
    expect(restoreSavedEntity(const [_a, _b], null), isNull);
  });

  test('la mémoire est propre à chaque utilisateur', () async {
    final store = _MemoryStore()..values['u1'] = 'a';
    final c = _container(store);
    c.listen(savedEntityIdProvider, (_, _) {});
    expect(await c.read(savedEntityIdProvider.future), 'a');
    c.read(_fakeSession.notifier).signInAs('u2');
    expect(await c.read(savedEntityIdProvider.future), isNull, reason: 'u2 n\'hérite pas du dossier de u1');
  });

  test('une mémoire illisible ne bloque rien', () async {
    final store = _MemoryStore()..failReads = true;
    final c = _container(store);
    expect(await c.read(savedEntityIdProvider.future), isNull);
  });

  test('l\'adaptateur du stockage local écrit, relit et oublie, une clé par utilisateur', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsLastEntityStore(await SharedPreferences.getInstance());
    await store.write('u1', 'a');
    await store.write('u2', 'b');
    expect(await store.read('u1'), 'a');
    expect(await store.read('u2'), 'b');
    await store.write('u1', null);
    expect(await store.read('u1'), isNull);
    expect(await store.read('u2'), 'b');
  });
}
