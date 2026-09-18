import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifEnabled = true;
  String _selectedLanguage = 'Français';
  String _selectedTheme = 'Sombre';

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
          _SettingsSection(title: 'General', children: [
            _SettingsItem(icon: 'assets/icons/profile.svg', label: 'Account', onTap: _account),
            _SettingsItem(icon: 'assets/icons/bell.svg', label: 'Notifications', value: _notifEnabled ? 'ON' : 'OFF', onTap: _notifications),
            _SettingsItem(icon: 'assets/icons/globe.svg', label: 'Language', value: _selectedLanguage, onTap: _language),
          ]),
          const SizedBox(height: 16),
          _SettingsSection(title: 'Appearance', children: [
            _SettingsItem(icon: 'assets/icons/moon.svg', label: 'Theme', value: _selectedTheme, onTap: _theme),
            _SettingsItem(icon: 'assets/icons/grid.svg', label: 'Layout', value: 'Grid', onTap: _layout),
          ]),
          const SizedBox(height: 16),
          _SettingsSection(title: 'Advanced', children: [
            _SettingsItem(icon: 'assets/icons/shield.svg', label: 'Privacy', onTap: _privacy),
            _SettingsItem(icon: 'assets/icons/database.svg', label: 'Data & Storage', onTap: _dataStorage),
            _SettingsItem(icon: 'assets/icons/log-out.svg', label: 'Logout', color: AppColors.error, onTap: _logout),
          ]),
        ],
      ),
    );
  }

  void _account() {
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
                Text('Compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildAccountOption('Modifier le profil', Icons.person_outline, () { Navigator.pop(context); }),
                _buildAccountOption('Changer le mot de passe', Icons.lock_outline, () { Navigator.pop(context); }),
                _buildAccountOption('Vérifier l\'email', Icons.email_outlined, () { Navigator.pop(context); }),
                const SizedBox(height: 16),
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

  Widget _buildAccountOption(String label, IconData icon, VoidCallback onTap) {
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

  void _notifications() {
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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Activer les notifications', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))), Switch(value: _notifEnabled, onChanged: (v) => setSheetState(() => _notifEnabled = v), activeColor: AppColors.primary)]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Notifications push', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))), Switch(value: true, onChanged: (v) {}, activeColor: AppColors.primary)]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Notifications email', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))), Switch(value: false, onChanged: (v) {}, activeColor: AppColors.primary)]),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () { Navigator.pop(context); setState(() {}); },
                    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                  ),
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
                ...languages.map((lang) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () { setState(() => _selectedLanguage = lang); Navigator.pop(context); },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedLanguage == lang ? AppColors.primary.withOpacity(0.15) : ThemeHelper.bg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _selectedLanguage == lang ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context)),
                        ),
                        child: Row(
                          children: [
                            Text(lang, style: TextStyle(fontSize: 14, color: _selectedLanguage == lang ? AppColors.primary : ThemeHelper.text(context))),
                            const Spacer(),
                            if (_selectedLanguage == lang) Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
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
                _buildThemeOption('Sombre', Icons.dark_mode, 'Sombre'),
                _buildThemeOption('Clair', Icons.light_mode, 'Clair'),
                _buildThemeOption('Système', Icons.brightness_auto, 'Système'),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, String value) {
    final isCurrent = _selectedTheme == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedTheme = value);
            if (value == 'Sombre') {
              setThemeMode(ThemeMode.dark);
            } else if (value == 'Clair') {
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

  void _layout() {
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
                Text('Disposition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildLayoutOption('Grille', Icons.grid_view)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildLayoutOption('Liste', Icons.view_list)),
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

  Widget _buildLayoutOption(String label, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disposition: $label'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
          child: Column(children: [Icon(icon, color: ThemeHelper.textDim(context), size: 32), const SizedBox(height: 8), Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)))]),
        ),
      ),
    );
  }

  void _privacy() {
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
                Text('Confidentialité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildPrivacyOption('Profil privé', true),
                _buildPrivacyOption('Statut en ligne', true),
                _buildPrivacyOption('Lecteur de réponse', false),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))),
          Switch(value: value, onChanged: (v) {}, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  void _dataStorage() {
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
                Text('Données & Stockage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildStorageOption('Cache', '45 MB'),
                _buildStorageOption('Données hors ligne', '120 MB'),
                _buildStorageOption('Médias', '230 MB'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Cache vidé'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); },
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Vider le cache', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600)))),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOption(String label, String size) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))),
          const Spacer(),
          Text(size, style: TextStyle(fontSize: 14, color: ThemeHelper.textDim(context))),
        ],
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
                    Expanded(child: GestureDetector(onTap: () { Navigator.pop(context); Navigator.of(context).pushReplacementNamed('/login'); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Déconnexion', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
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
  final Color? color;
  final VoidCallback onTap;
  const _SettingsItem({required this.icon, required this.label, this.value, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Material(
      color: Colors.transparent,
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
              if (value != null) Text(value!, style: TextStyle(fontSize: 12, color: textDimColor)),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(itemColor.withOpacity(0.5), BlendMode.srcIn)),
            ],
          ),
        ),
      ),
    );
  }
}
