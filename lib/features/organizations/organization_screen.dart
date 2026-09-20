import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/utils/photo_picker_helper.dart';

class OrganizationScreen extends StatefulWidget {
  final String orgId;
  const OrganizationScreen({super.key, required this.orgId});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _backend = LocalBackend();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isEditing = false;
  Map<String, dynamic>? _org;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final org = await _backend.getOrganization(widget.orgId);
    final members = await _backend.getMembers(widget.orgId);
    final projects = await _backend.getProjectsByOrganization(widget.orgId);
    setState(() {
      _org = org;
      _members = members;
      _projects = projects;
      _isLoading = false;
      if (org != null) {
        _nameController.text = org['name'] ?? '';
        _descController.text = org['description'] ?? '';
      }
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    if (_isLoading) {
      return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
    }

    if (_org == null) {
      return Scaffold(backgroundColor: bgColor, body: Center(child: Text('Organisation non trouvee', style: TextStyle(color: textColor))));
    }

    final color = _parseColor(_org!['color']);
    final photo = _org!['photo'] ?? '';
    final name = _org!['name'] ?? '';
    final initials = _org!['initials'] ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/'),
                        child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn)),
                      ),
                      const SizedBox(width: 12),
                      photo.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.memory(base64Decode(photo), width: 40, height: 40, fit: BoxFit.cover))
                          : Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                              child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('${_projects.length} projets · ${_members.length} membres', style: TextStyle(fontSize: 12, color: AppColors.success)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = PhotoPickerHelper();
                          final bytes = await picker.pickImage();
                          if (bytes != null) {
                            final photoBase64 = base64Encode(bytes);
                            await _backend.updateOrganization(widget.orgId, {'photo': photoBase64});
                            _loadData();
                          }
                        },
                        child: Column(
                          children: [
                            photo.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.memory(base64Decode(photo), width: 80, height: 80, fit: BoxFit.cover))
                                : Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)]),
                                    child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))),
                                  ),
                            const SizedBox(height: 6),
                            Text('Appuyez pour changer', style: TextStyle(fontSize: 11, color: textDimColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _isEditing
                          ? TextField(controller: _nameController, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))
                          : Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextField(controller: _descController, style: TextStyle(fontSize: 14, color: textDimColor), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))
                          : Text(_org!['description'] ?? '', style: TextStyle(fontSize: 14, color: textDimColor)),
                      const SizedBox(height: 24),
                      _buildSection('Projets (${_projects.length})', _projects.map((p) => _buildProject(p)).toList()),
                      const SizedBox(height: 16),
                      _buildSection('Membres (${_members.length})', _members.map((m) => _buildMember(m)).toList()),
                      const SizedBox(height: 16),
                      _buildSection('Parametres', [
                        _buildSetting('Notifications', 'Gerer les alertes', 'bell.svg', _openNotificationSettings),
                        _buildSetting('Securite', 'Mots de passe et 2FA', 'lock.svg', _openSecuritySettings),
                        _buildSetting('API Keys', 'Cles d\'acces API', 'terminal.svg', _openApiKeysSettings),
                      ]),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Row(
              children: [
                Expanded(
                  child: _FloatingButton(
                    label: _isEditing ? 'Sauvegarder' : 'Modifier',
                    icon: _isEditing ? 'check-circle.svg' : 'settings.svg',
                    isPrimary: true,
                    onTap: () async {
                      if (_isEditing) {
                        await _backend.updateOrganization(widget.orgId, {
                          'name': _nameController.text,
                          'description': _descController.text,
                          'initials': _nameController.text.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join().substring(0, _nameController.text.split(' ').length.clamp(0, 2).toInt()),
                        });
                        _loadData();
                      }
                      setState(() => _isEditing = !_isEditing);
                    },
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(width: 12),
                  _FloatingButton(
                    label: 'Inviter',
                    icon: 'plus.svg',
                    isPrimary: false,
                    onTap: _inviteMember,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProject(Map<String, dynamic> project) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final photo = project['photo'] ?? '';
    final name = project['name'] ?? '';
    final status = project['status'] ?? '';
    final statusType = project['status_type'] ?? 'info';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.go('/projects/${project['id']}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ThemeHelper.bg(context).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
          child: Row(
            children: [
              photo.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(photo), width: 36, height: 36, fit: BoxFit.cover))
                  : Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: SvgPicture.asset('assets/icons/project.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                    if (status.isNotEmpty)
                      Text(status, style: TextStyle(fontSize: 12, color: statusType == 'success' ? AppColors.success : statusType == 'warning' ? AppColors.warning : statusType == 'error' ? AppColors.error : textDimColor)),
                  ],
                ),
              ),
              SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMember(Map<String, dynamic> member) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final name = member['name'] ?? '';
    final role = member['role'] ?? '';
    final email = member['email'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(50)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                Text('${role.toUpperCase()} · $email', style: TextStyle(fontSize: 12, color: textDimColor)),
              ],
            ),
          ),
          if (role != 'admin')
            GestureDetector(
              onTap: () async {
                await _backend.removeMember(widget.orgId, member['id']);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name retire du groupe'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: SvgPicture.asset('assets/icons/trash.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
              ),
            ),
        ],
      ),
    );
  }

  void _inviteMember() {
    final emailController = TextEditingController();
    String selectedRole = 'membre';
    final surfaceColor = ThemeHelper.surface(context);
    final bgColor = ThemeHelper.bg(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

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
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 20),
                  Text('Adresse email', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'jean@example.com',
                      hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
                      filled: true, fillColor: ThemeHelper.bg(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Role', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRoleChip('Admin', 'admin', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                      const SizedBox(width: 8),
                      _buildRoleChip('Membre', 'membre', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                      const SizedBox(width: 8),
                      _buildRoleChip('Lecteur', 'lecteur', selectedRole, (v) => setSheetState(() => selectedRole = v)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                      const SizedBox(width: 12),
                      Expanded(child: GestureDetector(
                        onTap: () async {
                          if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                            await _backend.addMember(widget.orgId, emailController.text.split('@')[0], emailController.text, selectedRole);
                            Navigator.pop(context);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyee a ${emailController.text}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
    final bgColor = ThemeHelper.bg(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.3) : borderColor),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? AppColors.primary : textDimColor, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final borderColor = ThemeHelper.borderLight(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceColor.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
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

  Widget _buildSetting(String title, String subtitle, String icon, VoidCallback onTap) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/$icon', width: 20, height: 20, colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)), Text(subtitle, style: TextStyle(fontSize: 12, color: textDimColor))])),
            SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
          ],
        ),
      ),
    );
  }

  void _openNotificationSettings() {
    bool backendAlerts = true;
    bool memberAlerts = true;
    bool securityAlerts = true;
    bool chatMessages = false;
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 20),
                  _buildToggle('Alertes backend', 'Notifications de statut des backends', backendAlerts, (v) => setSheetState(() => backendAlerts = v)),
                  _buildToggle('Alertes membres', 'Quand un membre rejoint/quitte', memberAlerts, (v) => setSheetState(() => memberAlerts = v)),
                  _buildToggle('Alertes securite', 'Alertes de securite importantes', securityAlerts, (v) => setSheetState(() => securityAlerts = v)),
                  _buildToggle('Messages chat', 'Notifications des messages', chatMessages, (v) => setSheetState(() => chatMessages = v)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: textDimColor)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 48, height: 28,
              decoration: BoxDecoration(
                color: value ? AppColors.success : ThemeHelper.borderLight(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSecuritySettings() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Securite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 20),
                _buildSecurityOption('Changer le mot de passe', 'Derniere modification il y a 30 jours', () {
                  Navigator.pop(context);
                  _showChangePasswordSheet();
                }),
                _buildSecurityOption('Authentification a deux facteurs (2FA)', 'Securite renforcee pour votre compte', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('2FA configure avec succes'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }),
                _buildSecurityOption('Historique des connexions', 'Voir les dernières connexions', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Aucune connexion recente'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOption(String title, String subtitle, VoidCallback onTap) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: ThemeHelper.bg(context).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textDimColor)),
                ],
              ),
            ),
            SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Changer le mot de passe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 20),
                TextField(controller: oldPassController, obscureText: true, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(hintText: 'Mot de passe actuel', hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 12),
                TextField(controller: newPassController, obscureText: true, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(hintText: 'Nouveau mot de passe', hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 12),
                TextField(controller: confirmPassController, obscureText: true, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(hintText: 'Confirmer le mot de passe', hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () {
                        if (newPassController.text == confirmPassController.text && newPassController.text.isNotEmpty) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Mot de passe change avec succes'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Les mots de passe ne correspondent pas'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                        }
                      },
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Changer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openApiKeysSettings() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Text('API Keys', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor))),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Nouvelle API key generee'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset('assets/icons/plus.svg', width: 14, height: 14, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                            const SizedBox(width: 4),
                            Text('Generer', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildApiKeyItem('prd_org_' + widget.orgId.substring(0, 8), 'Organisation', true),
                _buildApiKeyItem('prd_proj_' + 'abc12345', 'Projets', true),
                _buildApiKeyItem('prd_read_' + 'xyz67890', 'Lecture seule', false),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyItem(String key, String label, bool isActive) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: ThemeHelper.bg(context).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: isActive ? AppColors.success : AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
                Text(key, style: TextStyle(fontSize: 12, color: textDimColor, fontFamily: 'monospace')),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('API key copiee'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: SvgPicture.asset('assets/icons/copy.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool isPrimary;
  final VoidCallback onTap;
  const _FloatingButton({required this.label, required this.icon, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isPrimary ? AppColors.gradient : null,
              color: isPrimary ? null : surfaceColor.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isPrimary ? Colors.transparent : borderColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icons/$icon', width: 18, height: 18, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
