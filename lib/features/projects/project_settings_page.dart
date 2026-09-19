import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/utils/photo_picker_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/local/local_backend.dart';

class ProjectSettingsPage extends StatefulWidget {
  final String projectId;
  const ProjectSettingsPage({super.key, required this.projectId});

  @override
  State<ProjectSettingsPage> createState() => _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends State<ProjectSettingsPage> with SingleTickerProviderStateMixin {
  final _backend = LocalBackend();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isEditing = false;
  bool _isAdmin = true;
  String _projectName = '';
  String _projectDesc = '';
  String _apiKey = '';
  String _backendUrl = '';
  Uint8List? _projectImageBytes;
  bool _isLoading = true;
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = true;

  static const Map<String, int> _rolePriority = {'admin': 0, 'editor': 1, 'viewer': 2, 'member': 3};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProject();
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final projects = await _backend.getProjects();
    final p = projects.firstWhere((p) => p['id'] == widget.projectId, orElse: () => <String, dynamic>{});
    final prefs = await SharedPreferences.getInstance();
    final savedImage = prefs.getString('project_image_${widget.projectId}');
    if (savedImage != null && savedImage.isNotEmpty) {
      try { _projectImageBytes = base64Decode(savedImage); } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _projectName = (p['name'] as String?) ?? '';
        _projectDesc = (p['description'] as String?) ?? '';
        _apiKey = (p['api_key'] as String?) ?? '';
        _backendUrl = (p['backend_url'] as String?) ?? '';
        _nameController.text = _projectName;
        _descController.text = _projectDesc;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    final orgs = await _backend.getOrganizations();
    if (orgs.isEmpty) { if (mounted) setState(() { _members = []; _membersLoading = false; }); return; }
    final orgId = (orgs.first['id'] as String?) ?? '';
    final members = await _backend.getMembers(orgId);
    members.sort((a, b) {
      final roleA = _rolePriority[(a['role'] as String?) ?? 'member'] ?? 3;
      final roleB = _rolePriority[(b['role'] as String?) ?? 'member'] ?? 3;
      if (roleA != roleB) return roleA.compareTo(roleB);
      return ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? '');
    });
    if (mounted) setState(() { _members = members; _membersLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(textColor, textDimColor, borderColor),
          const SizedBox(height: 8),
          _buildTabBar(textColor, textDimColor, surfaceColor, borderColor),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfosTab(surfaceColor, borderColor, textColor, textDimColor),
                _buildMembersTab(surfaceColor, borderColor, textColor, textDimColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color textDimColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn))),
          const SizedBox(width: 12),
          Expanded(child: Text('Parametres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor))),
          GestureDetector(
            onTap: _toggleEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isEditing ? AppColors.success.withOpacity(0.15) : ThemeHelper.bg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _isEditing ? AppColors.success.withOpacity(0.3) : borderColor),
              ),
              child: Text(_isEditing ? 'Sauvegarder' : 'Modifier', style: TextStyle(fontSize: 13, color: _isEditing ? AppColors.success : textDimColor, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color textColor, Color textDimColor, Color surfaceColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: textDimColor,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(10),
          tabs: const [Tab(text: 'Infos'), Tab(text: 'Membres')],
        ),
      ),
    );
  }

  void _toggleEdit() {
    if (_isEditing) _saveProject();
    setState(() => _isEditing = !_isEditing);
  }

