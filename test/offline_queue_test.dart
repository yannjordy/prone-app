import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectflow_app/core/offline/offline_queue.dart';
import 'package:connectflow_app/core/notifications/error_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineQueue.instance.clearAll();
  });

  group('OfflineQueue', () {
    test('vide au depart', () async {
      expect(await OfflineQueue.instance.pending('p1'), isEmpty);
      expect(await OfflineQueue.instance.pendingAll(), isEmpty);
    });

    test('enqueue + pending par projet', () async {
      await OfflineQueue.instance.enqueue('p1', '/users');
      await OfflineQueue.instance.enqueue('p1', '/tables');
      await OfflineQueue.instance.enqueue('p2', '/status');

      expect((await OfflineQueue.instance.pending('p1')).length, 2);
      expect((await OfflineQueue.instance.pending('p2')).length, 1);
      expect((await OfflineQueue.instance.pendingAll()).length, 3);
    });

    test('commande stockee avec son texte', () async {
      final item = await OfflineQueue.instance.enqueue('p1', '/count users');
      expect(item.command, '/count users');
      expect(item.projectId, 'p1');
      expect(item.attempts, 0);
      expect(item.id, isNotEmpty);
    });

    test('remove supprime seulement la bonne commande', () async {
      final a = await OfflineQueue.instance.enqueue('p1', '/last orders');
      await OfflineQueue.instance.enqueue('p1', '/schema users');
      await OfflineQueue.instance.remove(a.id);

      final rest = await OfflineQueue.instance.pending('p1');
      expect(rest.length, 1);
      expect(rest.first.command, '/schema users');
    });

    test('bumpAttempts incremente', () async {
      final a = await OfflineQueue.instance.enqueue('p1', '/ping');
      await OfflineQueue.instance.bumpAttempts(a.id);
      await OfflineQueue.instance.bumpAttempts(a.id);
      final rest = await OfflineQueue.instance.pending('p1');
      expect(rest.first.attempts, 2);
    });

    test('clearProject laisse les autres projets', () async {
      await OfflineQueue.instance.enqueue('p1', '/a');
      await OfflineQueue.instance.enqueue('p2', '/b');
      await OfflineQueue.instance.clearProject('p1');

      expect(await OfflineQueue.instance.pending('p1'), isEmpty);
      expect((await OfflineQueue.instance.pending('p2')).length, 1);
    });

    test('la file survit a une relecture (persistance)', () async {
      await OfflineQueue.instance.enqueue('p1', '/users');
      final again = await OfflineQueue.instance.pending('p1');
      expect(again.first.command, '/users');
    });
  });

  group('BackendErrorStore', () {
    test('vide au depart', () async {
      expect(await BackendErrorStore.instance.recent('p1'), isEmpty);
      expect(await BackendErrorStore.instance.unreadCount('p1'), 0);
    });

    test('record + unread count', () async {
      await BackendErrorStore.instance.record('p1', 'boom');
      await BackendErrorStore.instance.record('p1', 'bam', command: '/users');
      expect((await BackendErrorStore.instance.recent('p1')).length, 2);
      expect(await BackendErrorStore.instance.unreadCount('p1'), 2);
    });

    test('la plus recente est en premier', () async {
      await BackendErrorStore.instance.record('p1', 'first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await BackendErrorStore.instance.record('p1', 'second');
      final items = await BackendErrorStore.instance.recent('p1');
      expect(items.first.message, 'second');
    });

    test('markAllRead remet le compteur a zero', () async {
      await BackendErrorStore.instance.record('p1', 'e');
      await BackendErrorStore.instance.record('p1', 'f');
      await BackendErrorStore.instance.markAllRead('p1');
      expect(await BackendErrorStore.instance.unreadCount('p1'), 0);
      expect((await BackendErrorStore.instance.recent('p1')).length, 2);
    });

    test('clear supprime tout', () async {
      await BackendErrorStore.instance.record('p1', 'e');
      await BackendErrorStore.instance.clear('p1');
      expect(await BackendErrorStore.instance.recent('p1'), isEmpty);
    });

    test('les erreurs sont isolees par projet', () async {
      await BackendErrorStore.instance.record('p1', 'a');
      await BackendErrorStore.instance.record('p2', 'b');
      expect((await BackendErrorStore.instance.recent('p1')).length, 1);
      expect((await BackendErrorStore.instance.recent('p2')).length, 1);
      expect((await BackendErrorStore.instance.recent('p1')).first.message, 'a');
    });

    test('conserve le niveau et la commande', () async {
      await BackendErrorStore.instance.record('p1', 'offline', command: '/status', level: ErrorLevel.offline);
      final e = (await BackendErrorStore.instance.recent('p1')).first;
      expect(e.level, ErrorLevel.offline);
      expect(e.command, '/status');
      expect(e.read, isFalse);
    });
  });
}
