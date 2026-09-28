import 'package:dio/dio.dart';
import 'request_log.dart';

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
    BackendAdapter? adapter;
    String healthTarget = url;
    try {
      adapter = await BackendAdapter.create(url, apiKey, type: type);
      healthTarget = adapter.healthUrl;
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
      _log('GET', healthTarget, status: resp.statusCode, ms: ms);

      String? faviconUrl;
      try {
        final clean = url.replaceAll(RegExp(r'/+$'), '');
        final faviconResp = await _dio.get('$clean/favicon.ico',
          options: Options(receiveTimeout: const Duration(seconds: 3), validateStatus: (s) => s != null && s < 400, responseType: ResponseType.bytes),
        );
        if (faviconResp.statusCode == 200 && faviconResp.data != null) {
          faviconUrl = '$clean/favicon.ico';
        }
      } catch (_) {
        try {
          final clean = url.replaceAll(RegExp(r'/+$'), '');
          final altResp = await _dio.get('$clean/favicon.png',
            options: Options(receiveTimeout: const Duration(seconds: 3), validateStatus: (s) => s != null && s < 400),
          );
          if (altResp.statusCode == 200) {
            faviconUrl = '$clean/favicon.png';
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
      _log('GET', healthTarget, ms: 0, offline: isOfflineError(e));
      return BackendCheckResult(
        online: false,
        statusCode: 0,
        responseTime: 0,
        type: BackendAdapter.detect(url, type).name,
        message: '❌ Backend inaccessible\n\nURL: $url\nErreur: ${_humanError(e)}\n\nVérifiez l\'URL et la connexion.',
      );
    }
  }

  static void _log(String method, String url, {int? status, required int ms, bool offline = false}) {
    ApiCallLog.instance.record(method: method, url: url, status: status, ms: ms, offline: offline)
        .catchError((_) {});
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

  static bool isOfflineError(DioException e) {
    if (e.response != null) return false;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.error != null && e.error.toString().toLowerCase().contains('socket');
      default:
        return false;
    }
  }

  static Future<TableResult> fetchRows(
    String url,
    String apiKey,
    String table, {
    int limit = 50,
    int offset = 0,
    String? type,
    String? searchField,
    String? searchValue,
  }) async {
    final adapter = await BackendAdapter.create(url, apiKey, type: type);
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    final headers = Map<String, String>.from(adapter.headers);

    String target;
    if (adapter.type == BackendType.supabase) {
      final q = StringBuffer('$clean/rest/v1/$table?select=*&limit=$limit&offset=$offset');
      if (searchField != null && searchField.isNotEmpty && searchValue != null) {
        q.write('&$searchField=eq.${Uri.encodeComponent(searchValue)}');
      }
      target = q.toString();
      headers['Prefer'] = 'count=exact';
    } else {
      final q = StringBuffer('$clean/$table?limit=$limit&offset=$offset');
      if (searchField != null && searchField.isNotEmpty && searchValue != null) {
        q.write('&$searchField=${Uri.encodeComponent(searchValue)}');
      }
      target = q.toString();
    }

    try {
      final sw = DateTime.now();
      final resp = await _dio.get(
        target,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      _log('GET', target, status: resp.statusCode, ms: DateTime.now().difference(sw).inMilliseconds);
      if (resp.statusCode != 200) {
        return TableResult(
          table: table,
          offset: offset,
          limit: limit,
          error: 'HTTP ${resp.statusCode}',
        );
      }

      final rows = <Map<String, dynamic>>[];
      final data = resp.data;
      if (data is List) {
        for (final r in data) {
          if (r is Map) rows.add(Map<String, dynamic>.from(r));
        }
      } else if (data is Map) {
        rows.add(Map<String, dynamic>.from(data));
      }

      int? total;
      final contentRange = resp.headers.value('content-range') ?? resp.headers.value('Content-Range');
      if (contentRange != null && contentRange.contains('/')) {
        final part = contentRange.split('/').last.trim();
        if (part != '*') total = int.tryParse(part);
      }
      if (total == null && rows.length < limit) total = offset + rows.length;

      final columns = <String>[];
      for (final r in rows) {
        for (final k in r.keys) {
          if (!columns.contains(k)) columns.add(k);
        }
      }

      return TableResult(
        table: table,
        columns: columns,
        rows: rows,
        total: total,
        offset: offset,
        limit: limit,
      );
    } on DioException catch (e) {
      _log('GET', target, ms: 0, offline: isOfflineError(e));
      return TableResult(
        table: table,
        offset: offset,
        limit: limit,
        error: _humanError(e),
        offline: isOfflineError(e),
      );
    }
  }

  static final Map<String, _CachedCount> _countCache = {};
  static const _countTtl = Duration(seconds: 60);

  static void invalidateCountCache() => _countCache.clear();

  static Future<CountResult> countRows(
    String url,
    String apiKey,
    String table, {
    String? type,
    bool force = false,
  }) async {
    final cacheKey = '$url|$table';
    if (!force) {
      final hit = _countCache[cacheKey];
      if (hit != null && DateTime.now().difference(hit.at) < _countTtl) {
        return CountResult(table: table, count: hit.count, fromCache: true);
      }
    }

    final adapter = await BackendAdapter.create(url, apiKey, type: type);
    final clean = url.replaceAll(RegExp(r'/+$'), '');

    if (adapter.type == BackendType.supabase) {
      final target = '$clean/rest/v1/$table?select=id&limit=0';
      try {
        final headers = Map<String, String>.from(adapter.headers);
        headers['Prefer'] = 'count=exact';
        final sw = DateTime.now();
        final resp = await _dio.get(
          target,
          options: Options(headers: headers, receiveTimeout: const Duration(seconds: 15), validateStatus: (s) => s != null && s < 500),
        );
        _log('GET', target, status: resp.statusCode, ms: DateTime.now().difference(sw).inMilliseconds);
        if (resp.statusCode != 200) {
          return CountResult(table: table, error: 'HTTP ${resp.statusCode}');
        }
        final total = _parseContentRange(resp.headers.value('content-range') ?? resp.headers.value('Content-Range'));
        if (total != null) {
          _countCache[cacheKey] = _CachedCount(total, DateTime.now());
          return CountResult(table: table, count: total);
        }
      } on DioException catch (e) {
        _log('GET', target, ms: 0, offline: isOfflineError(e));
        return CountResult(table: table, error: _humanError(e), offline: isOfflineError(e));
      }
    }

    // Backends generiques : pas de standard de comptage.
    // On recupere un maximum de lignes et on signale si le nombre est plafonne.
    const probeLimit = 1000;
    try {
      final resp = await _dio.get(
        '$clean/$table?limit=$probeLimit',
        options: Options(headers: adapter.headers, receiveTimeout: const Duration(seconds: 20), validateStatus: (s) => s != null && s < 500),
      );
      if (resp.statusCode != 200) {
        return CountResult(table: table, error: 'HTTP ${resp.statusCode}');
      }
      final data = resp.data;
      final n = data is List ? data.length : (data is Map ? 1 : 0);
      final exact = n < probeLimit;
      if (exact) {
        _countCache[cacheKey] = _CachedCount(n, DateTime.now());
        return CountResult(table: table, count: n);
      }
      return CountResult(table: table, count: n, approximate: true);
    } on DioException catch (e) {
      return CountResult(table: table, error: _humanError(e), offline: isOfflineError(e));
    }
  }

  static int? _parseContentRange(String? header) {
    if (header == null || !header.contains('/')) return null;
    final part = header.split('/').last.trim();
    if (part == '*') return null;
    return int.tryParse(part);
  }

  static Future<SchemaResult> fetchSchema(String url, String apiKey, String table, {String? type}) async {
    final adapter = await BackendAdapter.create(url, apiKey, type: type);
    final clean = url.replaceAll(RegExp(r'/+$'), '');

    if (adapter.type == BackendType.supabase) {
      try {
        final resp = await _dio.get(
          '$clean/rest/v1/',
          options: Options(headers: adapter.headers, receiveTimeout: const Duration(seconds: 15)),
        );
        final spec = resp.data;
        if (spec is Map) {
          final components = spec['components'];
          final schemas = components is Map ? components['schemas'] : null;
          final schema = schemas is Map ? schemas[table] : null;
          final props = schema is Map ? schema['properties'] : null;
          if (props is Map && props.isNotEmpty) {
            final cols = <ColumnInfo>[];
            props.forEach((key, value) {
              cols.add(ColumnInfo(name: '$key', type: _openApiType(value)));
            });
            return SchemaResult(table: table, columns: cols);
          }
        }
      } catch (_) {}
    }

    try {
      final target = adapter.type == BackendType.supabase
          ? '$clean/rest/v1/$table?select=*&limit=1'
          : '$clean/$table?limit=1';
      final resp = await _dio.get(
        target,
        options: Options(headers: adapter.headers, receiveTimeout: const Duration(seconds: 15), validateStatus: (s) => s != null && s < 500),
      );
      if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
        final row = (resp.data as List).first;
        if (row is Map) {
          final cols = <ColumnInfo>[];
          row.forEach((key, value) {
            cols.add(ColumnInfo(name: '$key', type: _dartTypeOf(value)));
          });
          return SchemaResult(table: table, columns: cols, inferred: true);
        }
      }
      return SchemaResult(table: table, error: 'HTTP ${resp.statusCode}');
    } on DioException catch (e) {
      return SchemaResult(table: table, error: _humanError(e), offline: isOfflineError(e));
    }
  }

  static String _openApiType(dynamic value) {
    if (value is! Map) return 'unknown';
    if (value['type'] != null) return '${value['type']}';
    final anyOf = value['anyOf'];
    if (anyOf is List && anyOf.isNotEmpty) {
      return anyOf.map((e) => e is Map && e['type'] != null ? '${e['type']}' : 'unknown').join(' | ');
    }
    final ref = value[r'$ref'];
    if (ref is String) return ref.split('/').last;
    return 'unknown';
  }

  static String _dartTypeOf(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return 'String';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return value.runtimeType.toString();
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

class _CachedCount {
  final int count;
  final DateTime at;
  const _CachedCount(this.count, this.at);
}

class CountResult {
  final String table;
  final int? count;
  final String? error;
  final bool offline;
  final bool fromCache;
  final bool approximate;

  const CountResult({
    required this.table,
    this.count,
    this.error,
    this.offline = false,
    this.fromCache = false,
    this.approximate = false,
  });

  bool get ok => error == null && count != null;
}

class TableResult {
  final String table;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int? total;
  final int offset;
  final int limit;
  final String? error;
  final bool offline;

  const TableResult({
    required this.table,
    this.columns = const [],
    this.rows = const [],
    this.total,
    required this.offset,
    required this.limit,
    this.error,
    this.offline = false,
  });

  bool get ok => error == null;
  bool get hasMore {
    if (rows.isEmpty) return false;
    if (total != null) return (offset + rows.length) < total!;
    return rows.length >= limit;
  }

  int? get pageNumber => total == null ? null : (offset ~/ limit) + 1;
  int? get pageCount => total == null ? null : ((total! + limit - 1) ~/ limit).clamp(1, 1 << 30);
}

class ColumnInfo {
  final String name;
  final String type;
  const ColumnInfo({required this.name, required this.type});
}

class SchemaResult {
  final String table;
  final List<ColumnInfo> columns;
  final String? error;
  final bool offline;
  final bool inferred;
  const SchemaResult({
    required this.table,
    this.columns = const [],
    this.error,
    this.offline = false,
    this.inferred = false,
  });
  bool get ok => error == null && columns.isNotEmpty;
}
