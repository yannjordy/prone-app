import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:ui';
import '../../app/app.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'John Doe';
  String _userEmail = 'john@example.com';
  String _userInitials = 'JD';
  final _nameController = TextEditingController(text: 'John Doe');
  final _emailController = TextEditingController(text: 'john@example.com');
  final _picker = ImagePicker();
  Uint8List? _profileImageBytes;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Center(child: SvgPicture.asset('assets/icons/profile.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
              ),
              const SizedBox(width: 12),
              Text('PROFILE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _changePhoto,
              child: Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(gradient: _profileImageBytes == null ? AppColors.gradient : null, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _profileImageBytes != null
                          ? Image.memory(_profileImageBytes!, fit: BoxFit.cover, width: 80, height: 80)
                          : Center(child: Text(_userInitials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                    ),
                  ),
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle, border: Border.all(color: borderColor)),
                      child: Center(child: SvgPicture.asset('assets/icons/camera.svg', width: 14, height: 14, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(_userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor))),
          const SizedBox(height: 4),
          Center(child: Text(_userEmail, style: TextStyle(fontSize: 14, color: textDimColor))),
          const SizedBox(height: 32),
          _MenuItem(icon: 'assets/icons/profile.svg', label: 'Edit Profile', onTap: _editProfile),
          _MenuItem(icon: 'assets/icons/lock.svg', label: 'Change Password', onTap: _changePassword),
          _MenuItem(icon: 'assets/icons/bell.svg', label: 'Notifications', onTap: _notifications),
          _MenuItem(icon: 'assets/icons/globe.svg', label: 'Language', onTap: _language),
          _MenuItem(icon: 'assets/icons/moon.svg', label: 'Theme', onTap: _theme),
          const SizedBox(height: 16),
          _MenuItem(icon: 'assets/icons/log-out.svg', label: 'Logout', color: AppColors.error, onTap: _logout),
        ],
      ),
    );
  }

  void _changePhoto() {
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
                Text('Changer la photo de profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildPhotoOption('Prendre une photo', Icons.camera_alt, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() => _profileImageBytes = bytes);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise à jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                _buildPhotoOption('Choisir depuis la galerie', Icons.photo_library, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() => _profileImageBytes = bytes);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise à jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                _buildPhotoOption('Choisir un fichier', Icons.attach_file, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() => _profileImageBytes = bytes);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise à jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOption(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
          child: Row(children: [Icon(icon, color: ThemeHelper.textDim(context), size: 20), const SizedBox(width: 12), Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)))]),
        ),
      ),
    );
  }

  void _editProfile() {
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final borderColor = ThemeHelper.borderLight(context);
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
                Text('Modifier le profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 20),
                _buildInput('Nom', _nameController),
                const SizedBox(height: 12),
                _buildInput('Email', _emailController),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { setState(() { _userName = _nameController.text; _userEmail = _emailController.text; _userInitials = _userName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase(); }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profil mis à jour'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
        const SizedBox(height: 6),
        TextField(controller: controller, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)), decoration: InputDecoration(filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeHelper.borderLight(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      ],
    );
  }

  void _changePassword() {
    final _oldPassController = TextEditingController();
    final _newPassController = TextEditingController();
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
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
                Text('Changer le mot de passe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 20),
                TextField(controller: _oldPassController, obscureText: true, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)), decoration: InputDecoration(hintText: 'Mot de passe actuel', hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 12),
                TextField(controller: _newPassController, obscureText: true, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)), decoration: InputDecoration(hintText: 'Nouveau mot de passe', hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Mot de passe mis à jour'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _notifications() {
    bool notifEnabled = true;
    final surfaceColor = ThemeHelper.surface(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Activer les notifications', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))), Switch(value: notifEnabled, onChanged: (v) => setSheetState(() => notifEnabled = v), activeColor: AppColors.primary)]),
                  const SizedBox(height: 16),
                  GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Fermer', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))))),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _language() {
    final languages = ['Français', 'English', 'Español', 'Deutsch'];
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
                Text('Langue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                ...languages.map((lang) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.transparent, child: InkWell(onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Langue: $lang'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Text(lang, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)))))))),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _theme() {
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
                Text('Thème', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildThemeOption('Sombre', Icons.dark_mode, ThemeMode.dark),
                _buildThemeOption('Clair', Icons.light_mode, ThemeMode.light),
                _buildThemeOption('Système', Icons.brightness_auto, ThemeMode.system),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, ThemeMode mode) {
    final isCurrent = currentThemeMode == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { setThemeMode(mode); Navigator.pop(context); setState(() {}); },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCurrent ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context)),
            ),
            child: Row(
              children: [
                Icon(icon, color: isCurrent ? AppColors.primary : ThemeHelper.textDim(context), size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 14, color: isCurrent ? AppColors.primary : ThemeHelper.text(context))),
                const Spacer(),
                if (isCurrent) Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout() {
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
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.logout, color: AppColors.error, size: 28)),
                const SizedBox(height: 16),
                Text('Se déconnecter ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Vous devrez vous reconnecter.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { Navigator.pop(context); context.go('/login'); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Déconnexion', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
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
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? ThemeHelper.text(context);
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SvgPicture.asset(icon, width: 18, height: 18, colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn)),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 14, color: itemColor)),
                const Spacer(),
                SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(itemColor.withOpacity(0.5), BlendMode.srcIn)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
