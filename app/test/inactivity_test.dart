import 'package:akonta/src/presentation/auth/inactivity_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('déconnecte après le délai sans activité', () {
    fakeAsync((async) {
      var fired = 0;
      final c = InactivityController(timeout: const Duration(minutes: 30), onTimeout: () => fired++)..reset();
      async.elapse(const Duration(minutes: 29));
      expect(fired, 0);
      async.elapse(const Duration(minutes: 2));
      expect(fired, 1);
      c.dispose();
    });
  });

  test('toute activité remet le compteur à zéro', () {
    fakeAsync((async) {
      var fired = 0;
      final c = InactivityController(timeout: const Duration(minutes: 30), onTimeout: () => fired++)..reset();
      async.elapse(const Duration(minutes: 20));
      c.reset();
      async.elapse(const Duration(minutes: 20));
      expect(fired, 0, reason: 'activité à 20 min : le délai repart');
      async.elapse(const Duration(minutes: 11));
      expect(fired, 1);
      c.dispose();
    });
  });

  test('désactivé hors session', () {
    fakeAsync((async) {
      var fired = 0;
      InactivityController(timeout: const Duration(minutes: 1), onTimeout: () => fired++, enabled: false).reset();
      async.elapse(const Duration(minutes: 5));
      expect(fired, 0);
    });
  });
}
