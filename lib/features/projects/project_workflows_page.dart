import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectWorkflowsPage extends StatefulWidget {
  final String projectId;
  const ProjectWorkflowsPage({super.key, required this.projectId});

  @override
  State<ProjectWorkflowsPage> createState() => _ProjectWorkflowsPageState();
}

class _ProjectWorkflowsPageState extends State<ProjectWorkflowsPage> {
  final List<_Workflow> _workflows = [
    _Workflow(name: 'User Registration', steps: ['validate', 'create', 'email'], status: 'active', lastRun: '2 min'),
    _Workflow(name: 'Order Processing', steps: ['validate', 'payment', 'inventory', 'notify'], status: 'active', lastRun: '15 min'),
    _Workflow(name: 'Daily Backup', steps: ['export', 'compress', 'upload'], status: 'scheduled', lastRun: '12h'),
    _Workflow(name: 'Email Notifications', steps: ['template', 'send'], status: 'paused', lastRun: '3j'),
  ];

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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _workflows.length,
      itemBuilder: (context, index) {
        final wf = _workflows[index];
        return _WorkflowCard(
          workflow: wf,
          onRun: () => _runWorkflow(wf),
          onToggle: () => setState(() {
            wf.status = wf.status == 'active' ? 'paused' : 'active';
          }),
        );
      },
    );
  }

  void _runWorkflow(_Workflow wf) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exécution de "${wf.name}"...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Workflow {
  final String name;
  final List<String> steps;
  String status;
  final String lastRun;
  _Workflow({required this.name, required this.steps, required this.status, required this.lastRun});
}

class _WorkflowCard extends StatelessWidget {
  final _Workflow workflow;
  final VoidCallback onRun;
  final VoidCallback onToggle;

  const _WorkflowCard({required this.workflow, required this.onRun, required this.onToggle});

  Color _statusColor(BuildContext context) {
    switch (workflow.status) {
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
                          Text(workflow.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                          const SizedBox(height: 2),
                          Text('Dernière exécution: ${workflow.lastRun}', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
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
                  children: workflow.steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    final isLast = i == workflow.steps.length - 1;
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
                      child: Text(workflow.status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(context), fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onToggle,
                      child: SvgPicture.asset(workflow.status == 'active' ? 'assets/icons/log-out.svg' : 'assets/icons/arrow-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
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
