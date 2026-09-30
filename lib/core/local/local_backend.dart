import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'user_profile.dart';

class LocalBackend {
  static final LocalBackend _instance = LocalBackend._();
  factory LocalBackend() => _instance;
  LocalBackend._();

  final _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> getOrganizations() async {
    return await _db.query('organizations', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getOrganization(String id) async {
    final results = await _db.query('organizations', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>> createOrganization(String name, String description, {String? photo, String? color}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join().substring(0, name.split(' ').length.clamp(0, 2).toInt());
    final org = {
      'id': id, 'name': name, 'description': description,
      'photo': photo ?? '', 'color': color ?? '#555555', 'initials': initials,
      'is_archived': 0,
      'created_at': now, 'updated_at': now,
    };
    await _db.insert('organizations', org);
    return org;
  }

  Future<void> updateOrganization(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.update('organizations', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOrganization(String id) async {
    for (final table in ['projects', 'members', 'messages', 'logs']) {
      await _db.delete(table, where: 'organization_id = ?', whereArgs: [id]);
    }
    await _db.delete('organizations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getOrganizationProjectCount(String orgId) async {
    final projects = await _db.query('projects', where: 'organization_id = ?', whereArgs: [orgId]);
    return projects.length;
  }

  Future<int> getOrganizationMemberCount(String orgId) async {
    final members = await _db.query('members', where: 'organization_id = ?', whereArgs: [orgId]);
    return members.length;
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    return await _db.query('projects', orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, dynamic>>> getProjectsByOrganization(String orgId) async {
    return await _db.query('projects', where: 'organization_id = ?', whereArgs: [orgId], orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>> createProject(String name, String description, {String? apiKey, String? backendUrl, String? photo, String? organizationId, String? id}) async {
    final pid = (id != null && id.isNotEmpty) ? id : _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final project = {
      'id': pid, 'organization_id': organizationId ?? '', 'name': name, 'description': description,
      'api_key': apiKey ?? '', 'backend_url': backendUrl ?? '',
      'photo': photo ?? '',
      'join_code': _generateJoinCode(),
      'status': '', 'status_type': 'info', 'status_updated_at': '',
      'sync_state': 'dirty',
      'is_pinned': 0, 'is_archived': 0, 'is_muted': 0,
      'created_at': now, 'updated_at': now,
    };
    await _db.insert('projects', project);
    return project;
  }

  String _generateJoinCode() {
    // Position par position : l'ancienne formule arithmetique ne produisait
    // que 10 codes differents pour toute l'application (collisions).
    final chars = '0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final out = StringBuffer();
    var seed = now ^ (DateTime.now().millisecondsSinceEpoch << 16);
    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      out.write(chars[seed % chars.length]);
    }
    return out.toString();
  }

  Future<String> getOrCreateJoinCode(String projectId) async {
    final projects = await _db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (projects.isEmpty) return '';
    final project = projects.first;
    if (project['join_code'] != null && (project['join_code'] as String).isNotEmpty) {
      return project['join_code'] as String;
    }
    final code = _generateJoinCode();
    await _db.update('projects', {'join_code': code}, where: 'id = ?', whereArgs: [projectId]);
    return code;
  }

  Future<Map<String, dynamic>?> findByJoinCode(String code) async {
    final projects = await _db.query('projects', where: 'join_code = ?', whereArgs: [code]);
    return projects.isNotEmpty ? projects.first : null;
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final members = await _db.query('members');
    final q = query.toLowerCase();
    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final m in members) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final email = (m['email'] as String? ?? '').toLowerCase();
      if ((name.contains(q) || email.contains(q)) && !seen.contains(email)) {
        seen.add(email);
        results.add({'name': m['name'], 'email': m['email'], 'photo': m['photo'] ?? ''});
      }
      if (results.length >= 10) break;
    }
    return results;
  }

  Future<void> updateProject(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    updates['sync_state'] = 'dirty';
    await _db.update('projects', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// Change l'identifiant d'un projet et repointe ses membres/messages :
  /// utilise quand une invitation impose l'ID partage par l'inviteur.
  Future<void> retargetProject(String oldId, String newId) async {
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final members = await _db.query('members', where: 'project_id = ?', whereArgs: [oldId]);
    for (final m in members) {
      await _db.update('members', {'project_id': newId, 'updated_at': now, 'sync_state': 'dirty'},
          where: 'id = ?', whereArgs: [m['id']]);
    }
    final msgs = await _db.query('messages', where: 'project_id = ?', whereArgs: [oldId]);
    for (final m in msgs) {
      await _db.update('messages', {'project_id': newId, 'updated_at': now, 'sync_state': 'dirty'},
          where: 'id = ?', whereArgs: [m['id']]);
    }
    await _db.update('projects', {'id': newId, 'updated_at': now, 'sync_state': 'dirty'},
        where: 'id = ?', whereArgs: [oldId]);
    // Les cles derivees de l'ancien id : sans migration le role n'est plus
    // resolvable apres retarget (ecritures bloquees, doublons de membres).
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'member_id_$oldId',
        'bot_name_$oldId',
        'bot_photo_$oldId',
      ]) {
        final value = prefs.getString(key);
        if (value != null) {
          await prefs.setString(key.replaceFirst(oldId, newId), value);
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  /// Marque un projet comme etant la copie locale d'une entite distante :
  /// la prochaine lecture remontera le nom/photo/description de l'inviteur
  /// plutot que d'ecraser la source avec des champs vides.
  Future<void> preferRemoteProject(String id) async {
    await _db.update('projects', {'sync_state': 'synced', 'updated_at': '1970-01-01T00:00:00.000Z'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProject(String id) async {
    for (final table in ['messages', 'connections', 'workflows', 'webhooks', 'actions', 'executions', 'logs']) {
      await _db.delete(table, where: 'project_id = ?', whereArgs: [id]);
    }
    await _db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getMessages(String projectId) async {
    return await _db.query('messages', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'created_at ASC');
  }

  Future<Map<String, dynamic>> sendMessage(
    String projectId,
    String content, {
    String sender = 'user',
    String senderId = '',
    String senderName = '',
    String senderPhoto = '',
    String replyTo = '',
    String? explicitId,
  }) async {
    final id = (explicitId != null && explicitId.isNotEmpty) ? explicitId : _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final msg = {
      'id': id,
      'project_id': projectId,
      'content': content,
      'sender': sender,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_photo': senderPhoto,
      'reply_to': replyTo,
      'is_bot': sender == 'bot' ? 1 : 0,
      'created_at': now,
      'updated_at': now,
      'sync_state': 'dirty',
    };
    await _db.insert('messages', msg);
    await _db.update('projects', {'updated_at': now, 'sync_state': 'dirty'}, where: 'id = ?', whereArgs: [projectId]);
    return msg;
  }

  Future<void> deleteMessage(String messageId) async {
    final rows = await _db.query('messages', where: 'id = ?', whereArgs: [messageId]);
    final projectId = rows.isNotEmpty ? '${rows.first['project_id'] ?? ''}' : '';
    await _db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    await _tombstone(projectId, 'message', messageId);
  }

  /// Une suppression locale ne suffit pas : les autres appareils ont deja
  /// tire la ligne et la re-ferraient apparaitre au prochain cycle. On note
  /// la suppression (tombstone) pour la diffuser avec la synchro.
  Future<void> _tombstone(String projectId, String kind, String id) async {
    if (id.isEmpty || projectId.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.delete('tombstones', where: 'id = ?', whereArgs: [id]);
    await _db.insert('tombstones', {
      'id': id,
      'project_id': projectId,
      'kind': kind,
      'deleted_at': now,
      'updated_at': now,
      'sync_state': 'dirty',
    });
  }


  Future<List<Map<String, dynamic>>> getConnections(String projectId) async {
    return await _db.query('connections', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createConnection(String projectId, String name, String url, String apiKey) async {
    final id = _uuid.v4();
    final conn = {'id': id, 'project_id': projectId, 'name': name, 'url': url, 'api_key': apiKey, 'status': 'connected', 'created_at': DateTime.now().toUtc().toIso8601String()};
    await _db.insert('connections', conn);
    return conn;
  }

  Future<void> deleteConnection(String projectId, String connectionId) async {
    await _db.delete('connections', where: 'id = ?', whereArgs: [connectionId]);
  }

  Future<List<Map<String, dynamic>>> getWorkflows(String projectId) async {
    return await _db.query('workflows', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createWorkflow(String projectId, String name, String description) async {
    final id = _uuid.v4();
    final wf = {'id': id, 'project_id': projectId, 'name': name, 'description': description, 'status': 'active', 'created_at': DateTime.now().toUtc().toIso8601String()};
    await _db.insert('workflows', wf);
    return wf;
  }

  Future<void> deleteWorkflow(String projectId, String workflowId) async {
    await _db.delete('workflows', where: 'id = ?', whereArgs: [workflowId]);
  }

  Future<List<Map<String, dynamic>>> getWebhooks(String projectId) async {
    return await _db.query('webhooks', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createWebhook(String projectId, String name, String url, List<String> events) async {
    final id = _uuid.v4();
    final wh = {'id': id, 'project_id': projectId, 'name': name, 'url': url, 'events': jsonEncode(events), 'is_active': 1, 'created_at': DateTime.now().toUtc().toIso8601String()};
    await _db.insert('webhooks', wh);
    return wh;
  }

  Future<void> deleteWebhook(String projectId, String webhookId) async {
    await _db.delete('webhooks', where: 'id = ?', whereArgs: [webhookId]);
  }

  Future<void> updateWebhook(String webhookId, Map<String, dynamic> updates) async {
    await _db.update('webhooks', updates, where: 'id = ?', whereArgs: [webhookId]);
  }

  Future<void> updateWorkflow(String workflowId, Map<String, dynamic> updates) async {
    await _db.update('workflows', updates, where: 'id = ?', whereArgs: [workflowId]);
  }

  Future<void> updateConnection(String connectionId, Map<String, dynamic> updates) async {
    await _db.update('connections', updates, where: 'id = ?', whereArgs: [connectionId]);
  }

  Future<Map<String, dynamic>> addExecution(String projectId, String name, String status, {String? duration}) async {
    final id = _uuid.v4();
    final exec = {
      'id': id, 'project_id': projectId, 'name': name, 'status': status,
      'duration': duration ?? '', 'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _db.insert('executions', exec);
    return exec;
  }

  Future<List<Map<String, dynamic>>> getActions(String projectId) async {
    return await _db.query('actions', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createAction(String projectId, String name, String method, String endpoint) async {
    final id = _uuid.v4();
    final action = {'id': id, 'project_id': projectId, 'name': name, 'method': method, 'endpoint': endpoint, 'created_at': DateTime.now().toUtc().toIso8601String()};
    await _db.insert('actions', action);
    return action;
  }

  Future<void> deleteAction(String projectId, String actionId) async {
    await _db.delete('actions', where: 'id = ?', whereArgs: [actionId]);
  }

  Future<List<Map<String, dynamic>>> getExecutions(String projectId) async {
    return await _db.query('executions', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getLogs(String projectId) async {
    return await _db.query('logs', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'created_at DESC');
  }

  Future<void> addLog(String projectId, String level, String message, {String? details}) async {
    await _db.insert('logs', {
      'id': _uuid.v4(), 'project_id': projectId, 'level': level, 'message': message,
      'details': details, 'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getMembers(String organizationId, {String? projectId}) async {
    if (projectId != null) {
      return await _db.query('members', where: 'organization_id = ? AND project_id = ?', whereArgs: [organizationId, projectId]);
    }
    return await _db.query('members', where: 'organization_id = ?', whereArgs: [organizationId]);
  }

  Future<List<Map<String, dynamic>>> getMembersByProject(String projectId) async {
    return await _db.query('members', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> addMember(String organizationId, String name, String email, String role, {String? projectId, String? photo}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final member = {
      'id': id,
      'organization_id': organizationId,
      'project_id': projectId ?? '',
      'name': name,
      'email': email,
      'role': role,
      'photo': photo ?? '',
      'sync_state': 'dirty',
      'created_at': now,
      'updated_at': now,
    };
    await _db.insert('members', member);
    return member;
  }

  Future<void> updateMember(String memberId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    updates['sync_state'] = 'dirty';
    await _db.update('members', updates, where: 'id = ?', whereArgs: [memberId]);
  }

  /// Vrai si cette ligne a ete supprimee par l'un des appareils : empeche
  /// de recreer un message de bienvenue (ou tout autre contenu) supprime.
  Future<bool> isTombstoned(String projectId, String id) async {
    if (id.isEmpty) return false;
    final rows = await _db.query('tombstones', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  /// Role de l'appareil courant sur un projet.
  ///
  /// Source unique de verite pour toute ecriture dans les tables backend :
  /// '' signifie "identite non resolue" et doit etre traite comme interdit.
  Future<String> resolveRole(String projectId) async {
    final members = await getMembersByProject(projectId);
    // Projet local sans aucun membre enregistre : son createur est le seul
    // participant, il est admin.
    if (members.isEmpty) return 'admin';

    Map<String, dynamic>? me;
    try {
      final prefs = await SharedPreferences.getInstance();
      final known = prefs.getString('member_id_$projectId') ?? '';
      if (known.isNotEmpty) {
        final hit = members.firstWhere((m) => (m['id'] as String?) == known, orElse: () => <String, dynamic>{});
        if (hit.isNotEmpty) me = hit;
      }
    } catch (_) {}

    if (me == null) {
      final profile = await UserProfile.load();
      final email = (profile['email'] ?? '').trim().toLowerCase();
      final name = (profile['name'] ?? '').trim().toLowerCase();
      if (email.isNotEmpty) {
        final hit = members.firstWhere((m) => ((m['email'] as String?) ?? '').trim().toLowerCase() == email, orElse: () => <String, dynamic>{});
        if (hit.isNotEmpty) me = hit;
      }
      if (me == null && name.isNotEmpty) {
        final hit = members.firstWhere((m) => ((m['name'] as String?) ?? '').trim().toLowerCase() == name, orElse: () => <String, dynamic>{});
        if (hit.isNotEmpty) me = hit;
      }
      if (me == null && members.length == 1) me = members.first;
    }

    return (me?['role'] as String?) ?? '';
  }

  Future<void> removeMember(String organizationId, String memberId) async {
    final rows = await _db.query('members', where: 'id = ?', whereArgs: [memberId]);
    final projectId = rows.isNotEmpty ? '${rows.first['project_id'] ?? ''}' : '';
    await _db.delete('members', where: 'id = ?', whereArgs: [memberId]);
    await _tombstone(projectId, 'member', memberId);
  }

  /// Cree uniquement l'organisation par defaut et le compte admin.
  /// Aucun projet, aucune connexion et aucun message de demo :
  /// l'utilisateur connecte lui-meme son propre backend.
  Future<void> seedData() async {
    final orgs = await _db.query('organizations');
    if (orgs.isNotEmpty) return;

    final orgId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('organizations', {
      'id': orgId,
      'name': 'Mon Espace',
      'description': 'Espace de travail principal',
      'created_at': now,
      'updated_at': now,
    });
    await _db.insert('members', {
      'id': _uuid.v4(),
      'organization_id': orgId,
      'project_id': '',
      'name': 'Admin',
      'email': 'admin@prone.app',
      'role': 'admin',
      'created_at': now,
    });
  }

  Future<void> updateProjectStatus(String projectId, String status, {String? statusType}) async {
    await _db.update('projects', {
      'status': status,
      'status_type': statusType ?? 'info',
      'status_updated_at': DateTime.now().toUtc().toIso8601String(),
      'sync_state': 'dirty',
    }, where: 'id = ?', whereArgs: [projectId]);
  }
}
