import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../app/app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifEnabled = true;
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _soundEnabled = true;
  String _selectedLanguage = 'Francais';
  String _selectedTheme = 'Sombre';
  bool _isPrivateProfile = true;
  bool _showOnlineStatus = true;
  bool _readReceipts = false;
  bool _autoBackup = true;
  bool _darkMode = true;
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('settings_notif_enabled') ?? true;
      _pushEnabled = prefs.getBool('settings_push_enabled') ?? true;
      _emailEnabled = prefs.getBool('settings_email_enabled') ?? false;
      _soundEnabled = prefs.getBool('settings_sound_enabled') ?? true;
      _selectedLanguage = prefs.getString('settings_language') ?? 'Francais';
      _selectedTheme = prefs.getString('settings_theme') ?? 'Sombre';
      _isPrivateProfile = prefs.getBool('settings_private_profile') ?? true;
      _showOnlineStatus = prefs.getBool('settings_online_status') ?? true;
      _readReceipts = prefs.getBool('settings_read_receipts') ?? false;
      _autoBackup = prefs.getBool('settings_auto_backup') ?? true;
      _darkMode = prefs.getBool('settings_dark_mode') ?? true;
      _compactMode = prefs.getBool('settings_compact_mode') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: Center(child: SvgPicture.asset('assets/icons/settings.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
              ),
              const SizedBox(width: 12),
              Text('SETTINGS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _SettingsSection(title: 'Compte', children: [
                    _SettingsItem(icon: 'assets/icons/profile.svg', label: 'Mon profil', onTap: _account),
                    _SettingsItem(icon: 'assets/icons/lock.svg', label: 'Securite', onTap: _security),
                    _SettingsItem(icon: 'assets/icons/shield.svg', label: 'Confidentialite', onTap: _privacy),
                  ]),
                  const SizedBox(height: 16),
                  _SettingsSection(title: 'Notifications', children: [
                    _SettingsItem(
                      icon: 'assets/icons/bell.svg',
                      label: 'Notifications',
                      trailing: Switch(
                        value: _notifEnabled,
                        onChanged: (v) {
                          setState(() => _notifEnabled = v);
                          _saveSetting('settings_notif_enabled', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/bell.svg',
                      label: 'Push',
                      trailing: Switch(
                        value: _pushEnabled,
                        onChanged: (v) {
                          setState(() => _pushEnabled = v);
                          _saveSetting('settings_push_enabled', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/bell.svg',
                      label: 'Email',
                      trailing: Switch(
                        value: _emailEnabled,
                        onChanged: (v) {
                          setState(() => _emailEnabled = v);
                          _saveSetting('settings_email_enabled', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/bell.svg',
                      label: 'Sons',
                      trailing: Switch(
                        value: _soundEnabled,
                        onChanged: (v) {
                          setState(() => _soundEnabled = v);
                          _saveSetting('settings_sound_enabled', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _SettingsSection(title: 'Apparence', children: [
                    _SettingsItem(icon: 'assets/icons/moon.svg', label: 'Theme', value: _selectedTheme, onTap: _theme),
                    _SettingsItem(icon: 'assets/icons/globe.svg', label: 'Langue', value: _selectedLanguage, onTap: _language),
                    _SettingsItem(
                      icon: 'assets/icons/grid.svg',
                      label: 'Mode compact',
                      trailing: Switch(
                        value: _compactMode,
                        onChanged: (v) {
                          setState(() => _compactMode = v);
                          _saveSetting('settings_compact_mode', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _SettingsSection(title: 'Donnees', children: [
                    _SettingsItem(icon: 'assets/icons/database.svg', label: 'Stockage', onTap: _dataStorage),
                    _SettingsItem(
                      icon: 'assets/icons/database.svg',
                      label: 'Sauvegarde auto',
                      trailing: Switch(
                        value: _autoBackup,
                        onChanged: (v) {
                          setState(() => _autoBackup = v);
                          _saveSetting('settings_auto_backup', v);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _SettingsSection(title: 'A propos', children: [
                    _SettingsItem(icon: 'assets/icons/info.svg', label: 'Version', value: '1.0.0', onTap: () {}),
                    _SettingsItem(icon: 'assets/icons/info.svg', label: 'Conditions d\'utilisation', onTap: () {}),
                    _SettingsItem(icon: 'assets/icons/info.svg', label: 'Politique de confidentialite', onTap: () {}),
                  ]),
                  const SizedBox(height: 16),
                  _SettingsSection(title: 'Session', children: [
                    _SettingsItem(icon: 'assets/icons/log-out.svg', label: 'Deconnexion', color: AppColors.error, onTap: _logout),
                  ]),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _account() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 16),
                _buildOption('Modifier le profil', 'profile.svg', AppColors.primary, () { Navigator.pop(context); context.go('/profile'); }),
                _buildOption('Changer le mot de passe', 'lock.svg', AppColors.primary, () { Navigator.pop(context); _showChangePasswordSheet(); }),
                _buildOption('Verifier l\'email', 'check-circle.svg', AppColors.success, () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Email verifie'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
                TextField(controller: confirmPassController, obscureText: true, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(hintText: 'Confirmer', hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)), filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () {
                        if (newPassController.text == confirmPassController.text && newPassController.text.isNotEmpty) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Mot de passe change'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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

  void _security() {
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
                _buildSecurityOption('Authentification a deux facteurs', 'Securite renforcee', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('2FA active'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }),
                _buildSecurityOption('Historique des connexions', 'Voir les dernieres connexions', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Aucune connexion recente'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }),
                _buildSecurityOption('Sessions actives', 'Gerer les appareils connectes', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('1 session active'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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

  void _privacy() {
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
                  Text('Confidentialite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 20),
                  _buildPrivacyToggle('Profil prive', 'Masquer votre profil aux autres', _isPrivateProfile, (v) {
                    setSheetState(() => _isPrivateProfile = v);
                    setState(() => _isPrivateProfile = v);
                    _saveSetting('settings_private_profile', v);
                  }),
                  _buildPrivacyToggle('Statut en ligne', 'Afficher quand vous etes en ligne', _showOnlineStatus, (v) {
                    setSheetState(() => _showOnlineStatus = v);
                    setState(() => _showOnlineStatus = v);
                    _saveSetting('settings_online_status', v);
                  }),
                  _buildPrivacyToggle('Accusés de lecture', 'Notifier quand un message est lu', _readReceipts, (v) {
                    setSheetState(() => _readReceipts = v);
                    setState(() => _readReceipts = v);
                    _saveSetting('settings_read_receipts', v);
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
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

  void _theme() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 16),
                _buildThemeOption('Sombre', 'moon.svg'),
                _buildThemeOption('Clair', 'sun.svg'),
                _buildThemeOption('Systeme', 'settings.svg'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, String icon) {
    final isCurrent = _selectedTheme == label;
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedTheme = label);
            _saveSetting('settings_theme', label);
            if (label == 'Sombre') {
              setThemeMode(ThemeMode.dark);
            } else if (label == 'Clair') {
              setThemeMode(ThemeMode.light);
            } else {
              setThemeMode(ThemeMode.system);
            }
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCurrent ? AppColors.primary.withOpacity(0.3) : borderColor),
            ),
            child: Row(
              children: [
                SvgPicture.asset('assets/icons/$icon', width: 20, height: 20, colorFilter: ColorFilter.mode(isCurrent ? AppColors.primary : textDimColor, BlendMode.srcIn)),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 14, color: isCurrent ? AppColors.primary : textColor)),
                const Spacer(),
                if (isCurrent) SvgPicture.asset('assets/icons/check-circle.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _language() {
    final languages = ['Francais', 'English', 'Espanol', 'Deutsch'];
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Langue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 16),
                ...languages.map((lang) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedLanguage = lang);
                        _saveSetting('settings_language', lang);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedLanguage == lang ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _selectedLanguage == lang ? AppColors.primary.withOpacity(0.3) : borderColor),
                        ),
                        child: Row(
                          children: [
                            Text(lang, style: TextStyle(fontSize: 14, color: _selectedLanguage == lang ? AppColors.primary : textColor)),
                            const Spacer(),
                            if (_selectedLanguage == lang) SvgPicture.asset('assets/icons/check-circle.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dataStorage() {
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
                Text('Stockage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 20),
                _buildStorageOption('Cache', '45 MB'),
                _buildStorageOption('Donnees hors ligne', '120 MB'),
                _buildStorageOption('Medias', '230 MB'),
                _buildStorageOption('Total', '395 MB'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Cache vide'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Vider le cache', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600))),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOption(String label, String size) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: textColor)),
          const Spacer(),
          Text(size, style: TextStyle(fontSize: 14, color: textDimColor)),
        ],
      ),
    );
  }

  void _logout() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: SvgPicture.asset('assets/icons/log-out.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)))),
                const SizedBox(height: 16),
                Text('Se deconnecter ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('Vous devrez vous reconnecter.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { Navigator.pop(context); context.go('/login'); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Deconnexion', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String label, String icon, Color color, VoidCallback onTap) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: ThemeHelper.bg(context).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/$icon', width: 18, height: 18, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final surfaceColor = ThemeHelper.surface(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: textDimColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: surfaceColor.withOpacity(0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;
  const _SettingsItem({required this.icon, required this.label, this.value, this.trailing, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SvgPicture.asset(icon, width: 18, height: 18, colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: itemColor)),
              const Spacer(),
              if (trailing != null) trailing!,
              if (value != null && trailing == null) Text(value!, style: TextStyle(fontSize: 12, color: textDimColor)),
              if (trailing == null) ...[
                const SizedBox(width: 8),
                SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(itemColor.withOpacity(0.5), BlendMode.srcIn)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
