import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/local/database_helper.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  bool _showMenu = false;
  bool _showCreateForm = false;
  bool _showSearch = false;
  bool _showArchives = false;
  bool _isGridView = false;
  bool _hasBackend = false;
  bool _showContextMenu = false;
  _Project? _contextMenuProject;
  Offset _contextMenuPosition = Offset.zero;
  final _searchController = TextEditingController();
  final _newNameController = TextEditingController();
  final _newDescController = TextEditingController();
  final _renameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _backendUrlController = TextEditingController();
  final _notifService = NotificationService();
  final _backend = LocalBackend();
  List<_Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadBackendStatus();
    _loadProjects();
    _notifService.addListener(() => setState(() {}));
  }

  Future<void> _loadProjects() async {
    final rawProjects = await _backend.getProjects();
    setState(() {
      _projects = rawProjects.map((p) {
        final name = (p['name'] as String?) ?? '';
        final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
        final colorValue = name.hashCode.abs() % 0xFFFFFF;
        return _Project(
          id: (p['id'] as String?) ?? '',
          name: name,
          initials: initials.isEmpty ? '??' : initials,
          color: Color(0xFF000000 + colorValue),
          lastMessage: 'Backend connecté',
          time: '',
          timestamp: DateTime.tryParse((p['created_at'] as String?) ?? '') ?? DateTime.now(),
          isArchived: (p['is_archived'] as int?) == 1,
          isMuted: (p['is_muted'] as int?) == 1,
          isPinned: (p['is_pinned'] as int?) == 1,
          apiKey: (p['api_key'] as String?) ?? '',
          backendUrl: (p['backend_url'] as String?) ?? '',
        );
      }).toList();
    });
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = prefs.getBool('project_view_grid') ?? false);
  }

  Future<void> _saveViewPreference(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('project_view_grid', isGrid);
  }

  Future<void> _loadBackendStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hasBackend = prefs.getBool('has_backend') ?? false);
  }

  List<_Project> get _filteredProjects {
    var list = _projects.where((p) => _showArchives ? p.isArchived : !p.isArchived).toList();
    if (_searchController.text.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    }
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });
    return list;
  }

  int get _archivedCount => _projects.where((p) => p.isArchived).length;

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: SvgPicture.asset('assets/icons/projects.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                  ),
                  const SizedBox(width: 12),
                  Text(_showArchives ? 'ARCHIVES' : 'PROJECTS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
                  const Spacer(),
                  if (_notifService.totalUnread > 0 && !_showArchives)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_notifService.totalUnread} non lu${_notifService.totalUnread > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => _showArchives = !_showArchives),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _showArchives ? AppColors.warning.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset('assets/icons/archive.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_showArchives ? AppColors.warning : textDimColor, BlendMode.srcIn)),
                          if (_archivedCount > 0)
                            Positioned(
                              top: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                                child: Text('$_archivedCount', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showSearch = !_showSearch),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _showSearch ? AppColors.primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(50)),
                      child: Center(child: SvgPicture.asset('assets/icons/search.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_showSearch ? AppColors.primary : textDimColor, BlendMode.srcIn))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showMenu = !_showMenu),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _showMenu ? AppColors.primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(50)),
                      child: Center(child: SvgPicture.asset('assets/icons/more.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(_showMenu ? AppColors.primary : textDimColor, BlendMode.srcIn))),
                    ),
                  ),
                ],
              ),
              if (_showSearch) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                  child: Row(
                    children: [
                      SvgPicture.asset('assets/icons/search.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(hintText: 'Rechercher un projet...', hintStyle: TextStyle(color: textDimColor), border: InputBorder.none),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () { _searchController.clear(); setState(() {}); },
                          child: SvgPicture.asset('assets/icons/alert-circle.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(child: _isGridView ? _buildGrid() : _buildList()),
            ],
          ),
        ),
        if (_showMenu)
          GestureDetector(onTap: () => setState(() => _showMenu = false), child: Container(color: Colors.black.withOpacity(0.3))),
        if (_showMenu)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56, right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MenuItem(icon: 'plus.svg', label: 'Nouveau projet', onTap: () {
                        setState(() => _showMenu = false);
                        if (!_hasBackend) {
                          _showNoBackendWarning();
                        } else {
                          setState(() => _showCreateForm = true);
                        }
                      }),
                      _MenuItem(icon: 'search.svg', label: 'Rechercher', onTap: () { setState(() { _showMenu = false; _showSearch = true; }); }),
                      Divider(color: ThemeHelper.borderLight(context), height: 1),
                      _MenuItem(icon: 'grid.svg', label: _isGridView ? 'Vue liste' : 'Vue grille', onTap: () { final v = !_isGridView; _saveViewPreference(v); setState(() { _showMenu = false; _isGridView = v; }); }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showCreateForm)
          GestureDetector(onTap: () => setState(() => _showCreateForm = false), child: Container(color: Colors.black.withOpacity(0.5))),
        if (_showCreateForm) _buildCreateForm(),
        // Context menu overlay
        if (_showContextMenu)
          GestureDetector(
            onTap: () => setState(() { _showContextMenu = false; _contextMenuProject = null; }),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        if (_showContextMenu) _buildContextMenu(),
      ],
    );
  }

  void _showNoBackendWarning() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.link_off, color: AppColors.warning, size: 28)),
                const SizedBox(height: 16),
                Text('Backend non connecté', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Vous devez connecter un backend avant de créer un projet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Compris', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final projects = _filteredProjects;
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/archive.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            const SizedBox(height: 16),
            Text(_showArchives ? 'Aucun projet archivé' : 'Aucun projet', style: TextStyle(fontSize: 16, color: ThemeHelper.textDim(context))),
          ],
        ),
      );
    }
    return ListView(
      children: projects.map((p) {
        final itemKey = GlobalKey();
        return Column(
          children: [
            GestureDetector(
              key: itemKey,
              onLongPressStart: (details) {
                final RenderBox? renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final position = renderBox.localToGlobal(Offset.zero);
                  final size = renderBox.size;
                  _showProjectOptions(p, Offset(details.globalPosition.dx, position.dy + size.height / 2));
                }
              },
              child: _ProjectCard(
                project: p,
                onTap: () {
                  if (p.isArchived) return;
                  _notifService.clearUnread(p.id);
                  setState(() => p.unread = 0);
                  context.go('/projects/${p.id}');
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    final projects = _filteredProjects;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final p = projects[index];
        final itemKey = GlobalKey();
        return GestureDetector(
          key: itemKey,
          onLongPressStart: (details) {
            final RenderBox? renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;
              _showProjectOptions(p, Offset(details.globalPosition.dx, position.dy + size.height / 2));
            }
          },
          child: _ProjectGridCard(
            project: p,
            onTap: () {
              if (p.isArchived) return;
              _notifService.clearUnread(p.id);
              setState(() => p.unread = 0);
              context.go('/projects/${p.id}');
            },
          ),
        );
      },
    );
  }

  void _showProjectOptions(_Project project, Offset position) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    double top = position.dy - 40;
    double left = position.dx + 10;
    if (left + 200 > screenWidth) left = screenWidth - 210;
    if (left < 10) left = 10;
    if (top + 350 > screenHeight) top = screenHeight - 360;
    if (top < MediaQuery.of(context).padding.top) top = MediaQuery.of(context).padding.top + 10;

    setState(() {
      _contextMenuProject = project;
      _contextMenuPosition = Offset(left, top);
      _showContextMenu = true;
    });
  }

  Widget _buildContextMenu() {
    if (!_showContextMenu || _contextMenuProject == null) return const SizedBox.shrink();
    final project = _contextMenuProject!;
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Positioned(
      left: _contextMenuPosition.dx,
      top: _contextMenuPosition.dy,
      child: GestureDetector(
        onTap: () => setState(() { _showContextMenu = false; _contextMenuProject = null; }),
        child: SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor.withOpacity(0.5)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [project.color, project.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                            child: Center(child: Text(project.initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(project.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeHelper.text(context)), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Divider(color: borderColor.withOpacity(0.3), height: 1),
                    _buildPopupOption('edit.svg', 'Renommer', AppColors.primary, () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _renameProject(project); }),
                    _buildPopupOption(project.isPinned ? 'volume.svg' : 'mute.svg', project.isPinned ? 'Désépingler' : 'Épingler', AppColors.primary, () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _togglePin(project.id, project.isPinned); }),
                    _buildPopupOption('archive.svg', project.isArchived ? 'Désarchiver' : 'Archiver', AppColors.warning, () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _archiveProject(project.id, project.isArchived); }),
                    _buildPopupOption(project.isMuted ? 'volume.svg' : 'mute.svg', project.isMuted ? 'Démuter' : 'Muter', ThemeHelper.textDim(context), () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _toggleMute(project.id, project.isMuted); }),
                    Divider(color: borderColor.withOpacity(0.3), height: 1),
                    _buildPopupOption('trash.svg', 'Supprimer la conversation', AppColors.error, () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _clearMessages(project.id); }),
                    _buildPopupOption('trash.svg', 'Supprimer le projet', AppColors.error, () { setState(() { _showContextMenu = false; _contextMenuProject = null; }); _confirmDeleteProject(project); }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupOption(String icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/$icon', width: 16, height: 16, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 13, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _renameProject(_Project project) {
    _renameController.text = project.name;
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Renommer le projet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                TextField(
                  controller: _renameController,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () async {
                      await _backend.updateProject(project.id, {'name': _renameController.text});
                      Navigator.pop(context);
                      _loadProjects();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Projet renommé'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearMessages(String projectId) {
    final surfaceColor = ThemeHelper.surface(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline, color: AppColors.warning, size: 28)),
                const SizedBox(height: 16),
                Text('Supprimer la conversation ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Tous les messages de ce projet seront supprimés.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () async {
                      Navigator.pop(context);
                      final db = await DatabaseHelper().database;
                      await db.delete('messages', where: 'project_id = ?', whereArgs: [projectId]);
                      _loadProjects();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Conversation supprimée'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProject(_Project project) {
    final surfaceColor = ThemeHelper.surface(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28)),
                const SizedBox(height: 16),
                Text('Supprimer "${project.name}" ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Cette action est irréversible. Le projet et tous ses messages seront supprimés.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () async {
                      Navigator.pop(context);
                      await _backend.deleteProject(project.id);
                      _loadProjects();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Projet supprimé'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _togglePin(String id, bool currentPin) async {
    await _backend.updateProject(id, {'is_pinned': currentPin ? 0 : 1});
    _loadProjects();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentPin ? 'Projet désépinglé' : 'Projet épinglé'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _archiveProject(String id, bool isArchived) async {
    await _backend.updateProject(id, {'is_archived': isArchived ? 0 : 1});
    _loadProjects();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArchived ? 'Projet désarchivé' : 'Projet archivé'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _toggleMute(String id, bool currentMute) async {
    await _backend.updateProject(id, {'is_muted': currentMute ? 0 : 1});
    _loadProjects();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentMute ? 'Notifications activées' : 'Notifications coupées'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Widget _buildCreateForm() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nouveau Projet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('Connectez votre backend API', style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 24),
                _buildInput('Nom du projet', _newNameController, 'Mon Backend API'),
                const SizedBox(height: 12),
                _buildInput('Description', _newDescController, 'Description optionnelle'),
                const SizedBox(height: 12),
                _buildInput('Clé API', _apiKeyController, 'sk-xxxxxxxxxxxxxxxx', isPassword: true),
                const SizedBox(height: 12),
                _buildInput('URL du Backend', _backendUrlController, 'https://api.monbackend.com'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => setState(() => _showCreateForm = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: _createProject, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Créer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint, {bool isPassword = false}) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textDimColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        ),
      ],
    );
  }

  void _createProject() async {
    if (_newNameController.text.isEmpty || _apiKeyController.text.isEmpty || _backendUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez remplir tous les champs obligatoires'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    try {
      final name = _newNameController.text;
      await _backend.createProject(name, _newDescController.text, apiKey: _apiKeyController.text, backendUrl: _backendUrlController.text);
      setState(() {
        _showCreateForm = false;
        _newNameController.clear();
        _newDescController.clear();
        _apiKeyController.clear();
        _backendUrlController.clear();
      });
      _loadProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Projet "$name" créé'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }
}

class _Project {
  final String id;
  String name;
  final String initials;
  final Color color;
  String lastMessage;
  final String time;
  final DateTime timestamp;
  int unread;
  bool isArchived;
  bool isMuted;
  bool isPinned;
  final String apiKey;
  final String backendUrl;
  _Project({required this.id, required this.name, required this.initials, required this.color, required this.lastMessage, required this.time, required this.timestamp, this.unread = 0, this.isArchived = false, this.isMuted = false, this.isPinned = false, this.apiKey = '', this.backendUrl = ''});
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

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

class _ProjectCard extends StatelessWidget {
  final _Project project;
  final VoidCallback onTap;
  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [project.color, project.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(50),
                    border: project.isArchived ? Border.all(color: AppColors.warning.withOpacity(0.5), width: 2) : null,
                  ),
                  child: Center(child: Text(project.initials, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, decoration: project.isArchived ? TextDecoration.lineThrough : null))),
                ),
                if (project.isMuted)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.error, width: 1.5)),
                      child: SvgPicture.asset('assets/icons/mute.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                    ),
                  ),
                if (project.isArchived)
                  Positioned(
                    top: 0, left: 0,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.warning, width: 1.5)),
                      child: SvgPicture.asset('assets/icons/archive.svg', width: 10, height: 10, colorFilter: const ColorFilter.mode(AppColors.warning, BlendMode.srcIn)),
                    ),
                  ),
                if (project.isPinned)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
                      child: Icon(Icons.push_pin, color: AppColors.primary, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (project.isPinned) ...[
                        Icon(Icons.push_pin, color: AppColors.primary, size: 12),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: Text(project.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: project.isArchived ? textDimColor : textColor))),
                      if (project.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: SvgPicture.asset('assets/icons/mute.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(project.lastMessage, style: TextStyle(fontSize: 13, color: textDimColor, decoration: project.isArchived ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(project.time, style: TextStyle(fontSize: 12, color: textDimColor)),
                if (project.unread > 0 && !project.isMuted) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('${project.unread}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGridCard extends StatelessWidget {
  final _Project project;
  final VoidCallback onTap;
  const _ProjectGridCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: project.isArchived ? AppColors.warning.withOpacity(0.3) : borderColor)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [project.color, project.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                      child: Center(child: Text(project.initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                    ),
                    if (project.isMuted)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.error, width: 1.5)),
                          child: SvgPicture.asset('assets/icons/mute.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                        ),
                      ),
                    if (project.isArchived)
                      Positioned(
                        top: 0, left: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.warning, width: 1.5)),
                          child: SvgPicture.asset('assets/icons/archive.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(AppColors.warning, BlendMode.srcIn)),
                        ),
                      ),
                    if (project.isPinned)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: ThemeHelper.bg(context), shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
                          child: Icon(Icons.push_pin, color: AppColors.primary, size: 11),
                        ),
                      ),
                    if (project.unread > 0 && !project.isMuted)
                      Positioned(
                        top: -4, left: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('${project.unread}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (project.isPinned) ...[
                      Icon(Icons.push_pin, color: AppColors.primary, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Flexible(child: Text(project.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: project.isArchived ? textDimColor : textColor), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (project.isMuted) ...[
                      SvgPicture.asset('assets/icons/mute.svg', width: 10, height: 10, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
                      const SizedBox(width: 4),
                    ],
                    Text(project.time, style: TextStyle(fontSize: 11, color: textDimColor)),
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
