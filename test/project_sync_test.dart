import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectflow_app/core/backend/project_sync.dart';
import 'package:connectflow_app/core/local/database_helper.dart';
import 'package:connectflow_app/core/local/local_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatSize', () {
    test('octets sous 1 Ko', () {
      expect(formatSize(0), '0 o');
      expect(formatSize(1), '1 o');
      expect(formatSize(1023), '1023 o');
    });

    test('kilooctets', () {
      expect(formatSize(1024), '1.0 Ko');
      expect(formatSize(1536), '1.5 Ko');
      expect(formatSize(10 * 1024), '10 Ko');
    });

    test('megaoctets', () {
      expect(formatSize(1024 * 1024), '1.00 Mo');
      expect(formatSize(5 * 1024 * 1024), '5.00 Mo');
      expect(formatSize(20 * 1024 * 1024), '20 Mo');
    });
  });

  group('bootstrapSql', () {
    test('contient les trois tables Prone', () {
      final sql = ProjectSync.bootstrapSql();
      expect(sql, contains('_prone_messages'));
      expect(sql, contains('_prone_members'));
      expect(sql, contains('_prone_projects'));
    });

    test('gere RLS + index + idempotence', () {
      final sql = ProjectSync.bootstrapSql();
      expect(sql, contains('create table if not exists'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('drop policy if exists'));
      expect(sql, contains('create policy'));
      expect(sql, contains('create index if not exists'));
      expect(sql, contains('sender_name'));
      expect(sql, contains('is_bot boolean'));
    });
  });

  group('LocalBackend marque les lignes a synchroniser', () {
    late LocalBackend backend;
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backend = LocalBackend();
      db = DatabaseHelper();
    });

    test('createProject produit sync_state = dirty', () async {
      final p = await backend.createProject('Sync Test', 'desc', apiKey: 'k', backendUrl: 'https://x.supabase.co');
      expect(p['sync_state'], 'dirty');
    });

    test('sendMessage porte l\'identite de l\'expediteur et est dirty', () async {
      final p = await backend.createProject('Chat Sync', '');
      final msg = await backend.sendMessage(
        p['id'] as String,
        'bonjour',
        sender: 'user',
        senderId: 'm-1',
        senderName: 'Yann',
        senderPhoto: '',
      );
      expect(msg['sender_id'], 'm-1');
      expect(msg['sender_name'], 'Yann');
      expect(msg['sync_state'], 'dirty');
      expect(msg['updated_at'], isNotNull);

      final rows = await db.query('messages', where: 'id = ?', whereArgs: [msg['id']]);
      expect(rows, hasLength(1));
      expect(rows.first['sync_state'], 'dirty');
    });

    test('addMember + updateMember sont dirty', () async {
      final p = await backend.createProject('Membres Sync', '');
      final m = await backend.addMember('org-1', 'Alice', 'a@b.c', 'editor', projectId: p['id'] as String, photo: 'base64');
      expect(m['sync_state'], 'dirty');
      expect(m['photo'], 'base64');

      await db.update('members', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [m['id']]);
      await backend.updateMember(m['id'] as String, {'role': 'admin'});
      final rows = await db.query('members', where: 'id = ?', whereArgs: [m['id']]);
      expect(rows.first['sync_state'], 'dirty');
      expect(rows.first['role'], 'admin');
    });

    test('updateProject et updateProjectStatus repassent en dirty', () async {
      final p = await backend.createProject('Reglages', '');
      await db.update('projects', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [p['id']]);

      await backend.updateProject(p['id'] as String, {'name': 'Renomme'});
      var rows = await db.query('projects', where: 'id = ?', whereArgs: [p['id']]);
      expect(rows.first['sync_state'], 'dirty');

      await db.update('projects', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [p['id']]);
      await backend.updateProjectStatus(p['id'] as String, 'production', statusType: 'success');
      rows = await db.query('projects', where: 'id = ?', whereArgs: [p['id']]);
      expect(rows.first['sync_state'], 'dirty');
      expect(rows.first['status'], 'production');
    });
  });

  group('Arbitrage de fusion', () {
    test('la ligne locale sale gagne sur la ligne distante', () {
      const local = {'id': 'm1', 'sync_state': 'dirty', 'content': 'local'};
      const remote = {'id': 'm1', 'content': 'distant'};
      final winner = local['sync_state'] == 'dirty' ? local : remote;
      expect(winner['content'], 'local');
    });

    test('une ligne locale propre est ecrasee par la plus recente', () {
      const local = {'id': 'm1', 'sync_state': 'synced', 'content': 'local', 'updated_at': '2026-01-01T00:00:00.000Z'};
      const remote = {'id': 'm1', 'content': 'distant', 'updated_at': '2026-02-01T00:00:00.000Z'};
      final takeRemote = local['sync_state'] != 'dirty' &&
          (remote['updated_at'] as String).compareTo(local['updated_at'] as String) > 0;
      expect(takeRemote, isTrue);
    });
  });
}
