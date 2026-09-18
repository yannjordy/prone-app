import 'package:flutter/material.dart';

class ConsoleScreen extends StatefulWidget {
  final String projectId;
  const ConsoleScreen({super.key, required this.projectId});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ConsoleMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_ConsoleMessage(
      type: _MessageType.system,
      text: 'Connected to ConnectFlow',
      timestamp: DateTime.now(),
    ));
    _messages.add(_ConsoleMessage(
      type: _MessageType.info,
      text: 'Type "help" to see available commands',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFA29BFE).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.terminal_rounded, color: Color(0xFFA29BFE), size: 18),
              ),
              const SizedBox(width: 12),
              const Text('CONSOLE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Connected', style: TextStyle(fontSize: 10, color: Color(0xFF00B894))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2D3748)),
          const SizedBox(height: 8),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessage(msg);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131921),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D3748)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF6C5CE7), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type a command...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: _executeCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  color: const Color(0xFF6C5CE7),
                  onPressed: () => _executeCommand(_controller.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMessage(_ConsoleMessage msg) {
    final color = switch (msg.type) {
      _MessageType.command => const Color(0xFF6C5CE7),
      _MessageType.success => const Color(0xFF00B894),
      _MessageType.error => const Color(0xFFE53E3E),
      _MessageType.warning => const Color(0xFFFDCB6E),
      _MessageType.info => const Color(0xFF00CEC9),
      _MessageType.system => const Color(0xFF718096),
    };

    final prefix = switch (msg.type) {
      _MessageType.command => '> ',
      _MessageType.success => 'ok ',
      _MessageType.error => 'error ',
      _MessageType.warning => 'warn ',
      _MessageType.info => '  ',
      _MessageType.system => '  ',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$prefix${msg.text}',
        style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: color),
      ),
    );
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;

    setState(() {
      _messages.add(_ConsoleMessage(
        type: _MessageType.command,
        text: command,
        timestamp: DateTime.now(),
      ));
    });

    _controller.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        if (command.toLowerCase() == 'help') {
          _messages.add(_ConsoleMessage(type: _MessageType.info, text: 'Commands: status, errors, logs, ping, clear', timestamp: DateTime.now()));
        } else if (command.toLowerCase() == 'status') {
          _messages.add(_ConsoleMessage(type: _MessageType.success, text: 'All systems operational. Uptime: 99.9%', timestamp: DateTime.now()));
        } else if (command.toLowerCase() == 'errors') {
          _messages.add(_ConsoleMessage(type: _MessageType.warning, text: '3 warnings in last 24h', timestamp: DateTime.now()));
          _messages.add(_ConsoleMessage(type: _MessageType.error, text: 'Payment timeout at 14:32', timestamp: DateTime.now()));
        } else if (command.toLowerCase() == 'ping') {
          _messages.add(_ConsoleMessage(type: _MessageType.success, text: 'Pong! 45ms', timestamp: DateTime.now()));
        } else if (command.toLowerCase() == 'clear') {
          _messages.clear();
        } else {
          _messages.add(_ConsoleMessage(type: _MessageType.error, text: 'Unknown command: $command', timestamp: DateTime.now()));
        }
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }
}

enum _MessageType { command, success, error, warning, info, system }

class _ConsoleMessage {
  final _MessageType type;
  final String text;
  final DateTime timestamp;
  _ConsoleMessage({required this.type, required this.text, required this.timestamp});
}
