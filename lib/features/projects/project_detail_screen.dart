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
import '../../core/security/security_service.dart';
import '../../core/security/bot_protector.dart';
import '../../core/backend/backend_adapter.dart';
import '../../core/local/local_backend.dart';
import '../../core/utils/photo_picker_helper.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _controller = TextEditingController();
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
    final orgs = await _backend.getOrganizations();
    if (orgs.isNotEmpty) {
      final members = await _backend.getMembers(orgs.first['id'] as String);
      members.sort((a, b) {
        final dateA = (a['created_at'] as String?) ?? '';
        final dateB = (b['created_at'] as String?) ?? '';
        return dateA.compareTo(dateB);
      });
      if (mounted) {
        final memberList = <_Member>[];
        // Load bot photo
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
          final role = (m['role'] as String?) ?? 'member';
          final photo = (m['photo'] as String?) ?? '';
          Uint8List? photoBytes;
          try { if (photo.isNotEmpty) photoBytes = base64Decode(photo); } catch (_) {}
          final hash = name.hashCode;
          final colors = [AppColors.primary, const Color(0xFF00CEC9), const Color(0xFF00B894), const Color(0xFF6C5CE7), const Color(0xFFE17055)];
          final colorVal = colors[hash.abs() % colors.length];
          final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
          memberList.add(_Member(name: name.isEmpty ? email : name, initials: initials.isEmpty ? '?' : initials, color: colorVal, isOnline: true, photo: photoBytes, role: role, email: email));
        }
        setState(() {
          _members.clear();
          _members.addAll(memberList);
          _userRole = (members.isNotEmpty ? (members.first['role'] as String?) : null) ?? 'admin';
        });
      }
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _protector.stopMonitoring();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCommands = _selectedCategory == 'All'
        ? CommandLibrary.commands
        : CommandLibrary.commands.where((c) => c.category == _selectedCategory).toList();
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
              const SizedBox(height: 80),
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
                        _SettingsItem(icon: 'logs.svg', label: 'Logs', onTap: () {
                          setState(() => _showSettings = false);
                          context.go('/projects/${widget.projectId}/logs');
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
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            itemCount: filteredCommands.length,
                            itemBuilder: (context, index) {
                              final cmd = filteredCommands[index];
                              return _MenuBtn(icon: cmd.icon, label: '/${cmd.name}', description: cmd.description, onTap: () {
                                _controller.text = '/${cmd.name} ';
                                _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                                setState(() => _showCommands = false);
                                FocusScope.of(context).requestFocus(FocusNode());
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
                        onTap: () => setState(() => _showCommands = !_showCommands),
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
                          _buildRoleChip('Membre', 'Membre', selectedRole, (v) => setSheetState(() => selectedRole = v)),
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
                        onTap: () {
                          if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                            setState(() {
                              _members.add(_Member(name: emailController.text.split('@')[0], initials: emailController.text.substring(0, 2).toUpperCase(), color: AppColors.primaryDark, isOnline: false));
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyée à ${emailController.text}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('QR Code partagé'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('API Key copiée !'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      default:
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
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _messages.removeAt(_selectedMessageIndex ?? 0);
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

  void _sendCommand(String command) async {
    if (command.trim().isEmpty) return;

    // Check for @ mentions
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

    // Only slash commands trigger the bot
    if (!command.startsWith('/')) {
      setState(() { _isTyping = false; });
      return;
    }

    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      String response;
      final cmd = CommandLibrary.findCommand(command);
      if (cmd != null) {
        response = cmd.execute(cmd.currentParams);
      } else {
        final lower = command.toLowerCase();
        if (lower == '/help' || lower == '/aide') {
          response = '🤖 Commandes Prone:\n\n/status - Vérifier le backend\n/test - Tester la connexion\n/tables - Lister les tables\n/protect - Rapport sécurité\n/help - Aide\n\n💡 Commandes backend:\nGET /produits - Lire\nPOST /produits - Créer\nPUT /produits?id=1 - Modifier\nDELETE /produits?id=1 - Supprimer';
        } else if (lower == '/status' || lower == '/test') {
          response = await _checkBackendStatus();
        } else if (lower == '/tables') {
          response = await _listTables();
        } else if (lower == '/protect') {
          response = _protector.getStatusReport();
        } else {
          response = '❌ Commande inconnue: "$command"\n\nTapez /help pour voir les commandes disponibles.';
        }
      }
      _backend.sendMessage(widget.projectId, response, sender: 'bot').catchError((_) => <String, dynamic>{'error': true});
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(sender: _members.first, text: response, timestamp: DateTime.now()));
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
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
        buf.writeln('• $name${price != '' ? ' ($price FCFA)' : ''}');
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
    if (_backendUrl.isEmpty) return '⚠️ Aucun backend configuré.';
    final result = await BackendAdapter.check(_backendUrl, _projectApiKey, type: _backendType);
    return result.message;
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
  _ChatMessage({required this.sender, required this.text, required this.timestamp, this.replyToIndex, this.level = MessageLevel.info, this.alertTitle});
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
