import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ErrorLevel { error, warning, offline }

class BackendErrorEntry {
  final String id;
  final String projectId;
  final String message;
  final String? command;
  final ErrorLevel level;
  final DateTime at;
  final bool read;

  const BackendErrorEntry({
    required this.id,
    required this.projectId,
    required this.message,
    this.command,
    required this.level,
    required this.at,
    this.read = false,
  });

  factory BackendErrorEntry.fromJson(Map<String, dynamic> json) => BackendErrorEntry(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        message: json['message'] as String? ?? '',
        command: json['command'] as String?,
        level: ErrorLevel.values.firstWhere(
          (e) => e.name == json['level'],
          orElse: () => ErrorLevel.error,
        ),
        at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
        read: (json['read'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'message': message,
        'command': command,
        'level': level.name,
        'at': at.toIso8601String(),
        'read': read,
      };
}

class BackendErrorStore {
  BackendErrorStore._();
  static final BackendErrorStore instance = BackendErrorStore._();

  static const _max = 50;

  String _key(String projectId) => 'backend_errors_$projectId';

  Future<List<BackendErrorEntry>> _read(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(projectId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => BackendErrorEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String projectId, List<BackendErrorEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectId), jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<BackendErrorEntry> record(
    String projectId,
    String message, {
    String? command,
    ErrorLevel level = ErrorLevel.error,
  }) async {
    final items = await _read(projectId);
    final entry = BackendErrorEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      projectId: projectId,
      message: message,
      command: command,
      level: level,
      at: DateTime.now(),
    );
    items.insert(0, entry);
    if (items.length > _max) items.removeRange(_max, items.length);
    await _write(projectId, items);
    return entry;
  }

  Future<List<BackendErrorEntry>> recent(String projectId) => _read(projectId);

  Future<int> unreadCount(String projectId) async {
    final items = await _read(projectId);
    return items.where((e) => !e.read).length;
  }

  Future<void> markAllRead(String projectId) async {
    final items = await _read(projectId);
    if (items.isEmpty) return;
    final updated = items
        .map((e) => BackendErrorEntry(
              id: e.id,
              projectId: e.projectId,
              message: e.message,
              command: e.command,
              level: e.level,
              at: e.at,
              read: true,
            ))
        .toList();
    await _write(projectId, updated);
  }

  Future<void> clear(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(projectId));
  }
}
