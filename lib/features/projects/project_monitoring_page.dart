import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/backend/backend_adapter.dart';

class ProjectMonitoringPage extends StatefulWidget {
  final String projectId;
  const ProjectMonitoringPage({super.key, required this.projectId});
  @override
  State<ProjectMonitoringPage> createState() => _ProjectMonitoringPageState();
}

class _ProjectMonitoringPageState extends State<ProjectMonitoringPage> {
  final _backend = LocalBackend();
  String _backendUrl = '';
  String _apiKey = '';
  String _backendType = 'generic';
  bool _loading = true;
  bool _isOnline = false;
  int _responseTime = 0;
  int _statusCode = 0;
  List<String> _tables = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    final projects = await _backend.getProjects();
    final project = projects.where((p) => p['id'] == widget.projectId).toList();
    if (project.isEmpty) { setState(() { _loading = false; _error = 'Projet non trouve'; }); return; }
    final p = project.first;
    _backendUrl = (p['backend_url'] as String?) ?? '';
    _apiKey = (p['api_key'] as String?) ?? '';
    _backendType = BackendAdapter.detect(_backendUrl, null).name;
    if (_backendUrl.isEmpty) { setState(() { _loading = false; _error = 'Backend non configure'; }); return; }
    try {
      final result = await BackendAdapter.check(_backendUrl, _apiKey, type: _backendType);
      _isOnline = result.online;
      _responseTime = result.responseTime;
      _statusCode = result.statusCode;
      _tables = await BackendAdapter.listTables(_backendUrl, _apiKey, type: _backendType);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 16),
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
        child: Row(children: [
          SvgPicture.asset('assets/icons/monitoring.svg', width: 20, height: 20,
            colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
          const SizedBox(width: 12),
          Text('MONITORING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: 1, color: ThemeHelper.textDim(context))),
          const Spacer(),
          GestureDetector(onTap: _loadData,
            child: Icon(Icons.refresh, size: 20, color: ThemeHelper.textDim(context))),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(fontSize: 14, color: ThemeHelper.textDim(context))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10)),
                child: const Text('Reessayer', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard('Status', _isOnline ? 'En ligne' : 'Hors ligne',
            _isOnline ? 'Backend actif' : 'Backend inaccessible',
            _isOnline ? AppColors.success : AppColors.error, 'activity.svg'),
          _buildStatCard('Latence', '${_responseTime}ms', 'Temps de reponse',
            _responseTime < 200 ? AppColors.success : _responseTime < 500 ? AppColors.warning : AppColors.error, 'clock.svg'),
          _buildStatCard('Status HTTP', '$_statusCode', _statusCode == 200 ? 'OK' : 'Erreur',
            _statusCode == 200 ? AppColors.success : AppColors.error, 'zap.svg'),
          _buildStatCard('Tables', '${_tables.length}', 'Tables detectees',
            AppColors.primary, 'connections.svg'),
          const SizedBox(height: 16),
          _buildSection('Tables detectees', _tables.isEmpty
            ? [Text('Aucune table detectee', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context)))]
            : _tables.map((t) => _ServiceRow(name: t)).toList()),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, String icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.surface(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeHelper.borderLight(context)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Center(child: SvgPicture.asset('assets/icons/$icon', width: 20, height: 20,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ],
        )),
        Text(subtitle, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
      ]),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.surface(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeHelper.borderLight(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String name;
  const _ServiceRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 4)])),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: ThemeHelper.text(context)))),
      ]),
    );
  }
}
