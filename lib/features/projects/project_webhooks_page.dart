import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectWebhooksPage extends StatefulWidget {
  final String projectId;
  const ProjectWebhooksPage({super.key, required this.projectId});

  @override
  State<ProjectWebhooksPage> createState() => _ProjectWebhooksPageState();
}

class _ProjectWebhooksPageState extends State<ProjectWebhooksPage> {
  final List<_Webhook> _webhooks = [
    _Webhook(name: 'Stripe Payment', url: '/webhook/stripe', events: ['payment.success', 'payment.failed'], status: 'active', lastTrigger: '5 min'),
    _Webhook(name: 'GitHub Push', url: '/webhook/github', events: ['push', 'pull_request'], status: 'active', lastTrigger: '1h'),
    _Webhook(name: 'Slack Notify', url: '/webhook/slack', events: ['order.created'], status: 'inactive', lastTrigger: '3j'),
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
          Expanded(child: _buildWebhooksList()),
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
            SvgPicture.asset('assets/icons/webhooks.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('WEBHOOKS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_webhooks.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhooksList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _webhooks.length,
      itemBuilder: (context, index) {
        final wh = _webhooks[index];
        return _WebhookCard(
          webhook: wh,
          onCopy: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL copiée: ${wh.url}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          onToggle: () => setState(() => wh.status = wh.status == 'active' ? 'inactive' : 'active'),
        );
      },
    );
  }
}

class _Webhook {
  final String name;
  final String url;
  final List<String> events;
  String status;
  final String lastTrigger;
  _Webhook({required this.name, required this.url, required this.events, required this.status, required this.lastTrigger});
}

class _WebhookCard extends StatelessWidget {
  final _Webhook webhook;
  final VoidCallback onCopy;
  final VoidCallback onToggle;

  const _WebhookCard({required this.webhook, required this.onCopy, required this.onToggle});

  Color _statusColor(BuildContext context) => webhook.status == 'active' ? AppColors.success : ThemeHelper.textDim(context);

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
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: SvgPicture.asset('assets/icons/webhooks.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(webhook.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                          const SizedBox(height: 2),
                          Text('Dernier: ${webhook.lastTrigger}', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(webhook.status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(context), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThemeHelper.bg(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ThemeHelper.borderLight(context)),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset('assets/icons/terminal.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(webhook.url, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                        ),
                        SvgPicture.asset('assets/icons/send.svg', width: 12, height: 12, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: webhook.events.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontFamily: 'monospace')),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onToggle,
                      child: SvgPicture.asset(webhook.status == 'active' ? 'assets/icons/log-out.svg' : 'assets/icons/arrow-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
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
