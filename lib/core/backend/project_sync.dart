import 'dart:async';
import 'dart:convert';
import '../local/database_helper.dart';
import 'backend_adapter.dart';
import 'realtime_sync.dart';

/// Resultat d'un cycle de synchronisation.
class SyncStats {
  int pushedRows = 0;
  int pulledRows = 0;
  int bytesSent = 0;
  int bytesReceived = 0;
  bool tablesPresent = false;
  String? error;
  bool get ok => error == null;
  String get sentLabel => formatSize(bytesSent);
  String get receivedLabel => formatSize(bytesReceived);
}

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) {
    final ko = bytes / 1024;
    return '${ko.toStringAsFixed(ko < 10 ? 1 : 0)} Ko';
  }
  final mo = bytes / (1024 * 1024);
  return '${mo.toStringAsFixed(mo < 10 ? 2 : 0)} Mo';
}

/// Synchronise un projet entre les appareils via le backend deja connecte.
///
/// Principe :
///  - les tables cibles sont `_prone_*` dans le backend du projet ;
///  - chaque ecriture locale marque la ligne `sync_state = 'dirty'` ;
///  - chaque cycle pousse les lignes sales puis tire les lignes distantes ;
///  - arbitrage : la ligne locale non sale est ecrasee par la plus recente,
///    une ligne locale sale gagne (elle sera repoussee au cycle suivant).
///
/// Les tables doivent exister : [bootstrapSql] fournit le script a lancer une
/// seule fois dans la console SQL du backend.
class ProjectSync {
  ProjectSync._();
  static final ProjectSync instance = ProjectSync._();

  static const String membersTable = '_prone_members';
  static const String messagesTable = '_prone_messages';
  static const String projectsTable = '_prone_projects';

  final _db = DatabaseHelper();

  Timer? _timer;
  bool _busy = false;
  bool _pending = false;
  SyncStats? lastStats;
  void Function(SyncStats stats)? onSynced;

  static String bootstrapSql() => '''
-- Prone : synchronisation de projet (a executer une seule fois)
create table if not exists public.$messagesTable (
  id text primary key,
  project_id text not null,
  content text not null default '',
  sender_id text not null default '',
  sender_name text not null default '',
  sender_photo text not null default '',
  sender_role text not null default 'user',
  reply_to text not null default '',
  is_bot boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.$membersTable (
  id text primary key,
  project_id text not null,
  name text not null default '',
  email text not null default '',
  photo text not null default '',
  role text not null default 'viewer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.$projectsTable (
  project_id text primary key,
  name text not null default '',
  description text not null default '',
  photo text not null default '',
  status text not null default '',
  status_type text not null default 'info',
  updated_at timestamptz not null default now()
);

create index if not exists _prone_messages_project_idx on public.$messagesTable (project_id, created_at);
create index if not exists _prone_members_project_idx on public.$membersTable (project_id);

alter table public.$messagesTable enable row level security;
alter table public.$membersTable enable row level security;
alter table public.$projectsTable enable row level security;

drop policy if exists prone_sync_messages on public.$messagesTable;
drop policy if exists prone_sync_members on public.$membersTable;
drop policy if exists prone_sync_projects on public.$projectsTable;

create policy prone_sync_messages on public.$messagesTable for all using (true) with check (true);
create policy prone_sync_members on public.$membersTable for all using (true) with check (true);
create policy prone_sync_projects on public.$projectsTable for all using (true) with check (true);
''';

  static String? _normTime(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    return d == null ? s : d.toUtc().toIso8601String();
  }

  static int _normBool(Object? v) {
    if (v == true) return 1;
    if (v == false) return 0;
    if (v is num) return v.toInt() == 1 ? 1 : 0;
    final s = v?.toString().toLowerCase() ?? '';
    return (s == 'true' || s == '1') ? 1 : 0;
  }

  static String _str(Object? v) => v == null ? '' : v.toString();

  int _bytesOf(Map<String, dynamic> row) => utf8.encode(jsonEncode(row)).length;

