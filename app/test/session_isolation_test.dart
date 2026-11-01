import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/auth_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/admin_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utilisateur « connecté » que le test change à volonté.
class _FakeSession extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void signInAs(String? id) => state = id == null ? null : AuthSession(userId: id, email: '$id@test');
}

final _fakeSession = NotifierProvider<_FakeSession, AuthSession?>(_FakeSession.new);

/// Dépôt dont la réponse dépend de qui est connecté, comme la base avec sa sécurité par ligne.
class _PerUserAdmin implements AdminRepository {
  _PerUserAdmin(this._who);

  final String? Function() _who;

  @override
  Future<List<Profile>> profiles() async => _who() == 'admin'
      ? const [
          Profile(id: 'a', cabinetId: 'c', email: 'admin@t', fullName: 'Administrateur', isActive: true),
          Profile(id: 'p', cabinetId: 'c', email: 'associe@t', fullName: 'Associé', isActive: true),
        ]
      : const [Profile(id: 'p', cabinetId: 'c', email: 'associe@t', fullName: 'Associé', isActive: true)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('les listes d\'un utilisateur ne sont pas montrées au suivant dans la même session', () async {
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_fakeSession)),
        adminRepositoryProvider.overrideWith((ref) => _PerUserAdmin(() => container.read(_fakeSession)?.userId)),
      ],
    );
    addTearDown(container.dispose);
    // Garde le fournisseur vivant, comme un écran ouvert.
    container.listen(profilesProvider, (_, _) {});

    container.read(_fakeSession.notifier).signInAs('admin');
    expect((await container.read(profilesProvider.future)).map((p) => p.id), ['a', 'p']);

    // Déconnexion puis connexion de l'associé, sans recharger l'application.
    container.read(_fakeSession.notifier).signInAs(null);
    container.read(_fakeSession.notifier).signInAs('p');
    expect((await container.read(profilesProvider.future)).map((p) => p.id), ['p'], reason: 'l\'associé ne doit pas hériter de la liste de l\'administrateur');
  });
}
