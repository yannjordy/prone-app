import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._();

  final Map<String, List<Map<String, dynamic>>> _tables = {};
  bool _loaded = false;

  List<Map<String, dynamic>> _getTable(String name) {
    _tables.putIfAbsent(name, () => []);
    return _tables[name]!;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('db_')).toList();
      for (final key in keys) {
        final tableName = key.replaceFirst('db_', '');
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
            _tables[tableName] = list;
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _persistTable(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _tables[name] ?? [];
      await prefs.setString('db_$name', jsonEncode(data));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    await _ensureLoaded();
    var rows = List<Map<String, dynamic>>.from(_getTable(table));
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      final key = where.split('=')[0].trim();
      final val = whereArgs.first;
      rows = rows.where((r) => r[key] == val).toList();
    }
    if (orderBy != null) {
      final desc = orderBy.contains(' DESC');
      final field = orderBy.replaceAll(RegExp(r'\s*(ASC|DESC)\s*'), '').trim();
      rows.sort((a, b) {
        final va = a[field] ?? '';
        final vb = b[field] ?? '';
        final cmp = va.toString().compareTo(vb.toString());
        return desc ? -cmp : cmp;
      });
    }
    return rows;
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    await _ensureLoaded();
    _getTable(table).add(Map<String, dynamic>.from(data));
    await _persistTable(table);
    return 1;
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    await _ensureLoaded();
    final rows = _getTable(table);
    int count = 0;
    for (int i = 0; i < rows.length; i++) {
      if (where != null && whereArgs != null) {
        final key = where.split('=')[0].trim();
        final val = whereArgs.first;
        if (rows[i][key] != val) continue;
      }
      rows[i].addAll(data);
      count++;
    }
    if (count > 0) await _persistTable(table);
    return count;
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    await _ensureLoaded();
    final rows = _getTable(table);
    if (where == null || whereArgs == null || whereArgs.isEmpty) {
      final len = rows.length;
      rows.clear();
      await _persistTable(table);
      return len;
    }
    final key = where.split('=')[0].trim();
    final val = whereArgs.first;
    final before = rows.length;
    rows.removeWhere((r) => r[key] == val);
    if (rows.length != before) await _persistTable(table);
    return before - rows.length;
  }

  Future<void> close() async {}
}
