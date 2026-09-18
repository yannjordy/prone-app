import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectExecutionsPage extends StatelessWidget {
  final String projectId;
  const ProjectExecutionsPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final executions = [
      _Execution(id: '#1234', workflow: 'Order Processing', status: 'success', duration: '2.3s', time: '14:32', user: 'John Doe'),
      _Execution(id: '#1233', workflow: 'User Registration', status: 'success', duration: '1.1s', time: '14:15', user: 'Jane Smith'),
      _Execution(id: '#1232', workflow: 'Payment Webhook', status: 'failed', duration: 'timeout', time: '13:50', user: 'System'),
      _Execution(id: '#1231', workflow: 'Daily Cleanup', status: 'success', duration: '45.2s', time: '13:30', user: 'System'),
      _Execution(id: '#1230', workflow: 'Backup Job', status: 'success', duration: '120s', time: '12:00', user: 'System'),
      _Execution(id: '#1229', workflow: 'Email Send', status: 'success', duration: '0.8s', time: '11:45', user: 'Jane Smith'),
      _Execution(id: '#1228', workflow: 'Data Sync', status: 'running', duration: '15s...', time: '11:30', user: 'John Doe'),
    ];

    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: executions.length,
              itemBuilder: (context, index) => _ExecutionCard(execution: executions[index]),
            ),
          ),
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
            SvgPicture.asset('assets/icons/executions.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('EXECUTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
          ],
        ),
      ),
    );
  }
}

class _Execution {
  final String id;
  final String workflow;
  final String status;
  final String duration;
  final String time;
  final String user;
  _Execution({required this.id, required this.workflow, required this.status, required this.duration, required this.time, required this.user});
}

class _ExecutionCard extends StatelessWidget {
  final _Execution execution;
  const _ExecutionCard({required this.execution});

  Color _statusColor(BuildContext context) {
    switch (execution.status) {
      case 'success': return AppColors.success;
      case 'failed': return AppColors.error;
      case 'running': return AppColors.primary;
      default: return ThemeHelper.textDim(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: execution.status == 'running'
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _statusColor(context)))
                        : SvgPicture.asset(execution.status == 'success' ? 'assets/icons/check-circle.svg' : 'assets/icons/alert-circle.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_statusColor(context), BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(execution.workflow, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                          const SizedBox(width: 6),
                          Text(execution.id, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(execution.user, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                          const SizedBox(width: 8),
                          Text(execution.time, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
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
                  child: Text(execution.duration, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
