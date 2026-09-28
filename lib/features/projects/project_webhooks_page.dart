import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';

class ProjectWebhooksPage extends StatefulWidget {
  final String projectId;
  const ProjectWebhooksPage({super.key, required this.projectId});

  @override
  State<ProjectWebhooksPage> createState() => _ProjectWebhooksPageState();
}

class _ProjectWebhooksPageState extends State<ProjectWebhooksPage> {
  final _backend = LocalBackend();
  List<Map<String, dynamic>> _webhooks = [];

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  Future<void> _loadWebhooks() async {
    var whs = await _backend.getWebhooks(widget.projectId);
    if (whs.isEmpty) {
      await _backend.createWebhook(widget.projectId, 'Stripe Payment', 'https://api.example.com/webhook/stripe', ['payment.success', 'payment.failed']);
      await _backend.createWebhook(widget.projectId, 'GitHub Push', 'https://api.example.com/webhook/github', ['push', 'pull_request']);
      whs = await _backend.getWebhooks(widget.projectId);
    }
    if (mounted) setState(() => _webhooks = whs);
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
            GestureDetector(
              onTap: () => context.go('/projects/${widget.projectId}'),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
              ),
            ),
            const SizedBox(width: 10),
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
    if (_webhooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/webhooks.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            const SizedBox(height: 16),
            Text('Aucun webhook', style: TextStyle(fontSize: 16, color: ThemeHelper.textDim(context))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _webhooks.length,
      itemBuilder: (context, index) {
        final wh = _webhooks[index];
        final url = (wh['url'] as String?) ?? '';
        final events = ((wh['events'] as String?) ?? '[]').isEmpty ? <String>[] : (jsonDecode((wh['events'] as String?) ?? '[]') as List).cast<String>();
        final active = wh['is_active'] == 1;
        return _WebhookCard(
          name: (wh['name'] as String?) ?? 'Webhook',
          url: url,
          events: events,
          status: active ? 'active' : 'inactive',
          lastTrigger: (wh['created_at'] as String?) ?? 'jamais',
          onCopy: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('URL copiée !'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            );
          },
          onToggle: () async {
            await _backend.updateWebhook(wh['id'] as String, {'is_active': active ? 0 : 1});
            _loadWebhooks();
          },
          onDelete: () async {
            await _backend.deleteWebhook(widget.projectId, wh['id'] as String);
            _loadWebhooks();
          },
        );
      },
    );
  }
}

class _WebhookCard extends StatelessWidget {
  final String name;
  final String url;
  final List<String> events;
  final String status;
  final String lastTrigger;
  final VoidCallback onCopy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _WebhookCard({required this.name, required this.url, required this.events, required this.status, required this.lastTrigger, required this.onCopy, required this.onToggle, required this.onDelete});

  Color _statusColor(BuildContext context) => status == 'active' ? AppColors.success : ThemeHelper.textDim(context);

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
                          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                          const SizedBox(height: 2),
                          Text('Dernier: ${lastTrigger}', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(context), fontWeight: FontWeight.w600)),
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
                          child: Text(url, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
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
                  children: events.map((e) => Container(
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
