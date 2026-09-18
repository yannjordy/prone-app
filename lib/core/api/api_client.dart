import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  
  late final Dio _dio;
  String? _token;
  String? _refreshToken;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8080/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            error.requestOptions.headers['Authorization'] = 'Bearer $_token';
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final response = await _dio.post('/auth/refresh', data: {'refreshToken': _refreshToken});
      final data = response.data;
      _token = data['accessToken'];
      _refreshToken = data['refreshToken'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('refresh_token', _refreshToken!);
      return true;
    } catch (e) {
      _token = null;
      _refreshToken = null;
      return false;
    }
  }

  void setTokens(String token, String refreshToken) {
    _token = token;
    _refreshToken = refreshToken;
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  // ======================== AUTH ========================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = response.data;
    setTokens(data['accessToken'], data['refreshToken']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['accessToken']);
    await prefs.setString('refresh_token', data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
    return response.data;
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  // ======================== ORGANIZATIONS ========================
  Future<List<dynamic>> getOrganizations() async {
    final response = await _dio.get('/organizations');
    return response.data;
  }

  Future<Map<String, dynamic>> getOrganization(String id) async {
    final response = await _dio.get('/organizations/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createOrganization(String name, String description) async {
    final response = await _dio.post('/organizations', data: {'name': name, 'description': description});
    return response.data;
  }

  Future<Map<String, dynamic>> updateOrganization(String id, String name, String description) async {
    final response = await _dio.put('/organizations/$id', data: {'name': name, 'description': description});
    return response.data;
  }

  Future<void> deleteOrganization(String id) async {
    await _dio.delete('/organizations/$id');
  }

  // ======================== PROJECTS ========================
  Future<List<dynamic>> getProjects(String organizationId) async {
    final response = await _dio.get('/organizations/$organizationId/projects');
    return response.data;
  }

  Future<Map<String, dynamic>> getProject(String id) async {
    final response = await _dio.get('/projects/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createProject(String organizationId, String name, String description) async {
    final response = await _dio.post('/organizations/$organizationId/projects', data: {'name': name, 'description': description});
    return response.data;
  }

  Future<Map<String, dynamic>> updateProject(String id, String name, String description) async {
    final response = await _dio.put('/projects/$id', data: {'name': name, 'description': description});
    return response.data;
  }

  Future<void> deleteProject(String id) async {
    await _dio.delete('/projects/$id');
  }

  // ======================== MEMBERS ========================
  Future<List<dynamic>> getMembers(String organizationId) async {
    final response = await _dio.get('/organizations/$organizationId/members');
    return response.data;
  }

  Future<Map<String, dynamic>> inviteMember(String organizationId, String userId, String role) async {
    final response = await _dio.post('/organizations/$organizationId/members', data: {'userId': userId, 'role': role});
    return response.data;
  }

  Future<Map<String, dynamic>> updateMemberRole(String organizationId, String userId, String role) async {
    final response = await _dio.put('/organizations/$organizationId/members/$userId/role', data: {'role': role});
    return response.data;
  }

  Future<void> removeMember(String organizationId, String userId) async {
    await _dio.delete('/organizations/$organizationId/members/$userId');
  }

  // ======================== API KEYS ========================
  Future<List<dynamic>> getApiKeys(String projectId) async {
    final response = await _dio.get('/projects/$projectId/api-keys');
    return response.data;
  }

  Future<Map<String, dynamic>> createApiKey(String projectId, String name) async {
    final response = await _dio.post('/projects/$projectId/api-keys', data: {'name': name});
    return response.data;
  }

  Future<void> revokeApiKey(String projectId, String keyId) async {
    await _dio.delete('/projects/$projectId/api-keys/$keyId');
  }

  // ======================== CONNECTIONS ========================
  Future<List<dynamic>> getConnections(String projectId) async {
    final response = await _dio.get('/projects/$projectId/connections');
    return response.data;
  }

  Future<Map<String, dynamic>> createConnection(String projectId, String name, String url, String apiKey) async {
    final response = await _dio.post('/projects/$projectId/connections', data: {'name': name, 'url': url, 'apiKey': apiKey});
    return response.data;
  }

  Future<void> deleteConnection(String projectId, String connectionId) async {
    await _dio.delete('/projects/$projectId/connections/$connectionId');
  }

  Future<Map<String, dynamic>> testConnection(String projectId, String connectionId) async {
    final response = await _dio.post('/projects/$projectId/connections/$connectionId/test');
    return response.data;
  }

  // ======================== WORKFLOWS ========================
  Future<List<dynamic>> getWorkflows(String projectId) async {
    final response = await _dio.get('/projects/$projectId/workflows');
    return response.data;
  }

  Future<Map<String, dynamic>> createWorkflow(String projectId, String name, String description) async {
    final response = await _dio.post('/projects/$projectId/workflows', data: {'name': name, 'description': description});
    return response.data;
  }

  Future<void> deleteWorkflow(String projectId, String workflowId) async {
    await _dio.delete('/projects/$projectId/workflows/$workflowId');
  }

  Future<Map<String, dynamic>> runWorkflow(String projectId, String workflowId) async {
    final response = await _dio.post('/projects/$projectId/workflows/$workflowId/run');
    return response.data;
  }

  // ======================== WEBHOOKS ========================
  Future<List<dynamic>> getWebhooks(String projectId) async {
    final response = await _dio.get('/projects/$projectId/webhooks');
    return response.data;
  }

  Future<Map<String, dynamic>> createWebhook(String projectId, String name, String url, List<String> events) async {
    final response = await _dio.post('/projects/$projectId/webhooks', data: {'name': name, 'url': url, 'events': events});
    return response.data;
  }

  Future<void> deleteWebhook(String projectId, String webhookId) async {
    await _dio.delete('/projects/$projectId/webhooks/$webhookId');
  }

  // ======================== EXECUTIONS ========================
  Future<List<dynamic>> getExecutions(String projectId) async {
    final response = await _dio.get('/projects/$projectId/executions');
    return response.data;
  }

  // ======================== LOGS ========================
  Future<List<dynamic>> getLogs(String projectId) async {
    final response = await _dio.get('/projects/$projectId/logs');
    return response.data;
  }

  // ======================== MONITORING ========================
  Future<Map<String, dynamic>> getMonitoring(String projectId) async {
    final response = await _dio.get('/projects/$projectId/monitoring');
    return response.data;
  }

  // ======================== CHAT ========================
  Future<List<dynamic>> getMessages(String projectId) async {
    final response = await _dio.get('/projects/$projectId/messages');
    return response.data;
  }

  Future<Map<String, dynamic>> sendMessage(String projectId, String content) async {
    final response = await _dio.post('/projects/$projectId/messages', data: {'content': content});
    return response.data;
  }

  // ======================== HEALTH ========================
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }
}
