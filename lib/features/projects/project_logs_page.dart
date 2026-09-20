import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';

class ProjectLogsPage extends StatefulWidget {
  final String projectId;
  const ProjectLogsPage({super.key, required this.projectId});

  @override
  State<ProjectLogsPage> createState() => _ProjectLogsPageState();
}

class _ProjectLogsPageState extends State<ProjectLogsPage> {
  final _backend = LocalBackend();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() { _loading = true; });
    final logs = await _backend.getLogs(widget.projectId);
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_filter == 'all') return _logs;
    return _logs.where((l) => (l['level'] as String?)?.toLowerCase() == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 12),
          _buildFilters(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeHelper.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeHelper.borderLight(context)),
        ),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/logs.svg', width: 20, height: 20,
              colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('LOGS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            Text('${_logs.length} entrées', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
            const SizedBox(width: 8),
            GestureDetector(onTap: _loadLogs,
              child: Icon(Icons.refresh, size: 20, color: ThemeHelper.textDim(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [('all', 'Tous', AppColors.primary), ('info', 'Info', AppColors.success),
      ('warning', 'Warn', AppColors.warning), ('error', 'Erreur', AppColors.error)];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? f.$3.withOpacity(0.15) : ThemeHelper.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? f.$3 : ThemeHelper.borderLight(context)),
              ),
              child: Text(f.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isSelected ? f.$3 : ThemeHelper.textDim(context))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article, size: 48, color: ThemeHelper.textDim(context)),
            const SizedBox(height: 12),
            Text('Aucun log', style: TextStyle(fontSize: 16, color: ThemeHelper.textDim(context))),
            const SizedBox(height: 4),
            Text('Les logs apparaîtront ici', style: TextStyle(fontSize: 13,
              color: ThemeHelper.textDim(context).withOpacity(0.6))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) => _LogCard(log: _filteredLogs[index]),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final level = (log['level'] as String?) ?? 'INFO';
    final message = (log['message'] as String?) ?? '';
    final details = (log['details'] as String?) ?? '';
    final createdAt = (log['created_at'] as String?) ?? '';
    final time = createdAt.length >= 19 ? createdAt.substring(11, 19) : createdAt;

    Color levelColor;
    switch (level.toLowerCase()) {
      case 'warning': levelColor = AppColors.warning; break;
      case 'error': case 'critical': levelColor = AppColors.error; break;
      default: levelColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeHelper.surface(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeHelper.borderLight(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(time, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: levelColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(level.toUpperCase(), style: TextStyle(fontSize: 9, color: levelColor, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ),
          ]),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 12, color: ThemeHelper.text(context), fontFamily: 'monospace'), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
