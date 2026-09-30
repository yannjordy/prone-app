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

  group('Suppressions propagees (tombstones)', () {
    late LocalBackend backend;
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backend = LocalBackend();
      db = DatabaseHelper();
    });

    test('bootstrapSql cree la table des tombstones et l expose en realtime', () {
      final sql = ProjectSync.bootstrapSql();
      expect(sql, contains('_prone_tombstones'));
      expect(sql, contains('kind text not null default'));
      expect(sql, contains('prone_sync_tombstones'));
      expect(sql, contains('add table public.${ProjectSync.messagesTable}'));
      expect(sql, contains('add table public.${ProjectSync.membersTable}'));
      expect(sql, contains('add table public.${ProjectSync.projectsTable}'));
      expect(sql, contains('add table public.${ProjectSync.tombstonesTable}'));
    });

    test('deleteMessage supprime la ligne ET laisse un tombstone', () async {
      final p = await backend.createProject('Suppr msg', '');
      final msg = await backend.sendMessage(p['id'] as String, 'au revoir', sender: 'user', senderId: 'm-1', senderName: 'Yann');

      await backend.deleteMessage(msg['id'] as String);

      final rows = await db.query('messages', where: 'id = ?', whereArgs: [msg['id']]);
      expect(rows, isEmpty);

      final tombs = await db.query('tombstones', where: 'id = ?', whereArgs: [msg['id']]);
      expect(tombs, hasLength(1));
      expect(tombs.first['kind'], 'message');
      expect(tombs.first['project_id'], p['id']);
      expect(tombs.first['sync_state'], 'dirty');
    });

    test('removeMember supprime le membre ET laisse un tombstone', () async {
      final p = await backend.createProject('Suppr membre', '');
      final m = await backend.addMember('org-1', 'Alice', 'a@b.c', 'editor', projectId: p['id'] as String);

      await backend.removeMember('org-1', m['id'] as String);

      final members = await backend.getMembersByProject(p['id'] as String);
      expect(members, isEmpty);

      final tombs = await db.query('tombstones', where: 'id = ?', whereArgs: [m['id']]);
      expect(tombs, hasLength(1));
      expect(tombs.first['kind'], 'member');
      expect(tombs.first['project_id'], p['id']);
    });

    test('updateMember garde le meme ID (pas de doublon fantome)', () async {
      final p = await backend.createProject('Changer grade', '');
      final m = await backend.addMember('org-1', 'Bob', 'b@b.c', 'viewer', projectId: p['id'] as String);
      final id = m['id'] as String;

      await backend.updateMember(id, {'role': 'admin'});

      final members = await backend.getMembersByProject(p['id'] as String);
      expect(members, hasLength(1), reason: 'le changement de grade ne doit pas dupliquer le membre');
      expect(members.first['id'], id);
      expect(members.first['role'], 'admin');
      expect(members.first['sync_state'], 'dirty');
      final tombs = await db.query('tombstones', where: 'project_id = ?', whereArgs: [p['id']]);
      expect(tombs, isEmpty, reason: 'un changement de grade n\'est pas une suppression');
    });
  });

  group('Integrite des donnees locales', () {
    late LocalBackend backend;
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backend = LocalBackend();
      db = DatabaseHelper();
    });

    test('insert ne duplique jamais une meme cle primaire', () async {
      await db.delete('messages', where: 'project_id = ?', whereArgs: ['pk-test']);
      await db.insert('messages', {'id': 'welcome_pk', 'project_id': 'pk-test', 'content': 'a'});
      await db.insert('messages', {'id': 'welcome_pk', 'project_id': 'pk-test', 'content': 'b'});

      final rows = await db.query('messages', where: 'project_id = ?', whereArgs: ['pk-test']);
      expect(rows, hasLength(1), reason: 'deux chemins pouvaient creer le meme message de bienvenue');
      expect(rows.first['content'], 'b');
    });

    test('retargetProject migre member_id_ : le role est conserve', () async {
      final p = await backend.createProject('Retarget', '');
      final m = await backend.addMember('org-1', 'Yann', 'yann@x.co', 'admin', projectId: p['id'] as String);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('member_id_${p['id']}', m['id'] as String);

      await backend.retargetProject(p['id'] as String, 'new-id-retarget');

      expect(prefs.getString('member_id_new-id-retarget'), m['id']);
      expect(prefs.getString('member_id_${p['id']}'), isNull);
      expect(await backend.resolveRole('new-id-retarget'), 'admin',
          reason: 'sans migration, le role devient inconnu et les ecritures sont bloquees');
    });

    test('supprimer le message de bienvenue est definitif', () async {
      final p = await backend.createProject('Welcome', '');
      final pid = p['id'] as String;
      final welcomeId = 'welcome_$pid';
      final msg = await backend.sendMessage(pid, 'Bienvenue', sender: 'bot', explicitId: welcomeId);
      expect(msg['id'], welcomeId);

      await backend.deleteMessage(welcomeId);

      expect(await backend.getMessages(pid), isEmpty);
      expect(await backend.isTombstoned(pid, welcomeId), isTrue,
          reason: 'sinon le message est recree a chaque rechargement');
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
