import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/backend/backend_adapter.dart';

class ProjectWorkflowsPage extends StatefulWidget {
  final String projectId;
  const ProjectWorkflowsPage({super.key, required this.projectId});

  @override
  State<ProjectWorkflowsPage> createState() => _ProjectWorkflowsPageState();
}

class _ProjectWorkflowsPageState extends State<ProjectWorkflowsPage> {
  final _backend = LocalBackend();
  List<Map<String, dynamic>> _workflows = [];
  String _backendUrl = '';
  String _apiKey = '';
  String _backendType = 'generic';

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    final projects = await _backend.getProjects();
    final match = projects.where((p) => p['id'] == widget.projectId).toList();
    if (match.isNotEmpty) {
      final p = match.first;
      _backendUrl = (p['backend_url'] as String?) ?? '';
      _apiKey = (p['api_key'] as String?) ?? '';
      _backendType = BackendAdapter.detect(_backendUrl, null).name;
    }
    final wfs = await _backend.getWorkflows(widget.projectId);
    if (mounted) setState(() => _workflows = wfs);
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
          Expanded(child: _buildWorkflowsList()),
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
            GestureDetector(
              onTap: () => context.go('/projects/${widget.projectId}'),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
              ),
            ),
            const SizedBox(width: 10),
            SvgPicture.asset('assets/icons/workflows.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('WORKFLOWS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_workflows.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowsList() {
    if (_workflows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/workflows.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            const SizedBox(height: 16),
            Text('Aucun workflow', style: TextStyle(fontSize: 16, color: ThemeHelper.textDim(context))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _workflows.length,
      itemBuilder: (context, index) {
        final wf = _workflows[index];
        final steps = ((wf['description'] as String?) ?? '').split('->').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        return _WorkflowCard(
          name: (wf['name'] as String?) ?? 'Workflow',
          status: (wf['status'] as String?) ?? 'active',
          steps: steps.isEmpty ? ['start', 'end'] : steps,
          lastRun: (wf['created_at'] as String?) ?? 'jamais',
          onRun: () => _runWorkflow(wf),
          onToggle: () => _toggleWorkflow(wf),
          onDelete: () async {
            await _backend.deleteWorkflow(widget.projectId, wf['id'] as String);
            _loadWorkflows();
          },
        );
      },
    );
  }

  void _toggleWorkflow(Map<String, dynamic> wf) async {
    final newStatus = wf['status'] == 'active' ? 'paused' : 'active';
    await _backend.updateWorkflow(wf['id'] as String, {'status': newStatus});
    _loadWorkflows();
  }

  void _runWorkflow(Map<String, dynamic> wf) async {
    final name = (wf['name'] as String?) ?? 'Workflow';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exécution de "$name"...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final sw = Stopwatch()..start();
    final res = await BackendAdapter.check(_backendUrl, _apiKey, type: _backendType);
    sw.stop();
    final ms = sw.elapsedMilliseconds;
    await _backend.addExecution(widget.projectId, name, res.online ? 'success' : 'failed', duration: '$ms ms');
    await _backend.addLog(widget.projectId, res.online ? 'info' : 'error',
        'Workflow "$name" exécuté — backend ${res.online ? "en ligne" : "injoignable"} ($ms ms)');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.online ? '"$name" terminé en $ms ms' : '"$name" échoué — backend injoignable'),
        backgroundColor: res.online ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  final String name;
  final String status;
  final List<String> steps;
  final String lastRun;
  final VoidCallback onRun;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _WorkflowCard({required this.name, required this.status, required this.steps, required this.lastRun, required this.onRun, required this.onToggle, required this.onDelete});

  Color _statusColor(BuildContext context) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'scheduled': return AppColors.primary;
      case 'paused': return AppColors.warning;
      default: return ThemeHelper.textDim(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _statusColor(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: SvgPicture.asset('assets/icons/workflows.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_statusColor(context), BlendMode.srcIn)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                          const SizedBox(height: 2),
                          Text('Dernière exécution: ${lastRun}', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onRun,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.gradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SvgPicture.asset('assets/icons/arrow-right.svg', width: 14, height: 14, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    final isLast = i == steps.length - 1;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: ThemeHelper.bg(context),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ThemeHelper.borderLight(context)),
                              ),
                              child: Center(
                                child: Text(step, style: TextStyle(fontSize: 10, color: ThemeHelper.textDim(context)), overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: SvgPicture.asset('assets/icons/arrow-right.svg', width: 10, height: 10, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(context), fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: ThemeHelper.borderLight(context))),
                        child: SvgPicture.asset(status == 'active' ? 'assets/icons/mute.svg' : 'assets/icons/zap.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(_statusColor(context), BlendMode.srcIn)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: ThemeHelper.borderLight(context))),
                        child: SvgPicture.asset('assets/icons/trash.svg', width: 14, height: 14, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
