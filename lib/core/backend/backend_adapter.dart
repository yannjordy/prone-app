import 'dart:convert';
import 'package:dio/dio.dart';

enum BackendType { supabase, firebase, node, python, java, express, nextjs, nestjs, fastapi, django, flask, generic }

class BackendAdapter {
  final String url;
  final String apiKey;
  final BackendType type;

  BackendAdapter._({required this.url, required this.apiKey, required this.type});

  static BackendType detect(String url, String? forcedType) {
    if (forcedType != null && forcedType.isNotEmpty) {
      return BackendType.values.firstWhere((e) => e.name == forcedType, orElse: () => BackendType.generic);
    }
    final lower = url.toLowerCase();
    if (lower.contains('supabase')) return BackendType.supabase;
    if (lower.contains('firebase') || lower.contains('firestore')) return BackendType.firebase;
    if (lower.contains('vercel.app') || lower.contains('next')) return BackendType.nextjs;
    if (lower.contains('herokuapp') || lower.contains('render.com') || lower.contains('railway.app')) return BackendType.node;
    return BackendType.generic;
  }

  static Future<BackendAdapter> create(String url, String apiKey, {String? type}) async {
    final detected = detect(url, type);
    return BackendAdapter._(url: url, apiKey: apiKey, type: detected);
  }

  String get healthUrl {
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    switch (type) {
      case BackendType.supabase:
        return '$clean/rest/v1/?limit=1';
      case BackendType.firebase:
        return clean;
      default:
        return clean;
    }
  }

  Map<String, String> get headers {
    final h = <String, String>{};
    if (apiKey.isEmpty) return h;

    switch (type) {
      case BackendType.supabase:
        h['apikey'] = apiKey;
        h['Authorization'] = 'Bearer $apiKey';
        h['Content-Type'] = 'application/json';
        break;
      case BackendType.firebase:
        h['Authorization'] = 'Bearer $apiKey';
        break;
      default:
        h['Authorization'] = 'Bearer $apiKey';
        h['Content-Type'] = 'application/json';
        break;
    }
    return h;
  }

  String get typeName {
    switch (type) {
      case BackendType.supabase: return 'Supabase';
      case BackendType.firebase: return 'Firebase';
      case BackendType.node: return 'Node.js';
      case BackendType.python: return 'Python';
      case BackendType.java: return 'Java';
      case BackendType.express: return 'Express.js';
      case BackendType.nextjs: return 'Next.js';
      case BackendType.nestjs: return 'NestJS';
      case BackendType.fastapi: return 'FastAPI';
      case BackendType.django: return 'Django';
      case BackendType.flask: return 'Flask';
      case BackendType.generic: return 'API';
    }
  }

  static final _dio = Dio();

  static Future<BackendCheckResult> check(String url, String apiKey, {String? type}) async {
    try {
      final adapter = await BackendAdapter.create(url, apiKey, type: type);
      final startTime = DateTime.now();
      final resp = await _dio.get(
        adapter.healthUrl,
        options: Options(
          headers: adapter.headers,
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final ms = DateTime.now().difference(startTime).inMilliseconds;

      String? faviconUrl;
      try {
        final clean = url.replaceAll(RegExp(r'/+$'), '');
        final faviconResp = await _dio.get('\$clean/favicon.ico',
          options: Options(receiveTimeout: const Duration(seconds: 3), validateStatus: (s) => s != null && s < 400, responseType: ResponseType.bytes),
        );
        if (faviconResp.statusCode == 200 && faviconResp.data != null) {
          faviconUrl = '\$clean/favicon.ico';
        }
      } catch (_) {
        try {
          final clean = url.replaceAll(RegExp(r'/+$'), '');
          final altResp = await _dio.get('\$clean/favicon.png',
            options: Options(receiveTimeout: const Duration(seconds: 3), validateStatus: (s) => s != null && s < 400),
          );
          if (altResp.statusCode == 200) {
            faviconUrl = '\$clean/favicon.png';
          }
        } catch (_) {}
      }

      return BackendCheckResult(
        online: true,
        statusCode: resp.statusCode ?? 0,
        responseTime: ms,
        type: adapter.typeName,
        message: '✅ ${adapter.typeName} connecté!\n\nURL: $url\nType: ${adapter.typeName}\nStatus: ${resp.statusCode}\nTemps: ${ms}ms\n\nLe backend est opérationnel.',
        faviconUrl: faviconUrl,
      );
    } on DioException catch (e) {
      return BackendCheckResult(
        online: false,
        statusCode: 0,
        responseTime: 0,
        type: BackendAdapter.detect(url, type).name,
        message: '❌ Backend inaccessible\n\nURL: $url\nErreur: ${_humanError(e)}\n\nVérifiez l\'URL et la connexion.',
      );
    }
  }

  static String _humanError(DioException e) {
    if (e.response != null) return 'Status ${e.response?.statusCode}';
    if (e.type == DioExceptionType.connectionTimeout) return 'Timeout - le serveur ne répond pas';
    if (e.type == DioExceptionType.connectionError) return 'Impossible de se connecter';
    if (e.type == DioExceptionType.badCertificate) return 'Certificat SSL invalide';
    return e.message ?? 'Erreur inconnue';
  }

  static Future<List<String>> listTables(String url, String apiKey, {String? type}) async {
    final adapter = await BackendAdapter.create(url, apiKey, type: type);
    if (adapter.type == BackendType.supabase) {
      return _supabaseTables(url, apiKey);
    }
    // For other backends, try common REST endpoints
    return _probeEndpoints(url, apiKey);
  }

  static Future<List<String>> _supabaseTables(String url, String apiKey) async {
    try {
      final dio = Dio();
      final commonTables = [
        'users', 'profiles', 'products', 'orders', 'categories', 'messages',
        'produits', 'commandes', 'clients', 'produits', 'categories',
        'settings', 'config', 'logs', 'sessions', 'tokens',
      ];
      final found = <String>[];
      for (final table in commonTables) {
        try {
          final resp = await dio.get(
            '$url/rest/v1/$table?select=id&limit=1',
            options: Options(headers: {
              'apikey': apiKey,
              'Authorization': 'Bearer $apiKey',
            }, receiveTimeout: const Duration(seconds: 5)),
          );
          if (resp.statusCode == 200) found.add(table);
        } catch (_) {}
      }
      return found;
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> _probeEndpoints(String url, String apiKey) async {
    final dio = Dio();
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    final endpoints = ['/', '/api', '/health', '/status', '/docs', '/api/health', '/api/status'];
    final found = <String>[];
    final headers = <String, String>{};
    if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';

    for (final ep in endpoints) {
      try {
        final resp = await dio.get(
          '$clean$ep',
          options: Options(headers: headers, receiveTimeout: const Duration(seconds: 5), validateStatus: (s) => s != null && s < 500),
        );
        if (resp.statusCode == 200) found.add(ep);
      } catch (_) {}
    }
    return found;
  }
}

class BackendCheckResult {
  final bool online;
  final int statusCode;
  final int responseTime;
  final String type;
  final String message;
  final String? faviconUrl;
  BackendCheckResult({required this.online, required this.statusCode, required this.responseTime, required this.type, required this.message, this.faviconUrl});
}
