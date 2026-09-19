class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._();

  final Map<String, List<Map<String, dynamic>>> _tables = {};

  List<Map<String, dynamic>> _getTable(String name) {
    _tables.putIfAbsent(name, () => []);
    return _tables[name]!;
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
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
    _getTable(table).add(Map<String, dynamic>.from(data));
    return 1;
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
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
    return count;
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final rows = _getTable(table);
    if (where == null || whereArgs == null || whereArgs.isEmpty) {
      final len = rows.length;
      rows.clear();
      return len;
    }
    final key = where.split('=')[0].trim();
    final val = whereArgs.first;
    final before = rows.length;
    rows.removeWhere((r) => r[key] == val);
    return before - rows.length;
  }

  Future<void> close() async {}
}
