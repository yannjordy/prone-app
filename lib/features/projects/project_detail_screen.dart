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
import '../../app/app.dart';
import '../../core/commands/command_library.dart';
import '../../core/security/security_service.dart';
import '../../core/local/local_backend.dart';

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
        _backendType = _backendUrl.contains('supabase') ? 'supabase' : 'generic';
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
      if (members.isNotEmpty && mounted) {
        setState(() => _userRole = (members.first['role'] as String?) ?? 'admin');
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
                const SizedBox(height: 16),
                // Invite buttons row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () { Navigator.pop(context); _inviteMember(); },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('Email', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Text('QR Code', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Members list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final m = _members[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Center(child: Text(m.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ThemeHelper.text(context))),
                                  Text(m.isBot ? 'Bot' : (m.isOnline ? 'En ligne' : 'Hors ligne'), style: TextStyle(fontSize: 12, color: m.isOnline ? AppColors.success : ThemeHelper.textDim(context))),
                                ],
                              ),
                            ),
                            if (!m.isBot)
                              GestureDetector(
                                onTap: () {
                                  setState(() => _members.remove(m));
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.name} retiré du projet'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.person_remove, color: AppColors.error, size: 16),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
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
    final security = SecurityService();
    final inviteCode = security.encrypt('project:${widget.projectId}:invite');
    final inviteLink = 'connectflow://invite/$inviteCode';

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
                Text('QR Code d\'invitation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Scannez pour rejoindre le projet', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 24),
                // QR Code
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
                const SizedBox(height: 20),
                // Invite code display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                  child: Column(
                    children: [
                      Text('Code d\'invitation', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                      const SizedBox(height: 4),
                      Text(inviteCode, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'monospace'), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Code copié !'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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

  Widget _buildMessage(_ChatMessage msg) {
    final isBot = msg.sender.isBot;
    final isCurrentUser = msg.sender == _currentUser;
    final msgIndex = _messages.indexOf(msg);

    return GestureDetector(
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
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [msg.sender.color, msg.sender.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: ThemeHelper.bg(context), width: 2),
                  ),
                  child: Center(child: Text(msg.sender.initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(msg.sender.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: msg.sender.color))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMessageIndex == msgIndex
                            ? AppColors.primary.withOpacity(0.08)
                            : isCurrentUser ? AppColors.primary.withOpacity(0.15) : ThemeHelper.surface(context),
                        borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isCurrentUser ? 16 : 4), bottomRight: Radius.circular(isCurrentUser ? 4 : 16)),
                        border: Border.all(color: _selectedMessageIndex == msgIndex
                            ? AppColors.primary.withOpacity(0.5)
                            : isCurrentUser ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context)),
                      ),
                      child: _buildMessageText(msg.text, isBot),
                    ),
                    const SizedBox(height: 4),
                    Text('${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
                  ],
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 10),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [msg.sender.color, msg.sender.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: ThemeHelper.bg(context), width: 2),
                  ),
                  child: Center(child: Text(msg.sender.initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
          response = '🤖 Commandes Prone:\n\n/status - Vérifier le backend\n/test - Tester la connexion\n/tables - Lister les tables\n/help - Aide\n\n💡 Commandes backend (requêtes HTTP):\nGET /produits - Lire des données\nPOST /produits - Créer une ressource\nPUT /produits?id=1 - Modifier\nDELETE /produits?id=1 - Supprimer\n\n📝 Requête Supabase:\nGET /produits?select=*&statut=eq.published\nGET /produits?select=nom,prix&limit=5';
        } else if (lower == '/status' || lower == '/test') {
          response = await _checkBackendStatus();
        } else if (lower == '/tables') {
          response = await _listTables();
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
        CircleAvatar(radius: 12, backgroundColor: member.color, child: Text(member.initials, style: const TextStyle(fontSize: 10, color: Colors.white))),
        const SizedBox(width: 10),
        Expanded(child: Text('${member.name} a été notifié', style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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

  Future<String> _checkBackendStatus() async {
    if (_backendUrl.isEmpty) return '⚠️ Aucun backend configuré.';
    try {
      final dio = Dio();
      final headers = <String, dynamic>{};
      if (_backendType == 'supabase' && _projectApiKey.isNotEmpty) {
        headers['apikey'] = _projectApiKey;
        headers['Authorization'] = 'Bearer $_projectApiKey';
      }
      final url = _backendType == 'supabase' ? '$_backendUrl/rest/v1/?limit=1' : _backendUrl;
      final resp = await dio.get(url, options: Options(headers: headers, receiveTimeout: const Duration(seconds: 10)));
      return '✅ Backend connecté!\n\nURL: $_backendUrl\nType: $_backendType\nStatus: ${resp.statusCode}\n\nLe backend est opérationnel.';
    } on DioException catch (e) {
      return '❌ Backend inaccessible\n\nURL: $_backendUrl\nErreur: ${e.message}\n\nVérifiez l\'URL et la connexion.';
    }
  }

  Future<String> _listTables() async {
    if (_backendUrl.isEmpty) return '⚠️ Aucun backend configuré.';
    if (_backendType != 'supabase') return 'ℹ️ Listage des tables disponible uniquement pour Supabase.';
    try {
      final dio = Dio();
      final headers = <String, dynamic>{
        'apikey': _projectApiKey,
        'Authorization': 'Bearer $_projectApiKey',
      };
      // Try common Supabase tables
      final tables = ['produits', 'parametres_boutique', 'orders', 'users', 'profiles', 'categories'];
      final found = <String>[];
      for (final table in tables) {
        try {
          final resp = await dio.get('$_backendUrl/rest/v1/$table?select=id&limit=1',
            options: Options(headers: headers, receiveTimeout: const Duration(seconds: 5)));
          if (resp.statusCode == 200) {
            found.add(table);
          }
        } catch (_) {}
      }
      if (found.isEmpty) return 'ℹ️ Aucune table accessible avec cette API key.\n\nVérifiez les permissions Supabase.';
      return '📋 Tables disponibles:\n\n${found.map((t) => '• $t').join('\n')}\n\n💡 Essayez: GET /$found.first?select=*';
    } catch (e) {
      return '❌ Erreur: $e';
    }
  }
}

class _Member {
  final String name;
  final String initials;
  final Color color;
  final bool isOnline;
  final bool isBot;
  _Member({required this.name, required this.initials, required this.color, this.isOnline = false, this.isBot = false});
}

class _ChatMessage {
  final _Member sender;
  final String text;
  final DateTime timestamp;
  _ChatMessage({required this.sender, required this.text, required this.timestamp});
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
