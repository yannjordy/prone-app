import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectLogsPage extends StatelessWidget {
  final String projectId;
  const ProjectLogsPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final logs = [
      _Log(time: '14:32:15', level: 'INFO', message: 'GET /api/users 200 OK (45ms)', user: 'John Doe'),
      _Log(time: '14:31:42', level: 'INFO', message: 'POST /api/orders 201 Created (120ms)', user: 'Jane Smith'),
      _Log(time: '14:30:18', level: 'WARN', message: 'Rate limit exceeded /api/users', user: 'System'),
      _Log(time: '14:28:55', level: 'INFO', message: 'POST /api/auth/login 200 OK (89ms)', user: 'John Doe'),
      _Log(time: '14:25:03', level: 'ERROR', message: 'Connection refused to external API', user: 'System'),
      _Log(time: '14:20:11', level: 'INFO', message: 'GET /api/users/123 200 OK (38ms)', user: 'Jane Smith'),
      _Log(time: '14:15:44', level: 'INFO', message: 'PUT /api/products/45 200 OK (67ms)', user: 'John Doe'),
      _Log(time: '14:10:22', level: 'INFO', message: 'Webhook received from Stripe', user: 'System'),
    ];

    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: logs.length,
              itemBuilder: (context, index) => _LogCard(log: logs[index]),
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
            SvgPicture.asset('assets/icons/logs.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('LOGS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            SvgPicture.asset('assets/icons/search.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
          ],
        ),
      ),
    );
  }
}

class _Log {
  final String time;
  final String level;
  final String message;
  final String user;
  _Log({required this.time, required this.level, required this.message, required this.user});
}

class _LogCard extends StatelessWidget {
  final _Log log;
  const _LogCard({required this.log});

  Color _levelColor(BuildContext context) {
    switch (log.level) {
      case 'INFO': return AppColors.success;
      case 'WARN': return AppColors.warning;
      case 'ERROR': return AppColors.error;
      default: return ThemeHelper.textDim(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.time, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _levelColor(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(log.level, style: TextStyle(fontSize: 9, color: _levelColor(context), fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.message, style: TextStyle(fontSize: 12, color: ThemeHelper.text(context), fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(log.user, style: TextStyle(fontSize: 10, color: ThemeHelper.textDim(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
