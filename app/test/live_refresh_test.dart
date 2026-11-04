import 'dart:async';

import 'package:akonta/src/application/providers/live_refresh_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/realtime/change_feed.dart';
import 'package:akonta/src/application/realtime/live_refresh.dart';
import 'package:akonta/src/domain/auth_models.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écoute factice : les tests déclenchent eux-mêmes changements et coupures.
class FakeSubscription implements ChangeSubscription {
  FakeSubscription({this.connected = true});

  final _changes = StreamController<ChangeTopic>.broadcast(sync: true);
  final _connection = StreamController<bool>.broadcast(sync: true);
  bool connected;
  bool closed = false;

  void emit(ChangeTopic t) => _changes.add(t);

  void setConnected(bool v) {
    connected = v;
    _connection.add(v);
  }

  @override
  Stream<ChangeTopic> get changes => _changes.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('LiveRefresh', () {
    test('regroupe une rafale de changements en une seule relecture', () {
      fakeAsync((async) {
        final calls = <Set<ChangeTopic>>[];
        final sub = FakeSubscription();
        LiveRefresh(onRefresh: calls.add).attach(sub);

        sub.emit(ChangeTopic.entries);
        async.elapse(const Duration(milliseconds: 200));
        sub.emit(ChangeTopic.entries);
        sub.emit(ChangeTopic.documents);
        async.elapse(const Duration(milliseconds: 499));
        expect(calls, isEmpty);

        async.elapse(const Duration(milliseconds: 2));
        expect(calls, [
          {ChangeTopic.entries, ChangeTopic.documents},
        ]);
      });
    });

    test('canal connecté : aucune relecture périodique', () {
      fakeAsync((async) {
        final calls = <Set<ChangeTopic>>[];
        LiveRefresh(onRefresh: calls.add).attach(FakeSubscription());
        async.elapse(const Duration(minutes: 10));
        expect(calls, isEmpty);
      });
    });

    test('canal coupé : relecture toutes les 60 s, puis rattrapage à la reconnexion', () {
      fakeAsync((async) {
        final calls = <Set<ChangeTopic>>[];
        final sub = FakeSubscription(connected: false);
        LiveRefresh(onRefresh: calls.add).attach(sub);

        async.elapse(const Duration(seconds: 61));
        expect(calls, hasLength(1));
        expect(calls.single, ChangeTopic.values.toSet());

        // Première connexion : les listes viennent d'être lues, pas de relecture en plus.
        sub.setConnected(true);
        expect(calls, hasLength(1));
        async.elapse(const Duration(minutes: 5));
        expect(calls, hasLength(1));

        // Coupure puis reconnexion : tout est relu une fois.
        sub.setConnected(false);
        sub.setConnected(true);
        expect(calls, hasLength(2));
        async.elapse(const Duration(minutes: 5));
        expect(calls, hasLength(2));
      });
    });

    test('refreshAll relit tout et annule les changements en attente', () {
      fakeAsync((async) {
        final calls = <Set<ChangeTopic>>[];
        final sub = FakeSubscription();
        final live = LiveRefresh(onRefresh: calls.add)..attach(sub);
        sub.emit(ChangeTopic.entries);
        live.refreshAll();
        async.elapse(const Duration(seconds: 2));
        expect(calls, [ChangeTopic.values.toSet()]);
      });
    });

    test('dispose ferme l\'écoute et arrête les relectures', () {
      fakeAsync((async) {
        final calls = <Set<ChangeTopic>>[];
        final sub = FakeSubscription(connected: false);
        final live = LiveRefresh(onRefresh: calls.add)..attach(sub);
        live.dispose();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));
        expect(calls, isEmpty);
        expect(sub.closed, isTrue);
      });
    });
  });

  group('liveRefreshProvider', () {
    test('n\'ouvre aucune écoute sans utilisateur connecté', () {
      final feed = _CountingFeed();
      final container = ProviderContainer(overrides: [changeFeedProvider.overrideWithValue(feed), currentUserProvider.overrideWithValue(null)]);
      addTearDown(container.dispose);
      container.read(liveRefreshProvider);
      expect(feed.opened, 0);
    });

    test('ouvre une écoute pour l\'utilisateur connecté et la ferme à la libération', () {
      final feed = _CountingFeed();
      final container = ProviderContainer(overrides: [
        changeFeedProvider.overrideWithValue(feed),
        currentUserProvider.overrideWithValue(const AuthSession(userId: 'user-1', email: 'u@test')),
        isOnlineProvider.overrideWithValue(const AsyncData(true)),
      ]);
      container.read(liveRefreshProvider);
      expect(feed.opened, 1);
      expect(feed.lastUserId, 'user-1');
      container.dispose();
      expect(feed.subscription.closed, isTrue);
    });

    test('un changement d\'écriture ou de lettrage relance l\'écran de lettrage, un pointage celui du rapprochement', () {
      fakeAsync((async) {
        final feed = _CountingFeed();
        final container = ProviderContainer(overrides: [
          changeFeedProvider.overrideWithValue(feed),
          currentUserProvider.overrideWithValue(const AuthSession(userId: 'user-1', email: 'u@test')),
          isOnlineProvider.overrideWithValue(const AsyncData(true)),
        ]);
        container.read(liveRefreshProvider);
        container.listen(letteringRevisionProvider, (_, _) {});
        container.listen(reconciliationRevisionProvider, (_, _) {});

        feed.subscription.emit(ChangeTopic.lettering);
        async.elapse(const Duration(seconds: 1));
        expect(container.read(letteringRevisionProvider), 1);
        expect(container.read(reconciliationRevisionProvider), 0);

        feed.subscription.emit(ChangeTopic.reconciliation);
        async.elapse(const Duration(seconds: 1));
        expect(container.read(letteringRevisionProvider), 1);
        expect(container.read(reconciliationRevisionProvider), 1);

        // De nouvelles écritures changent les lignes à lettrer comme à pointer.
        feed.subscription.emit(ChangeTopic.entries);
        async.elapse(const Duration(seconds: 1));
        expect(container.read(letteringRevisionProvider), 2);
        expect(container.read(reconciliationRevisionProvider), 2);
        container.dispose();
      });
    });
  });
}

class _CountingFeed implements ChangeFeedPort {
  int opened = 0;
  String? lastUserId;
  late FakeSubscription subscription;

  @override
  ChangeSubscription? open({required String userId, String? entityId}) {
    opened++;
    lastUserId = userId;
    return subscription = FakeSubscription();
  }
}
