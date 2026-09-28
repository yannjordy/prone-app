import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';

class ProjectExecutionsPage extends StatefulWidget {
  final String projectId;
  const ProjectExecutionsPage({super.key, required this.projectId});

  @override
  State<ProjectExecutionsPage> createState() => _ProjectExecutionsPageState();
}

class _ProjectExecutionsPageState extends State<ProjectExecutionsPage> {
  final _backend = LocalBackend();
  List<Map<String, dynamic>> _executions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExecutions();
  }

  Future<void> _loadExecutions() async {
    final execs = await _backend.getExecutions(widget.projectId);
    if (mounted) setState(() { _executions = execs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _executions.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadExecutions,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _executions.length,
                          itemBuilder: (context, index) => _ExecutionCard(execution: _executions[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final textDimColor = ThemeHelper.textDim(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/icons/executions.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
          const SizedBox(height: 16),
          Text('Aucune execution', style: TextStyle(fontSize: 16, color: textDimColor)),
          const SizedBox(height: 8),
          Text('Lancez un workflow depuis l\'onglet Workflows', style: TextStyle(fontSize: 13, color: textDimColor.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            SvgPicture.asset('assets/icons/executions.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('EXECUTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            GestureDetector(
              onTap: _loadExecutions,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: ThemeHelper.borderLight(context))),
                child: SvgPicture.asset('assets/icons/activity.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  final Map<String, dynamic> execution;
  const _ExecutionCard({required this.execution});

  Color _statusColor(BuildContext context) {
    switch (execution['status']) {
      case 'success': return AppColors.success;
      case 'failed': return AppColors.error;
      case 'running': return AppColors.primary;
      default: return ThemeHelper.textDim(context);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = (execution['status'] as String?) ?? 'success';
    final id = (execution['id'] as String?) ?? '';
    final shortId = id.length > 6 ? '#${id.substring(id.length - 6)}' : '#$id';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: status == 'running'
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _statusColor(context)))
                        : SvgPicture.asset(status == 'success' ? 'assets/icons/check-circle.svg' : 'assets/icons/alert-circle.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_statusColor(context), BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text((execution['name'] as String?) ?? 'Execution', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeHelper.text(context)), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          Text(shortId, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(status, style: TextStyle(fontSize: 11, color: _statusColor(context))),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                          const SizedBox(width: 8),
                          Text(_formatTime(execution['created_at'] as String?), style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeHelper.bg(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text((execution['duration'] as String?) ?? '-', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
