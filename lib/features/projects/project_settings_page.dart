import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectSettingsPage extends StatefulWidget {
  final String projectId;
  const ProjectSettingsPage({super.key, required this.projectId});

  @override
  State<ProjectSettingsPage> createState() => _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends State<ProjectSettingsPage> {
  final _nameController = TextEditingController(text: 'ODA Market');
  final _descController = TextEditingController(text: 'E-commerce backend API');
  bool _isEditing = false;
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);
    final surfaceColor = ThemeHelper.surface(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSection('Informations', [
                  _buildPhotoSection(),
                  const SizedBox(height: 12),
                  _buildField('Nom du projet', _nameController, _isEditing),
                  const SizedBox(height: 12),
                  _buildField('Description', _descController, _isEditing),
                ]),
                const SizedBox(height: 12),
                _buildSection('Sécurité', [
                  _buildSetting('API Key', 'cf_abc123...', 'terminal.svg', () => _copyApiKey()),
                  _buildSetting('Webhook Secret', 'whsec_xxx...', 'lock.svg', () {}),
                  _buildSetting('Rate Limiting', '1000 req/min', 'zap.svg', () {}),
                ]),
                const SizedBox(height: 12),
                _buildSection('Danger Zone', [
                  _buildDangerButton('Supprimer le projet', 'Supprimer', AppColors.error, () => _confirmDelete()),
                ]),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(ThemeHelper.text(context), BlendMode.srcIn))),
          const SizedBox(width: 12),
          Expanded(child: Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context)))),
          GestureDetector(
            onTap: () => setState(() => _isEditing = !_isEditing),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _isEditing ? AppColors.primary.withOpacity(0.2) : ThemeHelper.bg(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: _isEditing ? AppColors.primary.withOpacity(0.3) : ThemeHelper.borderLight(context))),
              child: Text(_isEditing ? 'Sauvegarder' : 'Modifier', style: TextStyle(fontSize: 13, color: _isEditing ? AppColors.primary : ThemeHelper.textDim(context), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ThemeHelper.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: ThemeHelper.borderLight(context))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))), const SizedBox(height: 12), ...children],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
        const SizedBox(height: 6),
        TextField(controller: controller, enabled: enabled, style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)), decoration: InputDecoration(filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeHelper.borderLight(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(50)),
            child: const Center(child: Text('OM', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Photo du projet', style: TextStyle(fontSize: 14, color: ThemeHelper.text(context))), Text('JPG, PNG ou GIF', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context)))])),
          GestureDetector(
            onTap: _changePhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: const Text('Changer', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _changePhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Changer la photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 16),
                _buildPhotoOption('Prendre une photo', Icons.camera_alt, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo prise : ${image.name}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                _buildPhotoOption('Choisir depuis la galerie', Icons.photo_library, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image sélectionnée : ${image.name}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                _buildPhotoOption('Choisir un fichier', Icons.attach_file, () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier sélectionné : ${image.name}'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }),
                const SizedBox(height: 16),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))))),
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

  Widget _buildSetting(String title, String value, String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/$icon', width: 18, height: 18, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, color: ThemeHelper.text(context))), Text(value, style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context), fontFamily: 'monospace'))])),
            SvgPicture.asset('assets/icons/send.svg', width: 14, height: 14, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerButton(String title, String button, Color color, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: color))),
        GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(button, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)))),
      ],
    );
  }

  void _copyApiKey() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('API Key copiée !'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _confirmDelete() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: ThemeHelper.surface(context).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThemeHelper.borderLight(context), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28)),
                const SizedBox(height: 16),
                Text('Supprimer le projet ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Cette action est irréversible.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { Navigator.pop(context); _deleteProject(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
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

  void _deleteProject() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Projet supprimé'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    Navigator.pop(context);
  }
}
