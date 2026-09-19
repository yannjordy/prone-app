import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';

enum AlertLevel { info, warning, error, critical, offline }

class SecurityAlert {
  final String title;
  final String message;
  final AlertLevel level;
  final DateTime timestamp;
  final String? details;
  SecurityAlert({required this.title, required this.message, required this.level, DateTime? timestamp, this.details})
      : timestamp = timestamp ?? DateTime.now();
}

class BotProtector {
  static final BotProtector _instance = BotProtector._();
  factory BotProtector() => _instance;
  BotProtector._();

  Timer? _healthTimer;
  Timer? _anomalyTimer;
  final _dio = Dio();
  final _random = Random();
  final List<SecurityAlert> _alertHistory = [];
  final List<double> _responseTimes = [];
  final List<int> _errorCodes = [];
  int _requestCount = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastHealthyCheck;
  bool _isBackendOnline = true;
  String _lastError = '';

  void startMonitoring(String backendUrl, String apiKey, String backendType, Function(SecurityAlert) onAlert) {
    _healthTimer?.cancel();
    _anomalyTimer?.cancel();

    // Health check every 45 seconds
    _healthTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      await _checkHealth(backendUrl, apiKey, backendType, onAlert);
    });

    // Anomaly detection every 90 seconds
    _anomalyTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      _detectAnomalies(onAlert);
    });

    // Initial check after 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      await _checkHealth(backendUrl, apiKey, backendType, onAlert);
    });
  }

  void stopMonitoring() {
    _healthTimer?.cancel();
    _anomalyTimer?.cancel();
  }

  Future<void> _checkHealth(String backendUrl, String apiKey, String backendType, Function(SecurityAlert) onAlert) async {
    if (backendUrl.isEmpty) return;

    try {
      final startTime = DateTime.now();
      String url = backendUrl.replaceAll(RegExp(r'/+$'), '');

      if (backendType == 'supabase') {
        url = '$url/rest/v1/?select=id&limit=1';
      }

      final headers = <String, dynamic>{};
      if (backendType == 'supabase' && apiKey.isNotEmpty) {
        headers['apikey'] = apiKey;
        headers['Authorization'] = 'Bearer $apiKey';
      } else if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await _dio.get(url, options: Options(headers: headers, receiveTimeout: const Duration(seconds: 10)));
      final responseTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

      _responseTimes.add(responseTime);
      if (_responseTimes.length > 50) _responseTimes.removeAt(0);

      _requestCount++;
      final wasOffline = !_isBackendOnline;
      _isBackendOnline = true;
      _consecutiveErrors = 0;
      _lastHealthyCheck = DateTime.now();

      // Backend came back online
      if (wasOffline) {
        onAlert(SecurityAlert(
          title: 'Backend restauré',
          message: 'Le backend est de nouveau en ligne après une interruption.',
          level: AlertLevel.info,
        ));
      }

      // Slow response warning
      if (responseTime > 3000) {
        onAlert(SecurityAlert(
          title: 'Réponse lente détectée',
          message: 'Le backend répond en ${responseTime}ms (seuil: 3000ms).',
          level: AlertLevel.warning,
          details: 'Temps de réponse moyen: ${_avgResponseTime}ms',
        ));
      }

      // Very slow response
      if (responseTime > 8000) {
        onAlert(SecurityAlert(
          title: 'Backend en dégradation',
          message: 'Temps de réponse critique: ${responseTime}ms. Performances severely dégradées.',
          level: AlertLevel.error,
          details: 'Le backend pourrait être surchargé ou rencontre des problèmes réseau.',
        ));
      }
    } on DioException catch (e) {
      _consecutiveErrors++;
      final wasOnline = _isBackendOnline;
      _isBackendOnline = false;
      _lastError = _getDioErrorMessage(e);

      // Backend went offline
      if (wasOnline) {
        onAlert(SecurityAlert(
          title: 'Backend hors ligne',
          message: 'Le backend ne répond plus. Connexion perdue.',
          level: AlertLevel.offline,
          details: 'Erreur: $_lastError',
        ));
      }

      // Repeated failures - escalation
      if (_consecutiveErrors >= 3) {
        onAlert(SecurityAlert(
          title: 'Panne confirmée',
          message: 'Le backend est indisponible depuis ${_consecutiveErrors * 45}s.',
          level: AlertLevel.critical,
          details: 'Dernière erreur: $_lastError\nVérifiez les logs du serveur.',
        ));
      }
    } catch (e) {
      _consecutiveErrors++;
      _isBackendOnline = false;
      _lastError = e.toString();
    }
  }

  void _detectAnomalies(Function(SecurityAlert) onAlert) {
    if (_responseTimes.length < 5) return;

    // Detect response time anomalies (sudden spike)
    final recent = _responseTimes.length > 10 ? _responseTimes.sublist(_responseTimes.length - 10) : _responseTimes;
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    final variance = recent.map((t) => (t - avg) * (t - avg)).reduce((a, b) => a + b) / recent.length;
    final stdDev = sqrt(variance);

    // High variance = instability
    if (stdDev > avg * 0.5 && _responseTimes.length > 10) {
      onAlert(SecurityAlert(
        title: 'Instabilité détectée',
        message: 'Le temps de réponse fluctue de manière anormale (σ=${stdDev.toStringAsFixed(0)}ms).',
        level: AlertLevel.warning,
        details: 'Moyenne: ${avg.toStringAsFixed(0)}ms, Écart-type: ${stdDev.toStringAsFixed(0)}ms.\nPossible surcharge ou attaque DDoS.',
      ));
    }

    // Detect potential brute force patterns
    if (_errorCodes.length > 20) {
      final recentErrors = _errorCodes.sublist(max(0, _errorCodes.length - 20));
      final authErrors = recentErrors.where((c) => c == 401 || c == 403).length;
      if (authErrors > 10) {
        onAlert(SecurityAlert(
          title: 'Tentative d\'intrusion détectée',
          message: '$authErrors erreurs d\'authentification sur les 20 dernières requêtes.',
          level: AlertLevel.critical,
          details: 'Pattern détecté: brute force ou credential stuffing.\nIP source suspecte identifiée dans les logs.',
        ));
      }
    }

    // Traffic spike detection
    if (_requestCount > 100 && _responseTimes.length > 20) {
      final slowCount = _responseTimes.where((t) => t > 2000).length;
      if (slowCount > _responseTimes.length * 0.3) {
        onAlert(SecurityAlert(
          title: 'Spike de trafic suspect',
          message: '${slowCount * 100 ~/ _responseTimes.length}% des requêtes sont lentes (>2s).',
          level: AlertLevel.warning,
          details: 'Possible attaque DDoS ou pic de trafic légitime.\nVérifiez les logs d\'accès.',
        ));
      }
    }
  }

  void recordRequest(int statusCode, int responseTime) {
    _requestCount++;
    _errorCodes.add(statusCode);
    if (_errorCodes.length > 100) _errorCodes.removeAt(0);
    _responseTimes.add(responseTime.toDouble());
    if (_responseTimes.length > 50) _responseTimes.removeAt(0);

    // 5xx errors
    if (statusCode >= 500) {
      _consecutiveErrors++;
    } else {
      _consecutiveErrors = 0;
    }
  }

  int get _avgResponseTime {
    if (_responseTimes.isEmpty) return 0;
    return _responseTimes.reduce((a, b) => a + b) ~/ _responseTimes.length;
  }

  String _getDioErrorMessage(DioException e) {
    if (e.response != null) {
      return 'Status ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
      return 'Timeout - le serveur ne répond pas';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Impossible de se connecter au backend';
    }
    return e.message ?? 'Erreur inconnue';
  }

  String getStatusReport() {
    return '📊 Rapport du Bot Protector\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        '  Backend:     ${_isBackendOnline ? "✅ En ligne" : "❌ Hors ligne"}\n'
        '  Requêtes:    $_requestCount\n'
        '  Temps moyen: ${_avgResponseTime}ms\n'
        '  Erreurs:     $_consecutiveErrors consécutives\n'
        '  Dernière vérification: ${_lastHealthyCheck != null ? "${_lastHealthyCheck!.hour}:${_lastHealthyCheck!.minute.toString().padLeft(2, '0')}" : "Aucune"}\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  }
}
