import 'package:flutter/material.dart';

class AllExecutionsScreen extends StatelessWidget {
  const AllExecutionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDCB6E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_rounded, color: Color(0xFFFDCB6E), size: 18),
              ),
              const SizedBox(width: 12),
              const Text('ALL EXECUTIONS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _ExecutionItem(project: 'ODA Market', name: 'User Registration', trigger: 'webhook', duration: '2.3s', success: true),
                _ExecutionItem(project: 'ODA Market', name: 'Order Processing', trigger: 'webhook', duration: '1.8s', success: true),
                _ExecutionItem(project: 'ODA Seller', name: 'Payment Webhook', trigger: 'manual', duration: '0.5s', success: false),
                _ExecutionItem(project: 'WhatsApp Bot', name: 'Daily Backup', trigger: 'schedule', duration: '12.1s', success: true),
                _ExecutionItem(project: 'ODA Market', name: 'Stock Update', trigger: 'webhook', duration: '0.8s', success: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionItem extends StatelessWidget {
  final String project;
  final String name;
  final String trigger;
  final String duration;
  final bool success;
  const _ExecutionItem({required this.project, required this.name, required this.trigger, required this.duration, required this.success});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131921),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (success ? const Color(0xFF00B894) : const Color(0xFFE53E3E)).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(success ? Icons.check_rounded : Icons.close_rounded, color: success ? const Color(0xFF00B894) : const Color(0xFFE53E3E), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(project, style: const TextStyle(fontSize: 9, color: Color(0xFF6C5CE7))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Triggered by $trigger · $duration', style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: const Color(0xFF718096)),
        ],
      ),
    );
  }
}
