import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  bool _isConnected = true;
  final _nameController = TextEditingController(text: 'Prone Team');
  final _descController = TextEditingController(text: 'Équipe de développement');
  bool _isEditing = false;

  final List<_OrgMember> _members = [
    _OrgMember(name: 'John Doe', role: 'Admin', initials: 'JD', color: AppColors.primary, email: 'john@example.com', status: 'active'),
    _OrgMember(name: 'Jane Smith', role: 'Membre', initials: 'JS', color: AppColors.primaryDark, email: 'jane@example.com', status: 'active'),
    _OrgMember(name: 'Bob Wilson', role: 'Membre', initials: 'BW', color: AppColors.success, email: 'bob@example.com', status: 'active'),
  ];

  final List<_Invitation> _invitations = [
    _Invitation(email: 'alice@example.com', sentAt: 'Il y a 2h', status: 'pending'),
    _Invitation(email: 'charlie@example.com', sentAt: 'Il y a 1j', status: 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

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
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(50)),
                        child: Center(child: SvgPicture.asset('assets/icons/orgs.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mon Organisation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: _isConnected ? AppColors.success : AppColors.error, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(_isConnected ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, color: _isConnected ? AppColors.success : AppColors.error)),
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
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16)]),
                        child: Center(child: SvgPicture.asset('assets/icons/orgs.svg', width: 36, height: 36, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                      ),
                      const SizedBox(height: 16),
                      _isEditing
                          ? TextField(controller: _nameController, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))
                          : Text('Prone Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextField(controller: _descController, style: TextStyle(fontSize: 14, color: textDimColor), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))
                          : Text('Équipe de développement', style: TextStyle(fontSize: 14, color: textDimColor)),
                      const SizedBox(height: 24),
                      _buildSection('Membres', [
                        ..._members.map((m) => _buildMember(m)),
                      ]),
                      const SizedBox(height: 16),
                      if (_invitations.isNotEmpty)
                        _buildSection('Invitations en attente', [
                          ..._invitations.map((inv) => _buildInvitation(inv)),
                        ]),
                      if (_invitations.isNotEmpty) const SizedBox(height: 16),
                      _buildSection('Paramètres', [
                        _buildSetting('Notifications', 'Gérer les alertes', 'bell.svg', () {}),
                        _buildSetting('Sécurité', 'Mots de passe et 2FA', 'lock.svg', () {}),
                        _buildSetting('Facturation', 'Plan et paiements', 'grid.svg', () {}),
                        _buildSetting('API Keys', 'Clés d\'accès API', 'terminal.svg', () {}),
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
                    onTap: () => setState(() => _isEditing = !_isEditing),
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

  void _inviteMember() {
    final emailController = TextEditingController();
    String selectedRole = 'Membre';
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
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 8),
                  Text('L\'utilisateur doit avoir un compte Prone', style: TextStyle(fontSize: 13, color: textDimColor)),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adresse email', style: TextStyle(fontSize: 12, color: textDimColor)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'jean@example.com',
                          hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: ThemeHelper.bg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rôle', style: TextStyle(fontSize: 12, color: textDimColor)),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('L\'utilisateur recevra une notification. Une fois acceptée, le projet apparaîtra dans sa liste de projets.', style: TextStyle(fontSize: 12, color: textDimColor))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                      const SizedBox(width: 12),
                      Expanded(child: GestureDetector(
                        onTap: () {
                          if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                            setState(() {
                              _invitations.add(_Invitation(email: emailController.text, sentAt: 'Maintenant', status: 'pending'));
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

  Widget _buildInvitation(_Invitation inv) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.2))),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
              child: Center(child: Icon(Icons.mail_outline, color: AppColors.warning, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.email, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
                  Text('Envoyée ${inv.sentAt}', style: TextStyle(fontSize: 11, color: textDimColor)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _invitations.remove(inv));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation annulée'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, color: AppColors.error, size: 16),
              ),
            ),
          ],
        ),
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

  Widget _buildMember(_OrgMember member) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [member.color, member.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
            child: Center(child: Text(member.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                Text('${member.role} • ${member.email}', style: TextStyle(fontSize: 12, color: textDimColor)),
              ],
            ),
          ),
          if (member.role != 'Admin')
            GestureDetector(
              onTap: () {
                setState(() => _members.remove(member));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member.name} retiré du groupe'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
}

class _OrgMember {
  final String name;
  final String role;
  final String initials;
  final Color color;
  final String email;
  final String status;
  _OrgMember({required this.name, required this.role, required this.initials, required this.color, required this.email, required this.status});
}

class _Invitation {
  final String email;
  final String sentAt;
  final String status;
  _Invitation({required this.email, required this.sentAt, required this.status});
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
