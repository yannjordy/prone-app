import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectMonitoringPage extends StatelessWidget {
  final String projectId;
  const ProjectMonitoringPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatCard(context, 'Uptime', '99.97%', 'Depuis 15 jours', AppColors.success, 'activity.svg'),
                _buildStatCard(context, 'Latence moy.', '45ms', 'Dernière heure', AppColors.primary, 'clock.svg'),
                _buildStatCard(context, 'Requêtes', '12,456', 'Aujourd\'hui', AppColors.primaryDark, 'zap.svg'),
                _buildStatCard(context, 'Erreurs', '3', 'Dernières 24h', AppColors.error, 'alert-circle.svg'),
                const SizedBox(height: 16),
                _buildSection(context, 'Services', [
                  _ServiceRow(name: 'API Server', status: 'online', latency: '12ms'),
                  _ServiceRow(name: 'PostgreSQL', status: 'online', latency: '5ms'),
                  _ServiceRow(name: 'Redis Cache', status: 'online', latency: '2ms'),
                  _ServiceRow(name: 'Email Service', status: 'degraded', latency: '340ms'),
                  _ServiceRow(name: 'Storage', status: 'online', latency: '8ms'),
                ]),
                const SizedBox(height: 16),
                _buildSection(context, 'Backend Health', [
                  _ServiceRow(name: 'CPU Usage', status: 'online', latency: '23%'),
                  _ServiceRow(name: 'RAM Usage', status: 'online', latency: '512MB/1GB'),
                  _ServiceRow(name: 'Disk', status: 'online', latency: '45GB/100GB'),
                ]),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/monitoring.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('MONITORING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, String subtitle, Color color, String icon) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SvgPicture.asset('assets/icons/$icon', width: 20, height: 20, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 12, color: textDimColor)),
                      const SizedBox(height: 2),
                      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ),
                Text(subtitle, style: TextStyle(fontSize: 11, color: textDimColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final borderColor = ThemeHelper.borderLight(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String name;
  final String status;
  final String latency;

  const _ServiceRow({required this.name, required this.status, required this.latency});

  Color get _statusColor {
    switch (status) {
      case 'online': return AppColors.success;
      case 'degraded': return AppColors.warning;
      default: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.5), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 13, color: textColor)),
          ),
          Text(latency, style: TextStyle(fontSize: 12, color: textDimColor, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