  static bool _same(Map<String, dynamic> a, Map<String, dynamic> b, List<String> keys) {
    for (final k in keys) {
      if ('${a[k] ?? ''}' != '${b[k] ?? ''}') return false;
    }
    return true;
  }

  Future<WriteResult> _upsert(
    String url,
    String key,
    String table,
    Map<String, dynamic> values, {
    required String idColumn,
    required String idValue,
    String? type,
  }) async {
    final inserted = await BackendAdapter.insertRow(url, key, table, values, type: type);
    if (inserted.ok) return inserted;
    // Conflit de cle : la ligne existe deja, on la met a jour.
    if (inserted.statusCode == 409 || inserted.statusCode == 23505) {
      return BackendAdapter.updateRow(
        url,
        key,
        table,
        values,
        idColumn: idColumn,
        idValue: idValue,
        type: type,
      );
    }
    return inserted;
  }

  /// Verifie que les trois tables existent sur le backend.
  static Future<SyncStats> probe({
    required String url,
    required String apiKey,
    String? type,
  }) async {
    final stats = SyncStats();
    if (url.trim().isEmpty) {
      stats.error = 'Aucun backend connecte pour ce projet.';
      return stats;
    }
    final res = await BackendAdapter.fetchRows(url, apiKey, messagesTable, limit: 1, type: type);
    if (res.ok) {
      stats.tablesPresent = true;
      return stats;
    }
    stats.tablesPresent = false;
    if (res.offline) {
      stats.error = 'Backend injoignable.';
    } else if (res.error == 'HTTP 404' || res.error?.contains('404') == true) {
      stats.error = 'Tables Prone absentes du backend.';
    } else {
      stats.error = res.error ?? 'Synchronisation indisponible.';
    }
    return stats;
  }

  Future<SyncStats> syncNow({
    required String projectId,
    required String url,
    required String apiKey,
    String? type,
  }) async {
    final stats = SyncStats();
    if (url.trim().isEmpty) {
      stats.error = 'Aucun backend connecte pour ce projet.';
      return stats;
    }
    if (_busy) {
      // Un evennement realtime est arrive pendant un cycle : on le rejoue
      // juste apres, sinon la ligne serait perdue jusqu'au prochain polling.
      _pending = true;
      return lastStats ?? stats;
    }
    _busy = true;
    try {
      await _push(projectId, url, apiKey, type, stats);
      if (stats.error == null) await _pull(projectId, url, apiKey, type, stats);
      lastStats = stats;
      return stats;
    } finally {
      _busy = false;
      if (_pending) {
        _pending = false;
        unawaited(syncNow(projectId: projectId, url: url, apiKey: apiKey, type: type));
      }
    }
  }