  Future<void> _saveProject() async {
    await _backend.updateProject(widget.projectId, {'name': _nameController.text, 'description': _descController.text});
    setState(() { _projectName = _nameController.text; _projectDesc = _descController.text; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Parametres sauvegardes'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ======================== INFOS TAB ========================
  Widget _buildInfosTab(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildSection('Photo du projet', [_buildPhotoSection(surfaceColor, borderColor, textColor, textDimColor)], surfaceColor, borderColor, textColor),
        const SizedBox(height: 12),
        _buildSection('Informations', [
          _buildField('Nom du projet', _nameController, _isEditing, textColor, textDimColor, borderColor),
          const SizedBox(height: 12),
          _buildField('Description', _descController, _isEditing, textColor, textDimColor, borderColor),
        ], surfaceColor, borderColor, textColor),
        const SizedBox(height: 12),
        _buildSection('Securite', [
          _buildSecurityRow('API Key', _maskKey(_apiKey), 'terminal.svg', _isAdmin ? () => _copyToClipboard(_apiKey) : null, textColor, textDimColor),
          const SizedBox(height: 8),
          _buildSecurityRow('Backend URL', _backendUrl, 'globe.svg', _isAdmin ? () => _copyToClipboard(_backendUrl) : null, textColor, textDimColor),
          if (!_isAdmin)
            Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
              Icon(Icons.lock_outline, size: 14, color: textDimColor),
              const SizedBox(width: 6),
              Text('Seuls les administrateurs peuvent copier', style: TextStyle(fontSize: 11, color: textDimColor)),
            ])),
        ], surfaceColor, borderColor, textColor),
        const SizedBox(height: 12),
        _buildSection('Danger Zone', [
          _buildDangerButton('Supprimer le projet', AppColors.error, () => _confirmDelete(surfaceColor, borderColor, textColor, textDimColor), textColor),
        ], surfaceColor, borderColor, textColor),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children, Color surfaceColor, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildPhotoSection(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    final initials = _projectName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    return Row(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)),
          child: ClipOval(
            child: _projectImageBytes != null
                ? Image.memory(_projectImageBytes!, width: 64, height: 64, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])),
                    child: Center(child: Text(initials.isEmpty ? '??' : initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Photo du projet', style: TextStyle(fontSize: 14, color: textColor)),
          Text('JPG, PNG ou GIF', style: TextStyle(fontSize: 12, color: textDimColor)),
        ])),
        GestureDetector(
          onTap: _changePhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
            child: Text('Changer', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Future<void> _changePhoto() async {
    try {
      final bytes = await PhotoPickerHelper.instance.pickImage();
      if (bytes != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('project_image_${widget.projectId}', base64Encode(bytes));
        setState(() => _projectImageBytes = Uint8List.fromList(bytes));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise a jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Widget _buildField(String label, TextEditingController controller, bool enabled, Color textColor, Color textDimColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textDimColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller, enabled: enabled,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            filled: true, fillColor: ThemeHelper.bg(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRow(String title, String value, String icon, VoidCallback? onTap, Color textColor, Color textDimColor) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset('assets/icons/$icon', width: 18, height: 18, colorFilter: ColorFilter.mode(onTap != null ? textDimColor : textDimColor.withOpacity(0.4), BlendMode.srcIn)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, color: textColor)),
            Text(value, style: TextStyle(fontSize: 11, color: textDimColor, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ])),
          Icon(onTap != null ? Icons.copy_rounded : Icons.lock_outline, size: 16, color: onTap != null ? textDimColor : textDimColor.withOpacity(0.4)),
        ],
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Copie dans le presse-papier'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Widget _buildDangerButton(String title, Color color, VoidCallback onTap, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: color))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('Supprimer', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  void _confirmDelete(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, useRootNavigator: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28)),
              const SizedBox(height: 16),
              Text('Supprimer le projet ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Text('Cette action est irreversible.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textDimColor)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () async {
                  Navigator.pop(ctx);
                  await _backend.deleteProject(widget.projectId);
                  if (!mounted) return;
                  Navigator.pop(context);
                }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ]),
          ),
        ),
      ),
    );
  }

  // ======================== MEMBERS TAB ========================
  Widget _buildMembersTab(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    if (_membersLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_members.length} membre${_members.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 13, color: textDimColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showInviteMember(surfaceColor, borderColor, textColor, textDimColor),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Inviter', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _members.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 48, color: textDimColor),
                  const SizedBox(height: 12),
                  Text('Aucun membre', style: TextStyle(fontSize: 16, color: textDimColor)),
                  const SizedBox(height: 4),
                  Text('Invitez des personnes a rejoindre', style: TextStyle(fontSize: 13, color: textDimColor.withOpacity(0.6))),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final name = (m['name'] as String?) ?? '';
                    final email = (m['email'] as String?) ?? '';
                    final role = (m['role'] as String?) ?? 'member';
                    final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
                    final colorValue = name.hashCode.abs() % 0xFFFFFF;
                    final roleColor = role == 'admin' ? AppColors.error : role == 'editor' ? AppColors.primary : AppColors.success;
                    final isLastAdmin = role == 'admin' && _members.where((m2) => (m2['role'] as String?) == 'admin').length <= 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: Color(0xFF000000 + colorValue).withOpacity(0.2), shape: BoxShape.circle),
                            child: Center(child: Text(initials.isEmpty ? '?' : initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF000000 + colorValue)))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                            Text(email, style: TextStyle(fontSize: 12, color: textDimColor), overflow: TextOverflow.ellipsis),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor)),
                          ),
                          const SizedBox(width: 8),
                          if (isLastAdmin)
                            Icon(Icons.shield, size: 18, color: AppColors.warning)
                          else
                            GestureDetector(
                              onTap: () => _confirmRemoveMember(m['id'] as String, name, surfaceColor, borderColor, textColor, textDimColor),
                              child: Icon(Icons.close_rounded, size: 18, color: AppColors.error.withOpacity(0.7)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showInviteMember(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, useRootNavigator: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('Choisissez une methode', style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () { Navigator.pop(ctx); _showEmailInvite(surfaceColor, borderColor, textColor, textDimColor); },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Icon(Icons.email_outlined, color: AppColors.primary, size: 20))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Par email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                        Text('Envoyer une invitation par email', style: TextStyle(fontSize: 12, color: textDimColor)),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: textDimColor, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () { Navigator.pop(ctx); _showQRInvite(surfaceColor, borderColor, textColor, textDimColor); },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Icon(Icons.qr_code, color: AppColors.success, size: 20))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Par QR Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                        Text('Scanner pour rejoindre le projet', style: TextStyle(fontSize: 12, color: textDimColor)),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: textDimColor, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14))))),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailInvite(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    final emailCtrl = TextEditingController();
    String selectedRole = 'viewer';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, useRootNavigator: true, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Inviter par email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 8),
                  Text("L'utilisateur doit avoir un compte Prone", style: TextStyle(fontSize: 13, color: textDimColor)),
                  const SizedBox(height: 20),
                  Text('Adresse email', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'jean@example.com',
                      hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
                      filled: true, fillColor: ThemeHelper.bg(ctx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Role', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 8),
                  Row(children: ['admin', 'editor', 'viewer'].map((r) {
                    final isSelected = selectedRole == r;
                    final rColor = r == 'admin' ? AppColors.error : r == 'editor' ? AppColors.primary : AppColors.success;
                    final label = r == 'admin' ? 'Admin' : r == 'editor' ? 'Membre' : 'Lecteur';
                    return Expanded(child: GestureDetector(
                      onTap: () => setModalState(() => selectedRole = r),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: isSelected ? rColor.withOpacity(0.15) : ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? rColor : borderColor)),
                        child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? rColor : textDimColor))),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        if (emailCtrl.text.isEmpty || !emailCtrl.text.contains('@')) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: const Text('Email invalide'), backgroundColor: AppColors.error));
                          return;
                        }
                        final email = emailCtrl.text.trim();
                        final name = email.split('@')[0];
                        final orgs = await _backend.getOrganizations();
                        if (orgs.isNotEmpty) await _backend.addMember((orgs.first['id'] as String?) ?? '', name, email, selectedRole);
                        Navigator.pop(ctx);
                        _loadMembers();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyee a $email'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      },
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Envoyer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQRInvite(Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    final inviteLink = 'prone://invite/\${widget.projectId}';
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, useRootNavigator: true, isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('QR Code d\'invitation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('Scannez pour rejoindre le projet', style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)]),
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
                  decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                  child: Text(inviteLink, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textDimColor, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: const Text('Lien copie'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  },
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Copier le lien', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)))),
                ),
                const SizedBox(height: 10),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Fermer', style: TextStyle(color: AppColors.primary, fontSize: 14))))),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveMember(String memberId, String name, Color surfaceColor, Color borderColor, Color textColor, Color textDimColor) {
    final isAdmin = _members.firstWhere((m) => m['id'] == memberId, orElse: () => {})['role'] == 'admin';
    final adminCount = _members.where((m) => (m['role'] as String?) == 'admin').length;

    if (isAdmin && adminCount <= 1) {
      showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent, useRootNavigator: true,
        builder: (ctx) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28)),
                const SizedBox(height: 16),
                Text('Dernier administrateur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('$name est le seul administrateur.\nRetirer ce membre supprimera le projet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(onTap: () async {
                    Navigator.pop(ctx);
                    await _backend.deleteProject(widget.projectId);
                    if (!mounted) return;
                    Navigator.pop(context);
                  }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer le projet', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                ]),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ]),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, useRootNavigator: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Retirer $name ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Text('Ce membre n\'aura plus acces au projet.', style: TextStyle(fontSize: 13, color: textDimColor)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(ctx), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () async {
                  Navigator.pop(ctx);
                  final orgs = await _backend.getOrganizations();
                  if (orgs.isNotEmpty) await _backend.removeMember((orgs.first['id'] as String?) ?? '', memberId);
                  _loadMembers();
                }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Retirer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ]),
          ),
        ),
      ),
    );
  }
}
