import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QueuedCommand {
  final String id;
  final String projectId;
  final String command;
  final DateTime createdAt;
  final int attempts;

  const QueuedCommand({
    required this.id,
    required this.projectId,
    required this.command,
    required this.createdAt,
    this.attempts = 0,
  });

  factory QueuedCommand.fromJson(Map<String, dynamic> json) => QueuedCommand(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        command: json['command'] as String,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        attempts: (json['attempts'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'command': command,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };
}

class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _key = 'offline_queue';
  static const _maxPerProject = 25;

  Future<List<QueuedCommand>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => QueuedCommand.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<QueuedCommand> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<QueuedCommand>> pending(String projectId) async {
    final all = await _read();
    return all.where((c) => c.projectId == projectId).toList();
  }

  Future<List<QueuedCommand>> pendingAll() => _read();

  Future<QueuedCommand> enqueue(String projectId, String command) async {
    final all = await _read();
    final forProject = all.where((c) => c.projectId == projectId).toList();
    while (forProject.length >= _maxPerProject) {
      final removed = forProject.removeAt(0);
      all.removeWhere((c) => c.id == removed.id);
    }
    final item = QueuedCommand(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      projectId: projectId,
      command: command.trim(),
      createdAt: DateTime.now(),
    );
    all.add(item);
    await _write(all);
    return item;
  }

  Future<void> remove(String id) async {
    final all = await _read();
    all.removeWhere((c) => c.id == id);
    await _write(all);
  }

  Future<void> bumpAttempts(String id) async {
    final all = await _read();
    final idx = all.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = all[idx];
    all[idx] = QueuedCommand(
      id: old.id,
      projectId: old.projectId,
      command: old.command,
      createdAt: old.createdAt,
      attempts: old.attempts + 1,
    );
    await _write(all);
  }

  Future<void> clearProject(String projectId) async {
    final all = await _read();
    all.removeWhere((c) => c.projectId == projectId);
    await _write(all);
  }

  Future<void> clearAll() => _write([]);
}
