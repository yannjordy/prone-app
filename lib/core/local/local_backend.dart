import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

class LocalBackend {
  static final LocalBackend _instance = LocalBackend._();
  factory LocalBackend() => _instance;
  LocalBackend._();

  final _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> getOrganizations() async {
    return await _db.query('organizations', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>> createOrganization(String name, String description) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final org = {'id': id, 'name': name, 'description': description, 'created_at': now, 'updated_at': now};
    await _db.insert('organizations', org);
    return org;
  }

  Future<void> deleteOrganization(String id) async {
    await _db.delete('organizations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    return await _db.query('projects', orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>> createProject(String name, String description, {String? apiKey, String? backendUrl}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final project = {
      'id': id, 'name': name, 'description': description,
      'api_key': apiKey ?? '', 'backend_url': backendUrl ?? '',
      'is_pinned': 0, 'is_archived': 0, 'is_muted': 0,
      'created_at': now, 'updated_at': now,
    };
    await _db.insert('projects', project);
    return project;
  }

  Future<void> updateProject(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _db.update('projects', updates, where: 'id = ?', whereArgs: [id]);
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

  Future<Map<String, dynamic>> sendMessage(String projectId, String content, {String sender = 'user'}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final msg = {'id': id, 'project_id': projectId, 'content': content, 'sender': sender, 'is_bot': sender == 'bot' ? 1 : 0, 'created_at': now};
    await _db.insert('messages', msg);

    if (sender == 'user') {
      final botReply = _generateBotReply(content);
      await _db.insert('messages', {'id': _uuid.v4(), 'project_id': projectId, 'content': botReply, 'sender': 'bot', 'is_bot': 1, 'created_at': DateTime.now().toIso8601String()});
      await _db.update('projects', {'updated_at': now}, where: 'id = ?', whereArgs: [projectId]);
    }
    return msg;
  }

  String _generateBotReply(String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('health') || lower.contains('status')) {
      return '✅ Backend status: All systems operational.\n• API: Online (200 OK)\n• Database: Connected\n• Uptime: 99.98%';
    } else if (lower.contains('deploy') || lower.contains('deployer')) {
      return '🚀 Deployment initiated...\n• Building project...\n• Running tests...\n• Deploying to production...\n✅ Deployment successful!';
    } else if (lower.contains('log') || lower.contains('erreur') || lower.contains('error')) {
      return '📋 Recent logs:\n• [INFO] Request handled - 200 OK\n• [WARN] Slow query detected (1.2s)\n• [INFO] Cache hit ratio: 94%\nNo critical errors found.';
    } else if (lower.contains('endpoint') || lower.contains('route')) {
      return '🔗 Active endpoints:\n• GET /api/products\n• POST /api/orders\n• GET /api/users\n• PUT /api/inventory\n\nTotal: 12 endpoints';
    } else if (lower.contains('test')) {
      return '🧪 Running test suite...\n• Unit tests: 45/45 passed\n• Integration tests: 12/12 passed\n• Coverage: 87%\n✅ All tests passed!';
    } else if (lower.contains('help') || lower.contains('aide')) {
      return '🤖 Available commands:\n• "health" - Check backend status\n• "deploy" - Deploy your app\n• "logs" - View recent logs\n• "endpoints" - List API routes\n• "test" - Run test suite\n• "stats" - View statistics';
    } else if (lower.contains('stat') || lower.contains('metric')) {
      return '📊 Statistics (last 24h):\n• Requests: 12,847\n• Avg response: 124ms\n• Error rate: 0.02%\n• Active users: 234';
    } else {
      return '🤖 Command received: "$userMessage"\n\nI can help you manage your backend. Try:\n• "health" - Check status\n• "deploy" - Deploy\n• "logs" - View logs\n• "help" - All commands';
    }
  }

  Future<List<Map<String, dynamic>>> getConnections(String projectId) async {
    return await _db.query('connections', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createConnection(String projectId, String name, String url, String apiKey) async {
    final id = _uuid.v4();
    final conn = {'id': id, 'project_id': projectId, 'name': name, 'url': url, 'api_key': apiKey, 'status': 'connected', 'created_at': DateTime.now().toIso8601String()};
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
    final wf = {'id': id, 'project_id': projectId, 'name': name, 'description': description, 'status': 'active', 'created_at': DateTime.now().toIso8601String()};
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
    final wh = {'id': id, 'project_id': projectId, 'name': name, 'url': url, 'events': jsonEncode(events), 'is_active': 1, 'created_at': DateTime.now().toIso8601String()};
    await _db.insert('webhooks', wh);
    return wh;
  }

  Future<void> deleteWebhook(String projectId, String webhookId) async {
    await _db.delete('webhooks', where: 'id = ?', whereArgs: [webhookId]);
  }

  Future<List<Map<String, dynamic>>> getActions(String projectId) async {
    return await _db.query('actions', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<Map<String, dynamic>> createAction(String projectId, String name, String method, String endpoint) async {
    final id = _uuid.v4();
    final action = {'id': id, 'project_id': projectId, 'name': name, 'method': method, 'endpoint': endpoint, 'created_at': DateTime.now().toIso8601String()};
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
      'details': details, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getMembers(String organizationId) async {
    return await _db.query('members', where: 'organization_id = ?', whereArgs: [organizationId]);
  }

  Future<Map<String, dynamic>> addMember(String organizationId, String name, String email, String role) async {
    final id = _uuid.v4();
    final member = {'id': id, 'organization_id': organizationId, 'name': name, 'email': email, 'role': role, 'created_at': DateTime.now().toIso8601String()};
    await _db.insert('members', member);
    return member;
  }

  Future<void> removeMember(String organizationId, String memberId) async {
    await _db.delete('members', where: 'id = ?', whereArgs: [memberId]);
  }

  Future<void> seedData() async {
    final existing = await _db.query('projects');
    if (existing.isNotEmpty) return;

    final orgId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _db.insert('organizations', {'id': orgId, 'name': 'Mon Espace', 'description': 'Espace de travail principal', 'created_at': now, 'updated_at': now});

    final projects = [
      {'name': 'ODA Market', 'desc': 'Backend API pour ODA Market - E-commerce', 'key': 'oda-market-key-2024', 'url': 'https://oda-markets.vercel.app'},
      {'name': 'ODA Seller', 'desc': 'Backend API pour ODA Seller - Gestion vendeurs', 'key': 'oda-seller-key-2024', 'url': 'https://oda-markets.vercel.app/seller'},
      {'name': 'WhatsApp Bot', 'desc': 'Bot WhatsApp pour notifications', 'key': 'whatsapp-bot-key', 'url': 'https://api.whatsapp.com/v1'},
    ];

    for (final p in projects) {
      final projId = _uuid.v4();
      await _db.insert('projects', {
        'id': projId, 'organization_id': orgId, 'name': p['name'], 'description': p['desc'],
        'api_key': p['key'], 'backend_url': p['url'],
        'is_pinned': 0, 'is_archived': 0, 'is_muted': 0,
        'created_at': now, 'updated_at': now,
      });
      await _db.insert('messages', {'id': _uuid.v4(), 'project_id': projId, 'content': 'Backend connecte avec succes', 'sender': 'bot', 'is_bot': 1, 'created_at': now});
      await _db.insert('messages', {'id': _uuid.v4(), 'project_id': projId, 'content': 'health', 'sender': 'user', 'is_bot': 0, 'created_at': now});
      await _db.insert('messages', {'id': _uuid.v4(), 'project_id': projId, 'content': '✅ Backend status: All systems operational.\n• API: Online (200 OK)\n• Database: Connected\n• Uptime: 99.98%', 'sender': 'bot', 'is_bot': 1, 'created_at': now});
      await _db.insert('connections', {'id': _uuid.v4(), 'project_id': projId, 'name': 'Production', 'url': p['url']!, 'api_key': p['key'], 'status': 'connected', 'created_at': now});
    }

    await _db.insert('members', {'id': _uuid.v4(), 'organization_id': orgId, 'name': 'Admin', 'email': 'admin@prone.app', 'role': 'admin', 'created_at': now});
  }
}
