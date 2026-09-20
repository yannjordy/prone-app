import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/notification_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import '../../app/app.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String _userEmail = '';
  String _userInitials = '';
  String _userPhone = '';
  String _userBio = '';
  Uint8List? _profileImageBytes;
  bool _notifEnabled = true;
  String _selectedLanguage = 'Francais';
  bool _loading = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await PushNotificationService.initialize();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('profile_name') ?? '';
      _userEmail = prefs.getString('profile_email') ?? '';
      _userPhone = prefs.getString('profile_phone') ?? '';
      _userBio = prefs.getString('profile_bio') ?? '';
      _notifEnabled = PushNotificationService.permissionGranted;
      _selectedLanguage = prefs.getString('profile_language') ?? 'Francais';
      _nameController.text = _userName;
      _emailController.text = _userEmail;
      _userInitials = _userName.isNotEmpty
        ? _userName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
      try {
        final photoStr = prefs.getString('profile_photo');
        if (photoStr != null && photoStr.isNotEmpty) {
          _profileImageBytes = base64Decode(photoStr);
        }
      } catch (_) {}
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _userName);
    await prefs.setString('profile_email', _userEmail);
    await prefs.setString('profile_phone', _userPhone);
    await prefs.setString('profile_bio', _userBio);
    await prefs.setBool('profile_notif_enabled', _notifEnabled);
    await prefs.setString('profile_language', _selectedLanguage);
    if (_profileImageBytes != null) {
      await prefs.setString('profile_photo', base64Encode(_profileImageBytes!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: SvgPicture.asset('assets/icons/profile.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Text('PROFILE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
          ]),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _changePhoto,
              child: Stack(children: [
                Container(width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: _profileImageBytes == null ? AppColors.gradient : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(20),
                    child: _profileImageBytes != null
                      ? Image.memory(_profileImageBytes!, fit: BoxFit.cover, width: 80, height: 80)
                      : Center(child: Text(_userInitials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))))),
                Positioned(bottom: -2, right: -2,
                  child: Container(width: 28, height: 28,
                    decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle, border: Border.all(color: borderColor)),
                    child: Center(child: SvgPicture.asset('assets/icons/camera.svg', width: 14, height: 14, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(_userName.isNotEmpty ? _userName : 'Non defini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor))),
          const SizedBox(height: 4),
          Center(child: Text(_userEmail.isNotEmpty ? _userEmail : 'Non defini', style: TextStyle(fontSize: 14, color: textDimColor))),
          const SizedBox(height: 32),
          _MenuItem(icon: 'assets/icons/profile.svg', label: 'Modifier le profil', onTap: _editProfile),
          _MenuItem(icon: 'assets/icons/lock.svg', label: 'Changer le mot de passe', onTap: _changePassword),
          _MenuItem(icon: 'assets/icons/bell.svg', label: 'Notifications', onTap: _notifications),
          _MenuItem(icon: 'assets/icons/globe.svg', label: 'Langue', onTap: _language),
          _MenuItem(icon: 'assets/icons/moon.svg', label: 'Theme', onTap: _theme),
          const SizedBox(height: 16),
          _MenuItem(icon: 'assets/icons/log-out.svg', label: 'Deconnexion', color: AppColors.error, onTap: _logout),
        ],
      ),
    );
  }

  void _changePhoto() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Changer la photo de profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              const SizedBox(height: 16),
              _buildPhotoOption('Supprimer la photo', Icons.delete_outline, () async {
                Navigator.pop(context);
                setState(() => _profileImageBytes = null);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('profile_photo');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo supprimee'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              }),
              _buildPhotoOption('Prendre une photo', Icons.camera_alt, () async {
                Navigator.pop(context);
                try {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() => _profileImageBytes = bytes);
                    await _saveProfile();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise a jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
                }
              }),
              _buildPhotoOption('Choisir depuis la galerie', Icons.photo_library, () async {
                Navigator.pop(context);
                try {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() => _profileImageBytes = bytes);
                    await _saveProfile();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Photo mise a jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
                }
              }),
              const SizedBox(height: 16),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))))),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ]),
          )),
      ),
    );
  }

  Widget _buildPhotoOption(String label, IconData icon, VoidCallback onTap) {
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
        child: Row(children: [Icon(icon, color: ThemeHelper.textDim(context), size: 20), const SizedBox(width: 12), Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)))]))));
  }

  void _editProfile() {
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final borderColor = ThemeHelper.borderLight(context);
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Modifier le profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 20),
              _buildInput('Nom complet', _nameController),
              const SizedBox(height: 12),
              _buildInput('Email', _emailController),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                    child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () async {
                  setState(() {
                    _userName = _nameController.text;
                    _userEmail = _emailController.text;
                    _userInitials = _userName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
                  });
                  await _saveProfile();
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profil mis a jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]),
            ]),
          )),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
      const SizedBox(height: 6),
      TextField(controller: controller, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
        decoration: InputDecoration(filled: true, fillColor: ThemeHelper.bg(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeHelper.borderLight(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
    ]);
  }

  void _changePassword() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Changer le mot de passe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              const SizedBox(height: 20),
              TextField(controller: oldPassController, obscureText: true, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
                decoration: InputDecoration(hintText: 'Mot de passe actuel', hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
              const SizedBox(height: 12),
              TextField(controller: newPassController, obscureText: true, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
                decoration: InputDecoration(hintText: 'Nouveau mot de passe', hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
              const SizedBox(height: 12),
              TextField(controller: confirmPassController, obscureText: true, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
                decoration: InputDecoration(hintText: 'Confirmer le mot de passe', hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                    child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () async {
                  if (newPassController.text.isEmpty || newPassController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Le mot de passe doit faire au moins 6 caracteres'), backgroundColor: AppColors.error));
                    return;
                  }
                  if (newPassController.text != confirmPassController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Les mots de passe ne correspondent pas'), backgroundColor: AppColors.error));
                    return;
                  }
                  final prefs = await SharedPreferences.getInstance();
                  final savedPass = prefs.getString('profile_password') ?? '';
                  if (savedPass.isNotEmpty && oldPassController.text != savedPass) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Mot de passe actuel incorrect'), backgroundColor: AppColors.error));
                    return;
                  }
                  await prefs.setString('profile_password', newPassController.text);
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Mot de passe mis a jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]),
            ]),
          )),
      ),
    );
  }

  void _notifications() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Activer les notifications', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))),
                  Switch(value: _notifEnabled, onChanged: (v) async {
                    setSheetState(() => _notifEnabled = v);
                    setState(() => _notifEnabled = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('profile_notif_enabled', v);
                  }, activeColor: AppColors.primary),
                ]),
                const SizedBox(height: 16),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Fermer', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))))),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ]),
            )),
        ),
      ),
    );
  }

  void _language() {
    final languages = ['Francais', 'English', 'Espanol', 'Deutsch'];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Langue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              const SizedBox(height: 16),
              ...languages.map((lang) => Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Material(color: Colors.transparent, child: InkWell(onTap: () async {
                  setState(() => _selectedLanguage = lang);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('profile_language', lang);
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Langue: $lang'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }, borderRadius: BorderRadius.circular(12),
                  child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedLanguage == lang ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedLanguage == lang ? AppColors.primary : ThemeHelper.borderLight(context))),
                    child: Row(children: [
                      Text(lang, style: TextStyle(fontSize: 14, color: _selectedLanguage == lang ? AppColors.primary : ThemeHelper.text(context))),
                      const Spacer(),
                      if (_selectedLanguage == lang) Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                    ])))))),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ]),
          )),
      ),
    );
  }

  void _theme() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              const SizedBox(height: 16),
              _buildThemeOption('Sombre', Icons.dark_mode, ThemeMode.dark),
              _buildThemeOption('Clair', Icons.light_mode, ThemeMode.light),
              _buildThemeOption('Systeme', Icons.brightness_auto, ThemeMode.system),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ]),
          )),
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, ThemeMode mode) {
    final isCurrent = currentThemeMode == mode;
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: () { setThemeMode(mode); Navigator.pop(context); setState(() {}); },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCurrent ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context))),
          child: Row(children: [
            Icon(icon, color: isCurrent ? AppColors.primary : ThemeHelper.textDim(context), size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: isCurrent ? AppColors.primary : ThemeHelper.text(context))),
            const Spacer(),
            if (isCurrent) Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          ])))));
  }

  void _logout() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.logout, color: AppColors.error, size: 28)),
              const SizedBox(height: 16),
              Text('Se deconnecter ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              const SizedBox(height: 8),
              Text('Vous devrez vous reconnecter.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                    child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_backend', false);
                  Navigator.pop(context);
                  if (!mounted) return;
                  context.go('/login');
                }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Deconnexion', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ]),
          )),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(color: ThemeHelper.surface(context).withOpacity(0.5), borderRadius: BorderRadius.circular(14),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
          child: Padding(padding: const EdgeInsets.all(14),
            child: Row(children: [
              SvgPicture.asset(icon, width: 18, height: 18, colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: itemColor)),
              const Spacer(),
              SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(itemColor.withOpacity(0.5), BlendMode.srcIn)),
            ])))));
  }
}