  Future<void> _push(
    String projectId,
    String url,
    String key,
    String? type,
    SyncStats stats,
  ) async {
    // --- messages ---
    final messages = await _db.query('messages', where: 'project_id = ?', whereArgs: [projectId]);
    for (final m in messages) {
      if (m['sync_state'] != 'dirty') continue;
      final values = <String, dynamic>{
        'id': _str(m['id']),
        'project_id': projectId,
        'content': _str(m['content']),
        'sender_id': _str(m['sender_id']),
        'sender_name': _str(m['sender_name']),
        'sender_photo': _str(m['sender_photo']),
        'sender_role': _str(m['sender'] ?? 'user'),
        'reply_to': _str(m['reply_to']),
        'is_bot': _normBool(m['is_bot']) == 1,
        'created_at': _normTime(m['created_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'updated_at': _normTime(m['updated_at']) ?? DateTime.now().toUtc().toIso8601String(),
      };
      final res = await _upsert(url, key, messagesTable, values, idColumn: 'id', idValue: values['id'] as String, type: type);
      if (!res.ok) {
        stats.error = res.error;
        return;
      }
      stats.pushedRows++;
      stats.bytesSent += _bytesOf(values);
      await _db.update('messages', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [m['id']]);
    }

    // --- membres ---
    final members = await _db.query('members', where: 'project_id = ?', whereArgs: [projectId]);
    for (final m in members) {
      if (m['sync_state'] == 'synced') continue;
      final id = _str(m['id']);
      if (id.isEmpty) continue;
      final values = <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'name': _str(m['name']),
        'email': _str(m['email']),
        'photo': _str(m['photo']),
        'role': _str(m['role']),
        'created_at': _normTime(m['created_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'updated_at': _normTime(m['updated_at']) ?? DateTime.now().toUtc().toIso8601String(),
      };
      final res = await _upsert(url, key, membersTable, values, idColumn: 'id', idValue: id, type: type);
      if (!res.ok) {
        stats.error = res.error;
        return;
      }
      stats.pushedRows++;
      stats.bytesSent += _bytesOf(values);
      await _db.update('members', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [id]);
    }

    // --- reglages projet ---
    final projects = await _db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (projects.isNotEmpty) {
      final p = projects.first;
      if (p['sync_state'] == 'dirty') {
        final values = <String, dynamic>{
          'project_id': projectId,
          'name': _str(p['name']),
          'description': _str(p['description']),
          'photo': _str(p['photo']),
          'status': _str(p['status']),
          'status_type': _str(p['status_type']),
          'updated_at': _normTime(p['updated_at']) ?? DateTime.now().toUtc().toIso8601String(),
        };
        final res = await _upsert(url, key, projectsTable, values, idColumn: 'project_id', idValue: projectId, type: type);
        if (!res.ok) {
          stats.error = res.error;
          return;
        }
        stats.pushedRows++;
        stats.bytesSent += _bytesOf(values);
        await _db.update('projects', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [projectId]);
      }
    }
  }

  Future<void> _pull(
    String projectId,
    String url,
    String key,
    String? type,
    SyncStats stats,
  ) async {
    // --- messages distants ---
    final remoteMsgs = await BackendAdapter.fetchRows(
      url,
      key,
      messagesTable,
      limit: 500,
      type: type,
      searchField: 'project_id',
      searchValue: projectId,
    );
    if (!remoteMsgs.ok) {
      stats.error = remoteMsgs.error;
      stats.tablesPresent = false;
      return;
    }
    stats.tablesPresent = true;

    final localMsgs = await _db.query('messages', where: 'project_id = ?', whereArgs: [projectId]);
    final byId = <String, Map<String, dynamic>>{for (final m in localMsgs) _str(m['id']): m};

    for (final r in remoteMsgs.rows) {
      final id = _str(r['id']);
      if (id.isEmpty) continue;
      final bytes = _bytesOf(r);
      final local = byId[id];
      if (local != null && local['sync_state'] == 'dirty') continue; // local gagne

      final row = <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'content': _str(r['content']),
        'sender': _str(r['sender_role'] ?? 'user'),
        'sender_id': _str(r['sender_id']),
        'sender_name': _str(r['sender_name']),
        'sender_photo': _str(r['sender_photo']),
        'reply_to': _str(r['reply_to']),
        'is_bot': _normBool(r['is_bot']),
        'created_at': _normTime(r['created_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'updated_at': _normTime(r['updated_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'sync_state': 'synced',
      };
      const keys = ['content', 'sender_id', 'sender_name', 'sender_photo', 'sender', 'reply_to', 'is_bot'];
      if (local != null && _same(local, row, keys)) continue;
      if (local == null) {
        await _db.insert('messages', row);
      } else {
        await _db.update('messages', row, where: 'id = ?', whereArgs: [id]);
      }
      stats.pulledRows++;
      stats.bytesReceived += bytes;
    }

    // --- membres distants ---
    final remoteMembers = await BackendAdapter.fetchRows(
      url,
      key,
      membersTable,
      limit: 500,
      type: type,
      searchField: 'project_id',
      searchValue: projectId,
    );
    if (!remoteMembers.ok) {
      stats.error = remoteMembers.error;
      return;
    }
    final localMembers = await _db.query('members', where: 'project_id = ?', whereArgs: [projectId]);
    final membersById = <String, Map<String, dynamic>>{for (final m in localMembers) _str(m['id']): m};

    for (final r in remoteMembers.rows) {
      final id = _str(r['id']);
      if (id.isEmpty) continue;
      final bytes = _bytesOf(r);
      final local = membersById[id];
      if (local != null && local['sync_state'] == 'dirty') continue;

      final row = <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'organization_id': local != null ? _str(local['organization_id']) : '',
        'name': _str(r['name']),
        'email': _str(r['email']),
        'photo': _str(r['photo']),
        'role': _str(r['role']),
        'created_at': _normTime(r['created_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'updated_at': _normTime(r['updated_at']) ?? DateTime.now().toUtc().toIso8601String(),
        'sync_state': 'synced',
      };
      const keys = ['name', 'email', 'photo', 'role'];
      if (local != null && _same(local, row, keys)) continue;
      if (local == null) {
        await _db.insert('members', row);
      } else {
        await _db.update('members', row, where: 'id = ?', whereArgs: [id]);
      }
      stats.pulledRows++;
      stats.bytesReceived += bytes;
    }

    // --- reglages projet ---
    final remoteProject = await BackendAdapter.fetchRows(
      url,
      key,
      projectsTable,
      limit: 1,
      type: type,
      searchField: 'project_id',
      searchValue: projectId,
    );
    if (!remoteProject.ok || remoteProject.rows.isEmpty) return;

    final localProjects = await _db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (localProjects.isEmpty) return;
    final local = localProjects.first;
    if (local['sync_state'] == 'dirty') return;

    final r = remoteProject.rows.first;
    final remoteUpdated = _normTime(r['updated_at']) ?? '';
    final localUpdated = _normTime(local['updated_at']) ?? '';
    if (remoteUpdated.isEmpty || remoteUpdated.compareTo(localUpdated) <= 0) return;

    final row = <String, dynamic>{
      'name': _str(r['name']),
      'description': _str(r['description']),
      'photo': _str(r['photo']),
      'status': _str(r['status']),
      'status_type': _str(r['status_type']),
      'updated_at': remoteUpdated,
      'sync_state': 'synced',
    };
    await _db.update('projects', row, where: 'id = ?', whereArgs: [projectId]);
    stats.pulledRows++;
    stats.bytesReceived += _bytesOf(r);
  }

  void startPolling({
    required String projectId,
    required String url,
    required String apiKey,
    String? type,
    Duration interval = const Duration(seconds: 4),
  }) {
    if (url.trim().isEmpty) return;
    if (_timer != null && _pollingFor == projectId) return;
    stopPolling();
    _pollingFor = projectId;

    // Supabase : socket temps reel en plus du polling de securite.
    if (BackendAdapter.detect(url, type) == BackendType.supabase) {
      SupabaseRealtime.instance.attach(
        url: url,
        apiKey: apiKey,
        projectId: projectId,
        onChange: () async {
          final s = await syncNow(projectId: projectId, url: url, apiKey: apiKey, type: type);
          if (s.pushedRows > 0 || s.pulledRows > 0 || s.error != null) onSynced?.call(s);
        },
      );
    }
    _timer = Timer.periodic(interval, (_) async {
      final stats = await syncNow(projectId: projectId, url: url, apiKey: apiKey, type: type);
      final cb = onSynced;
      if (cb != null && (stats.pushedRows > 0 || stats.pulledRows > 0 || stats.error != null)) {
        cb(stats);
      }
    });
  }

  String? _pollingFor;

  void stopPolling() {
    SupabaseRealtime.instance.detach();
    _timer?.cancel();
    _timer = null;
    _pollingFor = null;
    _pending = false;
  }

  /// Reinitialisation complete, utilisee par les tests.
  void resetForTest() {
    stopPolling();
    lastStats = null;
    _busy = false;
    _pending = false;
  }
}
