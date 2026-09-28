import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiCall {
  final String id;
  final String method;
  final String url;
  final int? status;
  final int ms;
  final bool ok;
  final bool offline;
  final DateTime at;

  const ApiCall({
    required this.id,
    required this.method,
    required this.url,
    this.status,
    required this.ms,
    required this.ok,
    this.offline = false,
    required this.at,
  });

  factory ApiCall.fromJson(Map<String, dynamic> json) => ApiCall(
        id: json['id'] as String,
        method: json['method'] as String? ?? 'GET',
        url: json['url'] as String? ?? '',
        status: json['status'] as int?,
        ms: (json['ms'] as int?) ?? 0,
        ok: (json['ok'] as bool?) ?? false,
        offline: (json['offline'] as bool?) ?? false,
        at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        'status': status,
        'ms': ms,
        'ok': ok,
        'offline': offline,
        'at': at.toIso8601String(),
      };
}

class ApiCallLog {
  ApiCallLog._();
  static final ApiCallLog instance = ApiCallLog._();

  static const _key = 'api_call_log';
  static const _max = 60;

  Future<List<ApiCall>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => ApiCall.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<ApiCall> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> record({
    required String method,
    required String url,
    int? status,
    required int ms,
    bool offline = false,
  }) async {
    final items = await _read();
    items.insert(0, ApiCall(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      url: _shorten(url),
      status: status,
      ms: ms,
      ok: status != null && status < 400,
      offline: offline,
      at: DateTime.now(),
    ));
    if (items.length > _max) items.removeRange(_max, items.length);
    await _write(items);
  }

  static String _shorten(String url) {
    if (url.length <= 90) return url;
    return '${url.substring(0, 87)}...';
  }

  Future<List<ApiCall>> recent({int limit = 20}) async {
    final items = await _read();
    return items.take(limit).toList();
  }

  Future<void> clear() => _write([]);
}
