import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import '../../app/app.dart';
import '../../core/commands/command_library.dart';
import '../../core/security/bot_protector.dart';
import '../../core/backend/backend_adapter.dart';
import '../../core/local/local_backend.dart';
import '../../core/utils/photo_picker_helper.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/notifications/error_store.dart';
import '../../core/backend/request_log.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _controller = TextEditingController();
  final _commandSearchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _showCommands = false;
  bool _showSettings = false;
  bool _isTyping = false;
  bool _isAdmin = true;
  int? _selectedMessageIndex;
  String _selectedCategory = 'All';
  final _backend = LocalBackend();
  final _protector = BotProtector();

  String _projectName = 'Projet';
  String _projectInitials = 'P';
  Color _projectColor = AppColors.primary;
  bool _isConnected = true;
  bool _lastCmdOffline = false;
  int _unreadAlerts = 0;
  int _pendingCommands = 0;
  String _commandQuery = '';
  String _projectApiKey = '';
  String _backendUrl = '';
  String _backendType = 'generic';
  Uint8List? _projectImageBytes;
  String _userRole = 'admin';
  bool _isMentioning = false;

  final List<_Member> _members = [
    _Member(name: 'Bot', initials: 'BOT', color: Color(0xFF55EFC4), isOnline: true, isBot: true),
  ];

  _Member? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _Member(name: 'Vous', initials: 'VO', color: AppColors.primary, isOnline: true);
    _controller.addListener(() {
      final text = _controller.text;
      final hasMention = text.contains(RegExp(r'@\w+\s*$'));
      if (hasMention != _isMentioning) {
        setState(() => _isMentioning = hasMention);
      }
    });
    _loadProjectData();
    _refreshAlertCount();
    _refreshPendingCount();
  }

  Future<void> _refreshAlertCount() async {
    final n = await BackendErrorStore.instance.unreadCount(widget.projectId);
    if (mounted) setState(() => _unreadAlerts = n);
  }

  Future<void> _refreshPendingCount() async {
    final items = await OfflineQueue.instance.pending(widget.projectId);
    if (mounted) setState(() => _pendingCommands = items.length);
  }

  void _showAlertsSheet() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.97), border: Border(top: BorderSide(color: borderColor))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Row(children: [
                SvgPicture.asset('assets/icons/bell.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                const SizedBox(width: 10),
                Text('Alertes backend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ThemeHelper.text(context))),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await BackendErrorStore.instance.clear(widget.projectId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refreshAlertCount();
                  },
                  child: SvgPicture.asset('assets/icons/trash.svg', width: 17, height: 17, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                ),
              ]),
              const SizedBox(height: 14),
              Flexible(child: _buildAlertsList(ctx)),
            ]),
          ),
        ),
      ),
    ).then((_) {
      BackendErrorStore.instance.markAllRead(widget.projectId);
      _refreshAlertCount();
    });
  }

  Widget _buildAlertsList(BuildContext ctx) {
    return FutureBuilder<List<BackendErrorEntry>>(
      future: BackendErrorStore.instance.recent(widget.projectId),
      builder: (context, snap) {
        final items = snap.data ?? const <BackendErrorEntry>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Column(children: [
                SvgPicture.asset('assets/icons/check-circle.svg', width: 40, height: 40, colorFilter: const ColorFilter.mode(AppColors.success, BlendMode.srcIn)),
                const SizedBox(height: 12),
                Text('Aucune alerte', style: TextStyle(fontSize: 14, color: ThemeHelper.textDim(context))),
              ]),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = items[i];
            final color = switch (e.level) {
              ErrorLevel.error => AppColors.error,
              ErrorLevel.warning => AppColors.warning,
              ErrorLevel.offline => AppColors.primary,
            };
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
                    child: Text(e.level.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_formatAlertTime(e.at), style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context)))),
                ]),
                const SizedBox(height: 8),
                Text(e.message, style: TextStyle(fontSize: 13, height: 1.4, color: ThemeHelper.text(context))),
                if (e.command != null && e.command!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.command!, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                ],
              ]),
            );
          },
        );
      },
    );
  }

  String _formatAlertTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return "a l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return '${t.day}/${t.month}/${t.year} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadProjectData() async {
    final projects = await _backend.getProjects();
    final project = projects.where((p) => p['id'] == widget.projectId).toList();
    if (project.isNotEmpty) {
      final p = project.first;
      final name = (p['name'] as String?) ?? 'Projet';
      final hash = name.hashCode;
      final colors = [AppColors.primary, const Color(0xFF00CEC9), const Color(0xFF00B894), const Color(0xFF55EFC4), const Color(0xFF6C5CE7), const Color(0xFFE17055), const Color(0xFF0984E3)];
      Uint8List? imageBytes;
      try {
        final photo = (p['photo'] as String?) ?? '';
        if (photo.isNotEmpty) {
          imageBytes = base64Decode(photo);
        }
      } catch (_) {}
      setState(() {
        _projectName = name;
        _projectInitials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
        _projectApiKey = (p['api_key'] as String?) ?? '';
        _backendUrl = (p['backend_url'] as String?) ?? '';
        _projectColor = colors[hash.abs() % colors.length];
        _backendType = BackendAdapter.detect(_backendUrl, null).name;
        _projectImageBytes = imageBytes;
      });
    }
    final members = await _backend.getMembersByProject(widget.projectId);
    members.sort((a, b) {
      final dateA = (a['created_at'] as String?) ?? '';
      final dateB = (b['created_at'] as String?) ?? '';
      return dateA.compareTo(dateB);
    });
    if (mounted) {
      final memberList = <_Member>[];
      Uint8List? botPhoto;
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedBotPhoto = prefs.getString('bot_photo_${widget.projectId}');
        if (savedBotPhoto != null && savedBotPhoto.isNotEmpty) {
          botPhoto = base64Decode(savedBotPhoto);
        }
      } catch (_) {}
      final botName = await _getBotName();
      memberList.add(_Member(name: botName, initials: 'BOT', color: const Color(0xFF55EFC4), isOnline: true, isBot: true, photo: botPhoto));
      for (final m in members) {
        final name = (m['name'] as String?) ?? '';
        final email = (m['email'] as String?) ?? '';
        final role = (m['role'] as String?) ?? 'viewer';
        final photo = (m['photo'] as String?) ?? '';
        Uint8List? photoBytes;
        try { if (photo.isNotEmpty) photoBytes = base64Decode(photo); } catch (_) {}
        final hash = name.hashCode;
        final colors = [AppColors.primary, const Color(0xFF00CEC9), const Color(0xFF00B894), const Color(0xFF6C5CE7), const Color(0xFFE17055)];
        final colorVal = colors[hash.abs() % colors.length];
        final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
        memberList.add(_Member(name: name.isEmpty ? email : name, initials: initials.isEmpty ? '?' : initials, color: colorVal, isOnline: true, photo: photoBytes, role: role, email: email));
      }
      // Current user is the first member (oldest = admin)
      if (members.isNotEmpty) {
        final firstMember = members.first;
        _currentUser = _Member(
          name: (firstMember['name'] as String?) ?? 'Vous',
          initials: ((firstMember['name'] as String?) ?? 'V').split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase(),
          color: AppColors.primary,
          isOnline: true,
          role: (firstMember['role'] as String?) ?? 'admin',
          email: (firstMember['email'] as String?) ?? '',
        );
      }
      setState(() {
        _members.clear();
        _members.addAll(memberList);
        _userRole = (members.isNotEmpty ? (members.first['role'] as String?) : null) ?? 'admin';
        _isAdmin = _userRole == 'admin';
      });
    }
    final msgs = await _backend.getMessages(widget.projectId);
    setState(() {
      _messages.clear();
      for (final m in msgs) {
        final isBot = m['is_bot'] == 1;
        _messages.add(_ChatMessage(
          sender: isBot ? _members.first : _currentUser!,
          text: (m['content'] as String?) ?? '',
          timestamp: DateTime.tryParse((m['created_at'] as String?) ?? '') ?? DateTime.now(),
          id: (m['id'] as String?) ?? '',
        ));
      }
    });
    if (_messages.isEmpty) {
      _messages.add(_ChatMessage(
        sender: _members.first,
        text: 'Bienvenue sur $_projectName !\n\nTapez /help pour voir les commandes disponibles.',
        timestamp: DateTime.now(),
      ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
    // Start bot protector monitoring
    _protector.startMonitoring(_backendUrl, _projectApiKey, _backendType, _onSecurityAlert);
  }

  void _onSecurityAlert(SecurityAlert alert) {
    if (!mounted) return;
    final levelMap = {
      AlertLevel.info: MessageLevel.info,
      AlertLevel.warning: MessageLevel.warning,
      AlertLevel.error: MessageLevel.error,
      AlertLevel.critical: MessageLevel.critical,
      AlertLevel.offline: MessageLevel.offline,
    };
    setState(() {
      _messages.add(_ChatMessage(
        sender: _members.first,
        text: '${alert.title}\n\n${alert.message}${alert.details != null ? "\n\n${alert.details}" : ""}',
        timestamp: DateTime.now(),
        level: levelMap[alert.level] ?? MessageLevel.info,
        alertTitle: alert.title,
      ));
    });
    final errorLevel = switch (alert.level) {
      AlertLevel.offline => ErrorLevel.offline,
      AlertLevel.info => ErrorLevel.warning,
      _ => ErrorLevel.error,
    };
    BackendErrorStore.instance
        .record(widget.projectId, '${alert.title} — ${alert.message}', level: errorLevel)
        .then((_) => _refreshAlertCount());
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _protector.stopMonitoring();
    _controller.dispose();
    _commandSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var filteredCommands = _selectedCategory == 'All'
        ? CommandLibrary.commands
        : CommandLibrary.commands.where((c) => c.category == _selectedCategory).toList();
    final q = _commandQuery.trim().toLowerCase().replaceFirst(RegExp(r'^/'), '');
    if (q.isNotEmpty) {
      filteredCommands = filteredCommands
          .where((c) => c.name.toLowerCase().contains(q) || c.description.toLowerCase().contains(q))
          .toList();
    }
    final categories = ['All', ...CommandLibrary.commands.map((c) => c.category).toSet()];

    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Stack(
        children: [
           Column(
            children: [
              const SizedBox(height: 8),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: ThemeHelper.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThemeHelper.borderLight(context)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/projects'),
                        child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(ThemeHelper.text(context), BlendMode.srcIn)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: _projectImageBytes == null ? LinearGradient(colors: [_projectColor, _projectColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: _projectImageBytes != null
                            ? ClipOval(child: Image.memory(_projectImageBytes!, width: 40, height: 40, fit: BoxFit.cover))
                            : Center(child: Text(_projectInitials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_projectName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: _isConnected ? AppColors.success : AppColors.error,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: (_isConnected ? AppColors.success : AppColors.error).withOpacity(0.5), blurRadius: 4)],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(_isConnected ? '${_members.length} membres • En ligne' : 'Hors ligne', style: TextStyle(fontSize: 12, color: _isConnected ? AppColors.success : AppColors.error)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Backend error alerts
                      GestureDetector(
                        onTap: () => _showAlertsSheet(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _unreadAlerts > 0 ? AppColors.error.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset('assets/icons/bell.svg', width: 19, height: 19,
                                colorFilter: ColorFilter.mode(_unreadAlerts > 0 ? AppColors.error : ThemeHelper.textDim(context), BlendMode.srcIn)),
                              if (_unreadAlerts > 0)
                                Positioned(
                                  right: 4, top: 4,
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, border: Border.all(color: ThemeHelper.surface(context), width: 1.5)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 3-dot menu
                      GestureDetector(
                        onTap: () => setState(() => _showSettings = !_showSettings),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _showSettings ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: SvgPicture.asset('assets/icons/more.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(_showSettings ? AppColors.primary : ThemeHelper.textDim(context), BlendMode.srcIn)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) return _buildTypingIndicator();
                    return _buildMessage(_messages[index]);
                  },
                ),
              ),
              SizedBox(height: _pendingCommands > 0 && _userRole != 'viewer' ? 128 : 80),
            ],
          ),
          // Settings dropdown
          if (_showSettings)
            GestureDetector(
              onTap: () => setState(() => _showSettings = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),

          if (_showSettings)
            Positioned(
              top: 68,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: ThemeHelper.surface(context).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeHelper.borderLight(context)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsItem(icon: 'users.svg', label: 'Membres', onTap: () {
                          setState(() => _showSettings = false);
                          _showMembersSheet();
                        }),
                        _SettingsItem(icon: 'terminal.svg', label: 'API Key', onTap: () {
                          setState(() => _showSettings = false);
                          _showApiKeySheet();
                        }),
                        _SettingsItem(icon: 'connections.svg', label: 'Backend', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/connections');
                        }),
                        _SettingsItem(icon: 'monitoring.svg', label: 'Monitoring', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/monitoring');
                        }),
                        _SettingsItem(icon: 'database.svg', label: 'Tables', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/tables');
                        }),
                        _SettingsItem(icon: 'bell.svg', label: 'Alertes backend', onTap: () {
                          setState(() => _showSettings = false);
                          _showAlertsSheet();
                        }),
                        _SettingsItem(icon: 'logs.svg', label: 'Logs', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/logs');
                        }),
                        _SettingsItem(icon: 'actions.svg', label: 'Actions API', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/actions');
                        }),
                        _SettingsItem(icon: 'workflows.svg', label: 'Workflows', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/workflows');
                        }),
                        _SettingsItem(icon: 'webhooks.svg', label: 'Webhooks', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/webhooks');
                        }),
                        _SettingsItem(icon: 'executions.svg', label: 'Executions', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/executions');
                        }),
                        Divider(color: ThemeHelper.borderLight(context), height: 1),
                        _SettingsItem(icon: 'settings.svg', label: 'Paramètres', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/settings');
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Commands dropdown
          if (_showCommands)
            GestureDetector(
              onTap: () => setState(() => _showCommands = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),

          if (_showCommands)
            Positioned(
              bottom: 90, left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      color: ThemeHelper.surface(context).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThemeHelper.borderLight(context)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            height: 40,
                            decoration: BoxDecoration(
                              color: ThemeHelper.bg(context).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThemeHelper.borderLight(context)),
                            ),
                            child: Row(children: [
                              SvgPicture.asset('assets/icons/search.svg', width: 15, height: 15,
                                colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _commandSearchController,
                                  style: TextStyle(fontSize: 13, color: ThemeHelper.text(context)),
                                  decoration: InputDecoration(
                                    hintText: 'Rechercher une commande...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context)),
                                  ),
                                  onChanged: (v) => setState(() => _commandQuery = v),
                                ),
                              ),
                              if (_commandQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () { _commandSearchController.clear(); setState(() => _commandQuery = ''); },
                                  child: SvgPicture.asset('assets/icons/x.svg', width: 14, height: 14,
                                    colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                                ),
                            ]),
                          ),
                        ),
                        Container(
                          height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: categories.map((cat) => GestureDetector(
                              onTap: () => setState(() => _selectedCategory = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8, top: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == cat ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _selectedCategory == cat ? AppColors.primary.withOpacity(0.3) : AppColors.border),
                                ),
                                child: Text(cat, style: TextStyle(fontSize: 12, color: _selectedCategory == cat ? AppColors.primary : ThemeHelper.textDim(context), fontWeight: _selectedCategory == cat ? FontWeight.w600 : FontWeight.w400)),
                              ),
                            )).toList(),
                          ),
                        ),
                        Expanded(
                          child: filteredCommands.isEmpty
                              ? Center(
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    SvgPicture.asset('assets/icons/search.svg', width: 34, height: 34,
                                      colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                                    const SizedBox(height: 12),
                                    Text('Aucune commande', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                                  ]),
                                )
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            itemCount: filteredCommands.length,
                            itemBuilder: (context, index) {
                              final cmd = filteredCommands[index];
                              return _MenuBtn(icon: cmd.icon, label: '/${cmd.name}', description: cmd.description, onTap: () {
                                setState(() => _showCommands = false);
                                if (cmd.params == null || cmd.params!.isEmpty) {
                                  _sendCommand('/${cmd.name}');
                                } else {
                                  _controller.text = '/${cmd.name} ';
                                  _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                                  FocusScope.of(context).requestFocus(FocusNode());
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // @ Mention autocomplete
          if (_isMentioning && _userRole != 'viewer')
            Positioned(
              bottom: 80, left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: ThemeHelper.surface(context).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeHelper.borderLight(context)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _members.where((m) => !m.isBot && m.name.toLowerCase().contains(_getMentionQuery())).length,
                      itemBuilder: (context, index) {
                        final filtered = _members.where((m) => !m.isBot && m.name.toLowerCase().contains(_getMentionQuery())).toList();
                        final m = filtered[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectMention(m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(children: [
                                _buildAvatar(m, size: 32),
                                const SizedBox(width: 10),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                                  Text(m.email ?? '', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                                ]),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Offline queue chip
          if (_pendingCommands > 0 && _userRole != 'viewer')
            Positioned(
              bottom: 82, left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: GestureDetector(
                    onTap: _retryPending,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: (_isConnected ? AppColors.success : AppColors.warning).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (_isConnected ? AppColors.success : AppColors.warning).withOpacity(0.45)),
                      ),
                      child: Row(children: [
                        SvgPicture.asset('assets/icons/warning.svg', width: 15, height: 15,
                          colorFilter: ColorFilter.mode(_isConnected ? AppColors.success : AppColors.warning, BlendMode.srcIn)),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _isConnected
                                ? '$_pendingCommands commande(s) en attente — appuyer pour envoyer'
                                : 'Hors ligne · $_pendingCommands commande(s) en attente',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ThemeHelper.text(context)),
                          ),
                        ),
                        SvgPicture.asset('assets/icons/refresh.svg', width: 15, height: 15,
                          colorFilter: ColorFilter.mode(_isConnected ? AppColors.success : AppColors.warning, BlendMode.srcIn)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

          // Input bar
          if (_userRole != 'viewer')
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeHelper.surface(context).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ThemeHelper.borderLight(context)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _showCommands = !_showCommands;
                          if (_showCommands) { _commandSearchController.clear(); _commandQuery = ''; }
                        }),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: _showCommands ? AppColors.primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(50)),
                          child: Center(child: SvgPicture.asset('assets/icons/menu.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(_showCommands ? AppColors.primary : ThemeHelper.textDim(context), BlendMode.srcIn))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(fontSize: 14, color: _isMentioning ? AppColors.success : ThemeHelper.text(context)),
                          decoration: InputDecoration(hintText: '/help ou @nom', border: InputBorder.none, hintStyle: TextStyle(color: ThemeHelper.textDim(context))),
                          onSubmitted: (text) => _sendCommand(text),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _sendCommand(_controller.text),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(50)),
                          child: Center(child: SvgPicture.asset('assets/icons/send.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Membres du projet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 4),
                Text('${_members.length} membres', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                // Overlapping circles chain
                SizedBox(
                  height: 60,
                  child: Center(
                    child: SizedBox(
                      width: (_members.length * 30.0) + 10,
                      height: 56,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: List.generate(_members.length, (index) {
                          final m = _members[index];
                          return Positioned(
                            left: index * 30.0,
                            child: GestureDetector(
                              onTap: () { Navigator.pop(context); _showMemberProfileModal(m); },
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ThemeHelper.surface(context), width: 3),
                                ),
                                child: ClipOval(child: m.photo != null && m.photo!.isNotEmpty
                                    ? Image.memory(m.photo!, width: 50, height: 50, fit: BoxFit.cover)
                                    : Container(
                                        width: 50, height: 50,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(child: Text(m.initials, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                                      ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Name labels row
                SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: (_members.length * 30.0) + 10,
                      child: Row(
                        children: List.generate(_members.length, (index) {
                          final m = _members[index];
                          return SizedBox(
                            width: 56,
                            child: Center(child: Text(m.name.split(' ').first, style: TextStyle(fontSize: 8, color: ThemeHelper.textDim(context)), overflow: TextOverflow.ellipsis)),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Invite buttons
                if (_userRole == 'admin' || _userRole == 'editor')
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () { Navigator.pop(context); _inviteMember(); },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.person_add, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('Email', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () { Navigator.pop(context); _showQRCode(); },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.qr_code, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Text('QR Code', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Fermer', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMemberProfileModal(_Member member) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: ScaleTransition(scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack), child: child)),
      pageBuilder: (ctx, a1, a2) {
        return Stack(children: [
          GestureDetector(onTap: () => Navigator.pop(ctx), child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.black.withOpacity(0.4))))),
          Center(child: Material(color: Colors.transparent, child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildAvatar(member, size: 80),
              const SizedBox(height: 16),
              Text(member.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 4),
              if (member.email != null && member.email!.isNotEmpty)
                Text(member.email!, style: TextStyle(fontSize: 13, color: textDimColor)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: member.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text((member.role ?? 'Membre').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: member.color)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: member.isOnline ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(member.isOnline ? 'En ligne' : 'Hors ligne', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: member.isOnline ? AppColors.success : Colors.grey)),
                ),
              ]),
              if (member.isBot) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () { Navigator.pop(ctx); _showBotSettingsModal(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.settings, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Configurer le Bot', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Center(child: Text('Fermer', style: TextStyle(color: textDimColor, fontSize: 14))),
              )),
            ]),
          ))),
        ]);
      },
    );
  }

  void _showBotSettingsModal() async {
    final currentName = await _getBotName();
    final nameController = TextEditingController(text: currentName);
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    Uint8List? selectedPhoto;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('bot_photo_${widget.projectId}');
      if (saved != null && saved.isNotEmpty) selectedPhoto = base64Decode(saved);
    } catch (_) {}

    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: ScaleTransition(scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack), child: child)),
      pageBuilder: (ctx, a1, a2) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => Stack(children: [
            GestureDetector(onTap: () => Navigator.pop(ctx), child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.black.withOpacity(0.4))))),
            Center(child: Material(color: Colors.transparent, child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Paramètres du Bot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 20),
                // Bot photo
                GestureDetector(
                  onTap: () async {
                    final picker = PhotoPickerHelper();
                    final bytes = await picker.pickImage();
                    if (bytes != null) setModalState(() => selectedPhoto = Uint8List.fromList(bytes));
                  },
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2)),
                    child: ClipOval(child: selectedPhoto != null
                        ? Image.memory(selectedPhoto!, width: 80, height: 80, fit: BoxFit.cover)
                        : Container(
                            width: 80, height: 80,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF55EFC4), Color(0xFF00B894)])),
                            child: const Center(child: Text('BOT', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Appuyez pour changer la photo', style: TextStyle(fontSize: 11, color: textDimColor)),
                const SizedBox(height: 20),
                // Bot name
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Nom du bot',
                    labelStyle: TextStyle(color: textDimColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                    child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14))),
                  ))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('bot_name_${widget.projectId}', nameController.text.trim());
                    if (selectedPhoto != null) {
                      await prefs.setString('bot_photo_${widget.projectId}', base64Encode(selectedPhoto!));
                    }
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadProjectData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bot mis à jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }, child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                  ))),
                ]),
              ]),
            ))),
          ]),
        );
      },
    );
  }

  void _inviteMember() {
    final emailController = TextEditingController();
    String selectedRole = 'Membre';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: ThemeHelper.surface(context).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                  const SizedBox(height: 8),
                  Text('L\'utilisateur doit avoir un compte Prone', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                  const SizedBox(height: 20),
                  // Email input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adresse email', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
                        decoration: InputDecoration(
                          hintText: 'jean@example.com',
                          hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)),
                          filled: true,
                          fillColor: ThemeHelper.bg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeHelper.borderLight(context))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Role selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rôle', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRoleChip('Admin', 'Admin', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                          const SizedBox(width: 8),
                          _buildRoleChip('Éditeur', 'Membre', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                          const SizedBox(width: 8),
                          _buildRoleChip('Lecteur', 'Lecteur', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                      const SizedBox(width: 12),
                      Expanded(child: GestureDetector(
                        onTap: () async {
                          if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                            final email = emailController.text.trim();
                            final name = email.split('@')[0];
                            final roleMap = {'Admin': 'admin', 'Membre': 'editor', 'Lecteur': 'viewer'};
                            final role = roleMap[selectedRole] ?? 'viewer';
                            final orgs = await _backend.getOrganizations();
                            if (orgs.isNotEmpty) {
                              await _backend.addMember(orgs.first['id'] as String, name, email, role, projectId: widget.projectId);
                            }
                            Navigator.pop(context);
                            _loadProjectData();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyée à $email (rôle: $selectedRole)'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                          }
                        },
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Envoyer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, String value, String selected, Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : ThemeHelper.bg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? AppColors.primary : ThemeHelper.textDim(context), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  void _showQRCode() {
    final inviteLink = 'prone://invite/${widget.projectId}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.asset('assets/icons/qr_code.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                  const SizedBox(width: 8),
                  Text('QR Code Partage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                ]),
                const SizedBox(height: 8),
                Text('Scannez pour intégrer ce projet', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                  ),
                  child: QrImageView(
                    data: inviteLink,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Color(0xFF181818)),
                    dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF181818)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                  child: Column(
                    children: [
                      Text('Lien d\'invitation', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                      const SizedBox(height: 4),
                      Text(inviteLink, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'monospace'), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteLink));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Lien copié !'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.copy, color: ThemeHelper.textDim(context), size: 16), const SizedBox(width: 8), Text('Copier', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteLink));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Lien d\'invitation copié ! Partagez-le.'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share, color: Colors.white, size: 16), const SizedBox(width: 8), Text('Partager', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Fermer', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApiKeySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('API Key', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Utilisez cette clé pour connecter votre backend', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                  child: Text(_projectApiKey.isNotEmpty ? _projectApiKey : 'Aucune clé configurée', style: const TextStyle(fontSize: 14, color: AppColors.primary, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Fermer', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_projectApiKey.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _projectApiKey));
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_projectApiKey.isNotEmpty ? 'API Key copiée !' : 'Aucune clé à copier'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('Copier', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageText(String text, bool isBot) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(@\w+)');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return RichText(
      text: TextSpan(
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
        style: TextStyle(fontSize: 14, color: ThemeHelper.text(context), height: 1.5, fontFamily: isBot ? 'monospace' : null),
      ),
    );
  }

  Widget _buildAlertBubble(_ChatMessage msg, int msgIndex, bool isBot, bool isCurrentUser) {
    final isSelected = _selectedMessageIndex == msgIndex;

    // Alert level colors
    Color bubbleColor;
    Color borderColor;
    Widget? alertIcon;

    switch (msg.level) {
      case MessageLevel.critical:
        bubbleColor = const Color(0xFFFF6B6B).withOpacity(0.12);
        borderColor = const Color(0xFFFF6B6B).withOpacity(0.4);
        alertIcon = const Icon(Icons.dangerous_outlined, size: 14, color: Color(0xFFFF6B6B));
        break;
      case MessageLevel.error:
        bubbleColor = const Color(0xFFFF4757).withOpacity(0.10);
        borderColor = const Color(0xFFFF4757).withOpacity(0.35);
        alertIcon = const Icon(Icons.error_outline, size: 14, color: Color(0xFFFF4757));
        break;
      case MessageLevel.warning:
        bubbleColor = const Color(0xFFFFA502).withOpacity(0.10);
        borderColor = const Color(0xFFFFA502).withOpacity(0.35);
        alertIcon = const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFFA502));
        break;
      case MessageLevel.offline:
        bubbleColor = Colors.white.withOpacity(0.08);
        borderColor = Colors.white.withOpacity(0.2);
        alertIcon = const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.white54);
        break;
      case MessageLevel.info:
        bubbleColor = isSelected
            ? AppColors.primary.withOpacity(0.08)
            : isCurrentUser ? AppColors.primary.withOpacity(0.15) : ThemeHelper.surface(context);
        borderColor = isSelected
            ? AppColors.primary.withOpacity(0.5)
            : isCurrentUser ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context);
        alertIcon = null;
        break;
    }

    // Alert title header
    Widget? header;
    if (msg.alertTitle != null) {
      header = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: msg.level == MessageLevel.critical ? const Color(0xFFFF6B6B).withOpacity(0.15)
              : msg.level == MessageLevel.error ? const Color(0xFFFF4757).withOpacity(0.12)
              : msg.level == MessageLevel.warning ? const Color(0xFFFFA502).withOpacity(0.12)
              : msg.level == MessageLevel.offline ? Colors.white.withOpacity(0.06)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (alertIcon != null) ...[alertIcon, const SizedBox(width: 4)],
          Flexible(child: Text(msg.alertTitle!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: msg.level == MessageLevel.critical ? const Color(0xFFFF6B6B)
                  : msg.level == MessageLevel.error ? const Color(0xFFFF4757)
                  : msg.level == MessageLevel.warning ? const Color(0xFFFFA502)
                  : msg.level == MessageLevel.offline ? Colors.white54
                  : AppColors.primary), overflow: TextOverflow.ellipsis)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isCurrentUser ? 16 : 4), bottomRight: Radius.circular(isCurrentUser ? 4 : 16)),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null) header,
        _buildMessageText(msg.text, isBot),
      ]),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    final isBot = msg.sender.isBot;
    final isCurrentUser = msg.sender == _currentUser;
    final msgIndex = _messages.indexOf(msg);

    // Find if this message is a reply to another
    _ChatMessage? repliedMsg;
    if (msg.replyToIndex != null && msg.replyToIndex! >= 0 && msg.replyToIndex! < _messages.length) {
      repliedMsg = _messages[msg.replyToIndex!];
    }

    return Dismissible(
      key: ValueKey('msg_$msgIndex'),
      direction: _userRole == 'viewer' ? DismissDirection.none : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        _showCommentDialog(msg);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SvgPicture.asset('assets/icons/edit.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(AppColors.success, BlendMode.srcIn)),
          const SizedBox(height: 4),
          Text('Commenter', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
      ),
      child: GestureDetector(
        onLongPressStart: _userRole == 'viewer' ? null : (details) {
          setState(() => _selectedMessageIndex = msgIndex);
          _showMessageOptions(msg, details.globalPosition);
        },
        child: AnimatedScale(
          scale: _selectedMessageIndex == msgIndex ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  Column(children: [
                    _buildAvatar(msg.sender, size: 36),
                    const SizedBox(height: 2),
                    Text(msg.sender.name.split(' ').first, style: TextStyle(fontSize: 9, color: ThemeHelper.textDim(context), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  ]),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Reply bubble
                      if (repliedMsg != null)
                        GestureDetector(
                          onTap: () {
                            // Scroll to the original message
                            if (_scrollController.hasClients) {
                              final targetOffset = msg.replyToIndex! * 100.0;
                              _scrollController.animateTo(targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(left: BorderSide(color: AppColors.success, width: 3)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(repliedMsg.sender.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                              const SizedBox(height: 2),
                              Text(repliedMsg.text, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        ),
                      // Message bubble
                      _buildAlertBubble(msg, msgIndex, isBot, isCurrentUser),
                      const SizedBox(height: 4),
                      Text('${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                    ],
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 10),
                  Column(children: [
                    _buildAvatar(msg.sender, size: 36),
                    const SizedBox(height: 2),
                    Text(msg.sender.name.split(' ').first, style: TextStyle(fontSize: 9, color: ThemeHelper.textDim(context), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCommentDialog(_ChatMessage msg) {
    final commentController = TextEditingController();
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: ScaleTransition(scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack), child: child)),
      pageBuilder: (ctx, a1, a2) {
        return Stack(children: [
          GestureDetector(onTap: () => Navigator.pop(ctx), child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.black.withOpacity(0.4))))),
          Center(child: Material(color: Colors.transparent, child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SvgPicture.asset('assets/icons/edit.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                const SizedBox(width: 8),
                Text('Commenter le message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(10)),
                child: Text(msg.text, style: TextStyle(fontSize: 13, color: textDimColor), maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(hintText: 'Votre commentaire...', hintStyle: TextStyle(color: textDimColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary))),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                  child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14))),
                ))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () {
                  if (commentController.text.trim().isNotEmpty) {
                    final replyIdx = _messages.indexOf(msg);
                    Navigator.pop(ctx);
                    _sendComment(commentController.text.trim(), replyIdx);
                  }
                }, child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('Envoyer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ))),
              ]),
            ]),
          ))),
        ]);
      },
    );
  }

  void _sendComment(String text, int replyToIndex) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(sender: _currentUser!, text: text, timestamp: DateTime.now(), replyToIndex: replyToIndex));
    });
    _controller.clear();
    try {
      await _backend.sendMessage(widget.projectId, text, sender: 'user');
    } catch (_) {}
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _showMessageOptions(_ChatMessage msg, Offset position) {
    final surfaceColor = ThemeHelper.surface(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () { Navigator.pop(ctx); setState(() => _selectedMessageIndex = null); },
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
              ),
            ),
            Positioned(
              top: position.dy - 56,
              left: position.dx - 60,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: surfaceColor.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          Navigator.pop(ctx);
                          setState(() => _selectedMessageIndex = null);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Message copie'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                        },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SvgPicture.asset('assets/icons/copy.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                          const SizedBox(width: 4),
                          Text('Copier', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () async {
                            final idx = _selectedMessageIndex ?? 0;
                            final msgId = _messages[idx].id;
                            Navigator.pop(ctx);
                            if (msgId != null && msgId.isNotEmpty) {
                              await _backend.deleteMessage(msgId);
                            }
                            if (!mounted) return;
                            setState(() {
                              _messages.removeAt(idx);
                              _selectedMessageIndex = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Message supprime'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SvgPicture.asset('assets/icons/trash.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                            const SizedBox(width: 4),
                            Text('Supprimer', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) => setState(() => _selectedMessageIndex = null));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_projectColor, _projectColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(child: Text(_projectInitials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: ThemeHelper.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: ThemeHelper.borderLight(context))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [_TypingDot(delay: 0), const SizedBox(width: 4), _TypingDot(delay: 200), const SizedBox(width: 4), _TypingDot(delay: 400)]),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProjectStatus(String status, String type) async {
    await _backend.updateProjectStatus(widget.projectId, status, statusType: type);
  }

  Future<String> _executeRealCommand(String command) async {
    _lastCmdOffline = false;
    if (_backendUrl.isEmpty) {
      _updateProjectStatus('Backend non configure', 'warning');
      return '⚠️ Aucun backend configuré.\nConnectez un backend dans les paramètres du projet.';
    }
    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase().replaceFirst('/', '');
    final args = parts.sublist(1);

    try {
      if (cmd == 'users') {
        if (args.isNotEmpty) {
          final field = args[0].contains('@') ? 'email' : 'name';
          return await _searchTable('users', field, args[0]);
        }
        return await _fetchTable('users', limit: 50);
      } else if (cmd == 'products' || cmd == 'produits') {
        if (args.isNotEmpty) return await _searchTable('products', 'name', args.join(' '));
        return await _fetchTable('products', limit: 50);
      } else if (cmd == 'orders' || cmd == 'commandes') {
        if (args.isNotEmpty) return await _searchTable('orders', 'id', args[0]);
        return await _fetchTable('orders', limit: 50);
      } else if (cmd == 'count') {
        if (args.isEmpty) return '❌ Usage: /count <table>';
        return await _countTable(args[0]);
      } else if (cmd == 'last') {
        if (args.isEmpty) return '❌ Usage: /last <table> [limit]';
        final limit = args.length > 1 ? int.tryParse(args[1]) ?? 5 : 5;
        return await _fetchTable(args[0], limit: limit.clamp(1, 100));
      } else if (cmd == 'search') {
        if (args.length < 3) return '❌ Usage: /search <table> <champ> <valeur>';
        return await _searchTable(args[0], args[1], args.sublist(2).join(' '));
      } else if (cmd == 'schema') {
        if (args.isEmpty) return '❌ Usage: /schema <table>';
        return await _fetchSchema(args[0]);
      } else if (cmd == 'table') {
        if (args.isEmpty) return '❌ Usage: /table <nom>';
        return await _fetchTable(args[0], limit: 20);
      }
      return '❌ Commande inconnue: "$command"\n\nTapez /help pour les commandes disponibles.';
    } catch (e) {
      final offline = e is DioException && BackendAdapter.isOfflineError(e);
      _lastCmdOffline = offline;
      if (offline) {
        setState(() => _isConnected = false);
        await BackendErrorStore.instance.record(widget.projectId, 'Backend inaccessible — connexion impossible', command: command, level: ErrorLevel.offline);
        return '⚠️ Hors ligne — le backend ne repond pas.\n\nLa commande est mise en file d\'attente et sera renvoyee automatiquement.';
      }
      _updateProjectStatus('Erreur: $e', 'error');
      await BackendErrorStore.instance.record(widget.projectId, '$e', command: command, level: ErrorLevel.error);
      _refreshAlertCount();
      return '❌ Erreur backend: $e';
    }
  }

  Future<String> _fetchTable(String table, {int limit = 50}) async {
    final clean = _backendUrl.replaceAll(RegExp(r'/+$'), '');
    String url;
    Map<String, String> headers;

    if (_backendType == 'supabase') {
      url = '$clean/rest/v1/$table?select=*&limit=$limit';
      headers = {'apikey': _projectApiKey, 'Authorization': 'Bearer $_projectApiKey'};
    } else {
      url = '$clean/$table';
      headers = {};
      if (_projectApiKey.isNotEmpty) headers['Authorization'] = 'Bearer $_projectApiKey';
      headers['Content-Type'] = 'application/json';
    }

    final dio = Dio();
    final resp = await dio.get(url,
      options: Options(headers: headers, receiveTimeout: const Duration(seconds: 10), validateStatus: (s) => s != null && s < 500),
    );

    if (resp.statusCode != 200) {
      return '❌ Erreur ${resp.statusCode} sur "$table"\nURL: $url\n\nVérifiez que la table "$table" existe dans votre backend.';
    }

    final data = resp.data;
    if (data is List) {
      if (data.isEmpty) return 'ℹ️ Table "$table" vide ou inexistante.';
      final buf = StringBuffer('📋 **$table** (${data.length} entrées):\n\n');
      for (var i = 0; i < data.length && i < limit; i++) {
        final item = data[i];
        if (item is Map) {
          buf.writeln(_formatJsonList([item]));
          buf.writeln();
        }
      }
      return buf.toString();
    } else if (data is Map) {
      return '📋 **$table**:\n\n${_formatJsonMap(data)}';
    }
    return 'ℹ️ Réponse inattendue de $table';
  }

  Future<String> _countTable(String table) async {
    final res = await BackendAdapter.countRows(_backendUrl, _projectApiKey, table, type: _backendType);
    if (!res.ok) {
      if (res.offline) {
        _lastCmdOffline = true;
        return '⚠️ Hors ligne — impossible de compter "$table".';
      }
      return '❌ Erreur lors du comptage de "$table": ${res.error}';
    }
    final n = res.count!;
    final flag = res.approximate ? ' (minimum, plafonne a 1000)' : '';
    final cached = res.fromCache ? '\n⏱️ valeur en cache (< 60s)' : '';
    return '🔢 Nombre de lignes dans "$table": ${_formatNumber(n)}$flag$cached';
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<String> _searchTable(String table, String field, String value, {int limit = 25}) async {
    final res = await BackendAdapter.fetchRows(
      _backendUrl,
      _projectApiKey,
      table,
      limit: limit,
      offset: 0,
      type: _backendType,
      searchField: field,
      searchValue: value,
    );

    if (!res.ok) {
      if (res.offline) {
        _lastCmdOffline = true;
        return '⚠️ Hors ligne — recherche impossible dans "$table".';
      }
      return '❌ Erreur ${res.error} pour $field="$value" dans $table';
    }
    if (res.rows.isEmpty) return '🔍 Aucun résultat pour $field="$value" dans $table';

    final total = res.total;
    final buf = StringBuffer();
    if (total != null && total > res.rows.length) {
      buf.writeln('🔍 $field="$value" dans "$table" — ${_formatNumber(total)} correspondances, ${res.rows.length} affichées :');
    } else {
      buf.writeln('🔍 Résultats pour $field="$value" dans $table (${res.rows.length}) :');
    }
    buf.writeln();
    for (final item in res.rows) {
      buf.writeln(_formatJsonList([item]));
      buf.writeln();
    }
    if (total != null && total > res.rows.length) {
      buf.writeln('👉 Ouvrez Tables pour voir les ${_formatNumber(total - res.rows.length)} restantes.');
    }
    return buf.toString().trimRight();
  }

  Future<String> _fetchSchema(String table) async {
    final clean = _backendUrl.replaceAll(RegExp(r'/+$'), '');
    if (_backendType == 'supabase') {
      final url = '$clean/rest/v1/$table?select=*&limit=1';
      final headers = {'apikey': _projectApiKey, 'Authorization': 'Bearer $_projectApiKey'};
      final dio = Dio();
      final resp = await dio.get(url, options: Options(headers: headers, receiveTimeout: const Duration(seconds: 10)));
      if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
        final row = (resp.data as List).first as Map;
        final buf = StringBuffer('📐 Structure de la table "$table":\n\n');
        buf.writeln('╔════════════════╦════════════════╗');
        buf.writeln('║    Colonne     ║     Type       ║');
        buf.writeln('╠════════════════╬════════════════╣');
        for (final entry in row.entries) {
          final type = entry.value.runtimeType.toString();
          buf.writeln('║ ${entry.key.padRight(14)} ║ ${type.padRight(14)} ║');
        }
        buf.writeln('╚════════════════╩════════════════╝');
        return buf.toString();
      }
      return '❌ Impossible de récupérer le schéma de "$table"';
    }
    return '⚠️ Schéma non supporté pour ce type de backend';
  }

  void _sendCommand(String command) async {
    if (command.trim().isEmpty) return;

    final mentionMatch = RegExp(r'@(\w+)').firstMatch(command);
    if (mentionMatch != null) {
      final mentionedName = mentionMatch.group(1);
      final mentionedMember = _members.where((m) => m.name.toLowerCase() == mentionedName?.toLowerCase()).toList();
      if (mentionedMember.isNotEmpty) {
        _showMentionNotification(mentionedMember.first, command);
      }
    }

    setState(() {
      _showCommands = false;
      _messages.add(_ChatMessage(sender: _currentUser!, text: command, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _controller.clear();
    try {
      await _backend.sendMessage(widget.projectId, command, sender: 'user');
    } catch (e) {
      if (!mounted) return;
      setState(() { _isTyping = false; });
      return;
    }

    if (!command.startsWith('/')) {
      setState(() { _isTyping = false; });
      return;
    }

    if (_needsBackend(command) && _backendUrl.isNotEmpty && !_isConnected) {
      await OfflineQueue.instance.enqueue(widget.projectId, command);
      await _refreshPendingCount();
      if (!mounted) return;
      setState(() { _isTyping = false; });
      _botSay('⚠️ Hors ligne — commande mise en file d\'attente.\n\nElle sera renvoyee automatiquement des que le backend sera de nouveau joignable.\n\nFile d\'attente: $_pendingCommands commande(s).');
      return;
    }

    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final response = await _resolveCommand(command);
      if (response == '__NAV_TABLES__') {
        if (!mounted) return;
        setState(() => _isTyping = false);
        context.go('/projects/${widget.projectId}/tables');
        return;
      }
      if (response == '__NAV_ALERTS__') {
        if (!mounted) return;
        setState(() => _isTyping = false);
        _showAlertsSheet();
        return;
      }
      await _botSay(response);
      if (_lastCmdOffline) {
        final already = await OfflineQueue.instance.pending(widget.projectId);
        if (!already.any((c) => c.command == command)) {
          await OfflineQueue.instance.enqueue(widget.projectId, command);
        }
        await _refreshPendingCount();
      } else {
        if (_needsBackend(command) && mounted) setState(() => _isConnected = true);
        await _flushQueue();
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  bool _needsBackend(String command) {
    final lower = command.toLowerCase().trim();
    const remote = ['/users', '/products', '/produits', '/orders', '/commandes',
      '/count', '/last', '/search', '/schema', '/table', '/tables',
      '/status', '/test', '/health', '/ping', '/user', '/endpoints'];
    return remote.any((c) => lower == c || lower.startsWith('$c '));
  }

  Future<void> _botSay(String text) async {
    try {
      await _backend.sendMessage(widget.projectId, text, sender: 'bot');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(sender: _members.first, text: text, timestamp: DateTime.now()));
    });
  }

  bool _ensureBackend() => _backendUrl.isNotEmpty;

  String get _noBackendMsg =>
      '⚠️ Aucun backend configuré.\n\nConnectez un backend via le menu → Backend pour interroger vos données.\n\nTapez /help pour les commandes disponibles.';

  Future<String> _resolveCommand(String command) async {
    final raw = command.trim();
    final parts = raw.split(RegExp(r'\s+'));
    final name = (parts.isNotEmpty ? parts.first : raw).toLowerCase().replaceFirst('/', '');
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (name) {
      case 'help':
      case 'aide':
        return CommandLibrary.help();

      case 'status':
      case 'test':
      case 'health':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _checkBackendStatus();

      case 'ping':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _pingBackend();

      case 'protect':
        return _protector.getStatusReport();

      case 'alerts':
        return '__NAV_ALERTS__';

      case 'version':
        return _versionInfo();

      case 'tables':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _listTables();

      case 'tables-ui':
      case 'inspect':
        return '__NAV_TABLES__';

      case 'endpoints':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _endpointsInfo();

      case 'requests':
        return await _requestsInfo();

      case 'errors':
        return await _errorsInfo();

      case 'workflows':
        return await _workflowsInfo();

      case 'run':
        if (args.isEmpty) return '❌ Usage: /run <workflow>';
        return await _runWorkflowByName(args.join(' '));

      case 'history':
        return await _historyInfo();

      case 'users':
      case 'products':
      case 'produits':
      case 'orders':
      case 'commandes':
      case 'count':
      case 'last':
      case 'search':
      case 'schema':
      case 'table':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _executeRealCommand(raw);

      case 'user':
        if (!_ensureBackend()) return _noBackendMsg;
        if (args.isEmpty) return '❌ Usage: /user <id>';
        return await _fetchTableRow('users', args[0]);

      case 'insert':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _writeInsert(args);

      case 'update':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _writeUpdate(args);

      case 'delete':
        if (!_ensureBackend()) return _noBackendMsg;
        return await _writeDelete(args);

      case 'edit':
        return '__NAV_TABLES__';

      case 'query':
        return 'ℹ️ Les requêtes SQL brutes ne sont pas possibles via une API REST.\n\nUtilisez plutôt :\n• /search <table> <champ> <valeur>\n• /table <nom>\n• /count <table>\n• /inspect pour l\'explorateur complet';

      case 'restart':
        return 'ℹ️ Prone ne redémarre pas votre backend : ce serait dangereux de l\'extérieur.\n\nGérez le redémarrage depuis votre hébergeur (Supabase, Render, Vercel, etc.).';

      case 'uptime':
        return _uptimeInfo();

      default:
        return '❌ Commande inconnue: "$command"\n\nTapez /help pour voir les commandes disponibles.';
    }
  }

  String _versionInfo() {
    final buf = StringBuffer('📦 Prone\n\n');
    buf.writeln('App: 1.0.0');
    buf.writeln('Flutter: 3.44.1');
    buf.writeln('');
    if (_backendUrl.isEmpty) {
      buf.writeln('Backend: aucun connecté');
    } else {
      buf.writeln('Backend: $_backendUrl');
      buf.writeln('Type: ${_backendType.toUpperCase()}');
      buf.writeln('Clé API: ${_projectApiKey.isEmpty ? "non définie" : "${_projectApiKey.substring(0, 6)}…"}');
    }
    return buf.toString().trimRight();
  }

  String _uptimeInfo() {
    final since = _protector.monitoringSince;
    if (since == null) {
      return '⏱️ Prone n\'a pas encore mesuré ce backend dans cette session.\n\nLancez /status pour démarrer la surveillance.';
    }
    final d = DateTime.now().difference(since);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '⏱️ Surveillance active depuis $h h $m min\n\n'
        'Début: ${since.day}/${since.month}/${since.year} ${since.hour}:${since.minute.toString().padLeft(2, '0')}\n'
        'Vérifications: toutes les 45 s';
  }

  Future<String> _pingBackend() async {
    final sw = Stopwatch()..start();
    final res = await BackendAdapter.check(_backendUrl, _projectApiKey, type: _backendType);
    sw.stop();
    if (!res.online) {
      setState(() => _isConnected = false);
      await BackendErrorStore.instance.record(widget.projectId, 'Ping échoué', command: '/ping', level: ErrorLevel.offline);
      await _refreshAlertCount();
      return '❌ Ping échoué — backend injoignable.\n\n${res.message}';
    }
    setState(() => _isConnected = true);
    return '🏓 Pong !\n\n'
        'URL: $_backendUrl\n'
        'HTTP: ${res.statusCode}\n'
        'Latence réseau: ${sw.elapsedMilliseconds} ms\n'
        'Reponse: ${res.responseTime} ms\n'
        'Type: ${res.type}';
  }

  Future<String> _endpointsInfo() async {
    final tables = await BackendAdapter.listTables(_backendUrl, _projectApiKey, type: _backendType);
    if (tables.isEmpty) {
      return '🌐 Aucun endpoint détecté sur $_backendUrl.\n\nVérifiez l\'URL et la clé API (menu → Backend).';
    }
    final buf = StringBuffer('🌐 Endpoints détectés sur $_backendUrl (${tables.length}) :\n\n');
    for (final t in tables) {
      buf.writeln('• $t');
    }
    buf.writeln('\n👉 /inspect pour les explorer.');
    return buf.toString().trimRight();
  }

  Future<String> _requestsInfo() async {
    final calls = await ApiCallLog.instance.recent(limit: 15);
    if (calls.isEmpty) {
      return '📨 Aucune requête enregistrée pour l\'instant.\n\nElles apparaîtront ici après vos premières commandes.';
    }
    final buf = StringBuffer('📨 Dernières requêtes effectuées par Prone (${calls.length}) :\n\n');
    for (final c in calls) {
      final t = '${c.at.hour.toString().padLeft(2, '0')}:${c.at.minute.toString().padLeft(2, '0')}';
      final code = c.status != null ? '${c.status}' : (c.offline ? 'ERR' : '---');
      buf.writeln('$t  ${c.method}  ${c.status != null && c.status! < 400 ? "✅" : "❌"}  $code  ${c.ms}ms');
      buf.writeln('    ${c.url}');
    }
    return buf.toString().trimRight();
  }

  Future<String> _errorsInfo() async {
    final items = await BackendErrorStore.instance.recent(widget.projectId);
    if (items.isEmpty) {
      return '✅ Aucune erreur enregistrée pour ce projet.';
    }
    final buf = StringBuffer('❌ Erreurs enregistrées (${items.length}) :\n\n');
    for (final e in items.take(15)) {
      final t = '${e.at.day}/${e.at.month} ${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}';
      buf.writeln('[$t] ${e.level.name.toUpperCase()}');
      buf.writeln('  ${e.message}');
      if (e.command != null && e.command!.isNotEmpty) buf.writeln('  → ${e.command}');
      buf.writeln('');
    }
    return buf.toString().trimRight();
  }

  Future<String> _workflowsInfo() async {
    final items = await _backend.getWorkflows(widget.projectId);
    if (items.isEmpty) {
      return '⚙️ Aucun workflow pour ce projet.\n\nCréez-en un dans le menu → Workflows.';
    }
    final buf = StringBuffer('⚙️ Workflows (${items.length}) :\n\n');
    for (final w in items) {
      final active = '${w['status']}' == 'active';
      buf.writeln('${active ? "🟢" : "⚪️"} ${w['name']}');
      if (w['description'] != null && '${w['description']}'.isNotEmpty) buf.writeln('   ${w['description']}');
    }
    buf.writeln('\n👉 /run <nom> pour en lancer un.');
    return buf.toString().trimRight();
  }

  Future<String> _runWorkflowByName(String name) async {
    final items = await _backend.getWorkflows(widget.projectId);
    Map<String, dynamic>? wf;
    for (final w in items) {
      final n = '${w['name']}'.toLowerCase();
      if (n == name.toLowerCase() || n.contains(name.toLowerCase())) { wf = w; break; }
    }
    if (wf == null) {
      final names = items.map((w) => w['name']).join(', ');
      return '❌ Workflow "$name" introuvable.\n\nDisponibles: ${names.isEmpty ? "aucun" : names}';
    }
    if (!_ensureBackend()) return _noBackendMsg;

    final sw = Stopwatch()..start();
    final check = await BackendAdapter.check(_backendUrl, _projectApiKey, type: _backendType);
    sw.stop();
    final ms = sw.elapsedMilliseconds;
    final wfName = '${wf['name']}';

    final exec = await _backend.addExecution(
      widget.projectId,
      wfName,
      check.online ? 'success' : 'failed',
      duration: '$ms ms',
    );
    await _backend.addLog(
      widget.projectId,
      check.online ? 'info' : 'error',
      'Workflow "$wfName" exécuté — backend ${check.online ? "en ligne" : "injoignable"} ($ms ms)',
    );
    await _refreshAlertCount();

    final execId = '${exec['id']}';
    return '▶️ Workflow "$wfName"\n\n'
        'Résultat: ${check.online ? "✅ backend en ligne" : "❌ backend injoignable"}\n'
        'HTTP: ${check.statusCode}\n'
        'Durée: $ms ms\n'
        'Exécution: ${execId.substring(0, execId.length.clamp(0, 8))}\n\n'
        '👉 /history pour l\'historique.';
  }

  Future<String> _historyInfo() async {
    final items = await _backend.getExecutions(widget.projectId);
    if (items.isEmpty) {
      return '📅 Aucune exécution pour ce projet.\n\nLancez un workflow avec /run <nom>.';
    }
    final buf = StringBuffer('📅 Exécutions (${items.length}) :\n\n');
    for (final e in items.take(15)) {
      final at = DateTime.tryParse((e['created_at'] as String?) ?? '');
      final t = at != null
          ? '${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
          : '--/--';
      final st = '${e['status']}';
      final icon = st == 'success' ? '✅' : st == 'failed' ? '❌' : '⏳';
      buf.writeln('$t  $icon  ${e['name']}  ${e['duration'] ?? ''}');
    }
    return buf.toString().trimRight();
  }

  Future<String> _fetchTableRow(String table, String id) async {
    final res = await BackendAdapter.fetchRows(_backendUrl, _projectApiKey, table,
        limit: 1, offset: 0, type: _backendType, searchField: 'id', searchValue: id);
    if (!res.ok) {
      if (res.offline) {
        _lastCmdOffline = true;
        return '⚠️ Hors ligne — impossible de lire #$id.';
      }
      return '❌ Erreur ${res.error}';
    }
    if (res.rows.isEmpty) return '🔍 Aucune ligne avec id="$id" dans "$table".';
    final row = res.rows.first;
    final buf = StringBuffer('👤 $table #$id\n\n');
    row.forEach((k, v) => buf.writeln('$k: $v'));
    return buf.toString().trimRight();
  }

  Future<String> _environmentName() async {
    try {
      final conns = await _backend.getConnections(widget.projectId);
      final target = _backendUrl.replaceAll(RegExp(r'/+$'), '');
      for (final c in conns) {
        if ('${c['url']}'.replaceAll(RegExp(r'/+$'), '') == target) {
          final name = '${c['name']}';
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return 'Non défini';
  }

  bool _isProduction(String env) => env.toLowerCase().contains('prod');

  dynamic _parseWriteValue(String raw) {
    final l = raw.toLowerCase();
    if (l == 'null') return null;
    if (l == 'true') return true;
    if (l == 'false') return false;
    if (RegExp(r'^-?\d+$').hasMatch(raw)) {
      final i = int.tryParse(raw);
      if (i != null && i.toString() == raw) return i;
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(raw)) {
      final d = double.tryParse(raw);
      if (d != null) return d;
    }
    final first = raw.isNotEmpty ? raw[0] : '';
    final last = raw.isNotEmpty ? raw[raw.length - 1] : '';
    if ((first == '{' && last == '}') || (first == '[' && last == ']')) {
      try {
        return jsonDecode(raw);
      } catch (_) {}
    }
    return raw;
  }

  ({List<String> rest, bool confirmed, bool forced}) _splitConfirm(List<String> tokens) {
    var rest = List<String>.from(tokens);
    var confirmed = false;
    var forced = false;
    if (rest.length >= 2 && rest[rest.length - 1].toLowerCase() == 'prod' && rest[rest.length - 2].toLowerCase() == 'confirm') {
      confirmed = true;
      forced = true;
      rest = rest.sublist(0, rest.length - 2);
    } else if (rest.isNotEmpty && rest.last.toLowerCase() == 'confirm') {
      confirmed = true;
      rest = rest.sublist(0, rest.length - 1);
    }
    return (rest: rest, confirmed: confirmed, forced: forced);
  }

  String _writePreview({
    required String usage,
    required String verb,
    required String table,
    required Map<String, dynamic> values,
    required List<String> invalid,
    required bool needsProd,
    required List<String> echoed,
  }) {
    final env = _lastEnv ?? 'Non défini';
    final buf = StringBuffer('✏️ Aperçu — rien n\'a été envoyé\n\n');
    buf.writeln('Action : $verb dans "$table"');
    buf.writeln('Environnement : $env${needsProd ? '  ⚠️ PRODUCTION' : ''}');
    buf.writeln('Champs (${values.length}) :');
    values.forEach((k, v) => buf.writeln('• $k = $v'));
    if (invalid.isNotEmpty) buf.writeln('\nTokens ignorés (sans "=") : ${invalid.join(', ')}');
    if (needsProd) {
      buf.writeln('\n🔐 Écriture de production : ajoutez `confirm prod` pour valider.');
    } else {
      buf.writeln('\n🔐 Ajoutez `confirm` pour valider.');
    }
    buf.writeln('\n$usage');
    buf.writeln('${echoed.join(' ')}${needsProd ? ' confirm prod' : ' confirm'}');
    return buf.toString().trimRight();
  }

  String? _lastEnv;

  String _formatWriteResult(WriteResult res, String verb, String table) {
    if (!res.ok) {
      if (res.offline) {
        _lastCmdOffline = true;
        return '⚠️ Hors ligne — $verb non effectué(e).\n\nLa commande est mise en file d\'attente.';
      }
      return '❌ $verb refusé(e) par "$table"\n\n${res.error}\nHTTP ${res.statusCode}';
    }
    final n = res.affected ?? 1;
    final buf = StringBuffer('✅ $verb réussie — "$table"\n\n');
    buf.writeln('HTTP ${res.statusCode} · ${res.method} · $n ligne(s)');
    if (res.row != null) {
      buf.writeln('\nLigne concernée :');
      res.row!.forEach((k, v) {
        final s = '$v';
        buf.writeln('• $k = ${s.length > 60 ? '${s.substring(0, 60)}…' : s}');
      });
    }
    return buf.toString().trimRight();
  }

  Future<String> _finishWrite(WriteResult res, String verb, String table, String command) async {
    BackendAdapter.invalidateCountCache();
    await BackendErrorStore.instance.record(
      widget.projectId,
      res.ok ? '${res.method} $table — ${res.affected ?? 1} ligne(s)' : '${res.method} $table: ${res.error}',
      command: command,
      level: res.ok ? ErrorLevel.warning : (res.offline ? ErrorLevel.offline : ErrorLevel.error),
    );
    _refreshAlertCount();
    if (res.ok) setState(() => _isConnected = true);
    return _formatWriteResult(res, verb, table);
  }

  Future<String> _writeInsert(List<String> tokens) async {
    const usage = 'Usage: /insert <table> champ=valeur ...';
    if (tokens.length < 2) return '❌ $usage';
    final conf = _splitConfirm(tokens);
    final table = conf.rest.first;
    final pairs = conf.rest.sublist(1);
    if (pairs.isEmpty) return '❌ $usage';

    final values = <String, dynamic>{};
    final invalid = <String>[];
    for (final t in pairs) {
      final i = t.indexOf('=');
      if (i <= 0) {
        invalid.add(t);
        continue;
      }
      values[t.substring(0, i)] = _parseWriteValue(t.substring(i + 1));
    }
    if (values.isEmpty) return '❌ Aucun champ valide. $usage';

    final env = _lastEnv = await _environmentName();
    final needsProd = _isProduction(env);
    if (!conf.confirmed || (needsProd && !conf.forced)) {
      return _writePreview(
        usage: usage,
        verb: 'Insertion',
        table: table,
        values: values,
        invalid: invalid,
        needsProd: needsProd,
        echoed: ['/insert', ...conf.rest],
      );
    }

    setState(() => _isTyping = true);
    final res = await BackendAdapter.insertRow(_backendUrl, _projectApiKey, table, values, type: _backendType);
    if (mounted) setState(() => _isTyping = false);
    return await _finishWrite(res, 'Insertion', table, '/insert $table');
  }

  Future<String> _writeUpdate(List<String> tokens) async {
    const usage = 'Usage: /update <table> <id> champ=valeur ...';
    if (tokens.length < 3) return '❌ $usage';
    final conf = _splitConfirm(tokens);
    if (conf.rest.length < 3) return '❌ $usage';
    final table = conf.rest.first;
    final idValue = conf.rest[1];
    final pairs = conf.rest.sublist(2);
    if (pairs.isEmpty) return '❌ $usage';

    final values = <String, dynamic>{};
    final invalid = <String>[];
    for (final t in pairs) {
      final i = t.indexOf('=');
      if (i <= 0) {
        invalid.add(t);
        continue;
      }
      values[t.substring(0, i)] = _parseWriteValue(t.substring(i + 1));
    }
    if (values.isEmpty) return '❌ Aucun champ valide. $usage';

    final env = _lastEnv = await _environmentName();
    final needsProd = _isProduction(env);
    if (!conf.confirmed || (needsProd && !conf.forced)) {
      return _writePreview(
        usage: usage,
        verb: 'Modification',
        table: table,
        values: {...values, 'id': idValue},
        invalid: invalid,
        needsProd: needsProd,
        echoed: ['/update', ...conf.rest],
      );
    }

    setState(() => _isTyping = true);
    final idCol = await BackendAdapter.findIdColumn(_backendUrl, _projectApiKey, table, type: _backendType);
    final res = await BackendAdapter.updateRow(_backendUrl, _projectApiKey, table, values,
        idColumn: idCol, idValue: idValue, type: _backendType);
    if (mounted) setState(() => _isTyping = false);
    return await _finishWrite(res, 'Modification', table, '/update $table $idValue');
  }

  Future<String> _writeDelete(List<String> tokens) async {
    const usage = 'Usage: /delete <table> <id>';
    if (tokens.length < 2) return '❌ $usage';
    final conf = _splitConfirm(tokens);
    if (conf.rest.length < 2) return '❌ $usage';
    final table = conf.rest.first;
    final idValue = conf.rest[1];

    final env = _lastEnv = await _environmentName();
    final needsProd = _isProduction(env);
    if (!conf.confirmed || (needsProd && !conf.forced)) {
      return _writePreview(
        usage: usage,
        verb: 'Suppression',
        table: table,
        values: {'id': idValue},
        invalid: const [],
        needsProd: needsProd,
        echoed: ['/delete', ...conf.rest],
      );
    }

    setState(() => _isTyping = true);
    final idCol = await BackendAdapter.findIdColumn(_backendUrl, _projectApiKey, table, type: _backendType);
    final res = await BackendAdapter.deleteRow(_backendUrl, _projectApiKey, table,
        idColumn: idCol, idValue: idValue, type: _backendType);
    if (mounted) setState(() => _isTyping = false);
    return await _finishWrite(res, 'Suppression', table, '/delete $table $idValue');
  }

  Future<void> _retryPending() async {
    if (_backendUrl.isEmpty) return;
    setState(() => _isTyping = true);
    try {
      final res = await BackendAdapter.check(_backendUrl, _projectApiKey, type: _backendType);
      if (mounted) setState(() => _isConnected = res.online);
      if (!res.online) {
        if (!mounted) return;
        setState(() => _isTyping = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Toujours hors ligne — reessayez plus tard'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
      await _flushQueue();
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
    if (mounted) setState(() => _isTyping = false);
  }

  Future<void> _flushQueue() async {
    final pending = await OfflineQueue.instance.pending(widget.projectId);
    if (pending.isEmpty) return;
    await _refreshPendingCount();
    if (_pendingCommands == 0 || _lastCmdOffline) return;

    await _botSay('🔁 Backend de retour en ligne — ${pending.length} commande(s) en file d\'attente...');

    for (final item in pending) {
      final res = await _resolveCommand(item.command);
      await OfflineQueue.instance.remove(item.id);
      if (_lastCmdOffline) break;
      await _botSay('📤 ${item.command}\n\n$res');
      await Future.delayed(const Duration(milliseconds: 250));
    }
    await _refreshPendingCount();
    if (!_lastCmdOffline) {
      await _botSay(_pendingCommands > 0
          ? '⚠️ $_pendingCommands commande(s) restent en attente (backend toujours hors ligne).'
          : '✅ File d\'attente vide.');
    }
  }

  void _showMentionNotification(_Member member, String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        _buildAvatar(member, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Text('${member.name} a été notifié', style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _getMentionQuery() {
    final text = _controller.text;
    final match = RegExp(r'@(\w*)$').firstMatch(text);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  void _selectMention(_Member member) {
    final text = _controller.text;
    final newText = text.replaceFirst(RegExp(r'@\w*$'), '@${member.name} ');
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
    setState(() => _isMentioning = false);
  }

  String _formatJsonList(List data) {
    final buf = StringBuffer();
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is Map) {
        final name = item['nom'] ?? item['name'] ?? item['title'] ?? item['id'] ?? '---';
        final price = item['prix'] ?? item['price'] ?? '';
        final currency = item['currency'] ?? item['devise'] ?? '';
        buf.writeln('• $name${price != '' ? ' ($price${currency != '' ? ' $currency' : ''})' : ''}');
        // Show extra fields
        for (final key in item.keys) {
          if (!['nom', 'name', 'title', 'id', 'prix', 'price', 'description_images', 'main_image', 'created_at'].contains(key)) {
            final val = item[key];
            if (val != null && val.toString().isNotEmpty && val.toString().length < 100) {
              buf.writeln('  $key: $val');
            }
          }
        }
      } else {
        buf.writeln('• $item');
      }
      if (i < data.length - 1) buf.writeln();
    }
    return buf.toString();
  }

  String _formatJsonMap(Map data) {
    final buf = StringBuffer();
    for (final entry in data.entries) {
      final val = entry.value;
      if (val is List) {
        buf.writeln('${entry.key}: [${val.length} items]');
      } else if (val is Map) {
        buf.writeln('${entry.key}: {...}');
      } else {
        buf.writeln('${entry.key}: $val');
      }
    }
    return buf.toString();
  }

  Future<String> _getBotName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('bot_name_${widget.projectId}') ?? 'Bot';
    } catch (_) { return 'Bot'; }
  }

  Widget _buildAvatar(_Member m, {double size = 40}) {
    if (m.photo != null && m.photo!.isNotEmpty) {
      return ClipOval(child: Image.memory(m.photo!, width: size, height: size, fit: BoxFit.cover));
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(m.initials, style: TextStyle(color: Colors.white, fontSize: size * 0.3, fontWeight: FontWeight.w700))),
    );
  }

  Future<String> _checkBackendStatus() async {
    if (_backendUrl.isEmpty) {
      _updateProjectStatus('Backend non configure', 'warning');
      return '⚠️ Aucun backend configuré.';
    }
    try {
      final result = await BackendAdapter.check(_backendUrl, _projectApiKey, type: _backendType);
      if (mounted) setState(() => _isConnected = result.online);
      if (result.online) {
        _updateProjectStatus('En ligne - ${result.responseTime}ms', 'success');
        _lastCmdOffline = false;
        await _flushQueue();
      } else {
        _updateProjectStatus('Hors ligne', 'error');
        await BackendErrorStore.instance.record(widget.projectId, 'Backend inaccessible — ${result.message}', command: '/status', level: ErrorLevel.offline);
        await _refreshAlertCount();
      }
      return result.message;
    } catch (e) {
      if (mounted) setState(() => _isConnected = false);
      _updateProjectStatus('Erreur de connexion', 'error');
      return '❌ Erreur: $e';
    }
  }

  Future<String> _listTables() async {
    if (_backendUrl.isEmpty) return '⚠️ Aucun backend configuré.';
    try {
      final tables = await BackendAdapter.listTables(_backendUrl, _projectApiKey, type: _backendType);
      if (tables.isEmpty) return 'ℹ️ Aucune table/endpoint détecté.\n\nLe backend pourrait ne pas exposer de tables accessibles.';
      final buffer = StringBuffer('📋 Tables/Endpoints détectés:\n\n');
      for (final t in tables) {
        buffer.writeln('  • $t');
      }
      return buffer.toString();
    } catch (e) {
      return '❌ Erreur lors du listage: $e';
    }
  }
}

class _Member {
  final String name;
  final String initials;
  final Color color;
  final bool isOnline;
  final bool isBot;
  final Uint8List? photo;
  final String? role;
  final String? email;
  _Member({required this.name, required this.initials, required this.color, this.isOnline = false, this.isBot = false, this.photo, this.role, this.email});
}

enum MessageLevel { info, warning, error, critical, offline }

class _ChatMessage {
  final _Member sender;
  final String text;
  final DateTime timestamp;
  final int? replyToIndex;
  final MessageLevel level;
  final String? alertTitle;
  final String? id;
  _ChatMessage({required this.sender, required this.text, required this.timestamp, this.replyToIndex, this.level = MessageLevel.info, this.alertTitle, this.id});
}

class _SettingsItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/$icon', width: 18, height: 18, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuBtn extends StatelessWidget {
  final String icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  const _MenuBtn({required this.icon, required this.label, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset(icon, width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ThemeHelper.text(context))),
                Text(description, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
              ])),
              SvgPicture.asset('assets/icons/send.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(Duration(milliseconds: widget.delay));
    if (mounted) _controller.repeat(reverse: true);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3 + (_animation.value * 0.7)), shape: BoxShape.circle));
      },
    );
  }
}
