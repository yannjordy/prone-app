import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/utils/photo_picker_helper.dart';

class OrgListScreen extends StatefulWidget {
  const OrgListScreen({super.key});

  @override
  State<OrgListScreen> createState() => _OrgListScreenState();
}

class _OrgListScreenState extends State<OrgListScreen> {
  final _backend = LocalBackend();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  List<Map<String, dynamic>> _orgs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    setState(() => _isLoading = true);
    final orgs = await _backend.getOrganizations();
    setState(() {
      _orgs = orgs;
      _isLoading = false;
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

  String _getInitials(String name) {
    return name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join().substring(0, name.split(' ').length.clamp(0, 2).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

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
                child: Center(child: SvgPicture.asset('assets/icons/orgs.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
              ),
              const SizedBox(width: 12),
              Text('ORGANIZATIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
              const Spacer(),
              GestureDetector(
                onTap: _showCreateOrgSheet,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: SvgPicture.asset('assets/icons/plus.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : _orgs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                              child: Center(child: SvgPicture.asset('assets/icons/orgs.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                            ),
                            const SizedBox(height: 16),
                            Text('Aucune organisation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
                            const SizedBox(height: 6),
                            Text('Creez votre premiere organisation', style: TextStyle(fontSize: 13, color: textDimColor)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrgs,
                        color: AppColors.primary,
                        child: ListView.builder(
                          itemCount: _orgs.length,
                          itemBuilder: (context, index) => _OrgCardAnimated(
                            org: _orgs[index],
                            index: index,
                            onTap: () => context.go('/organization/${_orgs[index]['id']}'),
                            onLongPress: () => _showOrgOptions(_orgs[index]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateOrgSheet() {
    _nameController.clear();
    _descController.clear();
    Uint8List? selectedPhoto;
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
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Creer une organisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = PhotoPickerHelper();
                        final bytes = await picker.pickImage();
                        if (bytes != null) setSheetState(() => selectedPhoto = Uint8List.fromList(bytes));
                      },
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2)),
                        child: ClipOval(child: selectedPhoto != null
                            ? Image.memory(selectedPhoto!, width: 80, height: 80, fit: BoxFit.cover)
                            : Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                                child: Center(child: SvgPicture.asset('assets/icons/plus.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(child: Text('Photo optionnelle', style: TextStyle(fontSize: 11, color: textDimColor))),
                  const SizedBox(height: 20),
                  Text('Nom', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Mon Organisation',
                      hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
                      filled: true, fillColor: ThemeHelper.bg(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Description', style: TextStyle(fontSize: 12, color: textDimColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Description optionnelle',
                      hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
                      filled: true, fillColor: ThemeHelper.bg(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: GestureDetector(
                        onTap: () async {
                          if (_nameController.text.isNotEmpty) {
                            final photo = selectedPhoto != null ? base64Encode(selectedPhoto!) : null;
                            await _backend.createOrganization(_nameController.text, _descController.text, photo: photo);
                            Navigator.pop(context);
                            _loadOrgs();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Organisation creee'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                          }
                        },
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Creer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
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

  void _showOrgOptions(Map<String, dynamic> org) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final color = _parseColor(org['color']);

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
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                      child: Center(child: Text(org['initials'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 12),
                    Text(org['name'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                  ],
                ),
                const SizedBox(height: 20),
                _buildOption('edit.svg', 'Renommer', AppColors.primary, () { Navigator.pop(context); _renameOrg(org); }),
                _buildOption('archive.svg', org['is_archived'] == 1 ? 'Desarchiver' : 'Archiver', AppColors.warning, () async {
                  Navigator.pop(context);
                  await _backend.updateOrganization(org['id'], {'is_archived': org['is_archived'] == 1 ? 0 : 1});
                  _loadOrgs();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(org['is_archived'] == 1 ? 'Organisation desarchivee' : 'Organisation archivee'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }),
                _buildOption('trash.svg', 'Supprimer', AppColors.error, () { Navigator.pop(context); _deleteOrg(org); }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String icon, String label, Color color, VoidCallback onTap) {
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
              Text(label, style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _renameOrg(Map<String, dynamic> org) {
    _nameController.text = org['name'] ?? '';
    _descController.text = org['description'] ?? '';
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
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Renommer l\'organisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(filled: true, fillColor: ThemeHelper.bg(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () async {
                      if (_nameController.text.isNotEmpty) {
                        await _backend.updateOrganization(org['id'], {
                          'name': _nameController.text,
                          'description': _descController.text,
                          'initials': _getInitials(_nameController.text),
                        });
                        Navigator.pop(context);
                        _loadOrgs();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Organisation renommee'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      }
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

  void _deleteOrg(Map<String, dynamic> org) {
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
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: SvgPicture.asset('assets/icons/warning.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(AppColors.error, BlendMode.srcIn)))),
                const SizedBox(height: 16),
                Text('Supprimer "${org['name']}" ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Tous les projets seront supprimes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () async {
                      await _backend.deleteOrganization(org['id']);
                      Navigator.pop(context);
                      _loadOrgs();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Organisation supprimee'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
}

class _OrgCardAnimated extends StatefulWidget {
  final Map<String, dynamic> org;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _OrgCardAnimated({required this.org, required this.index, required this.onTap, required this.onLongPress});

  @override
  State<_OrgCardAnimated> createState() => _OrgCardAnimatedState();
}

class _OrgCardAnimatedState extends State<_OrgCardAnimated> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String _getInitials(String name) {
    return name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join().substring(0, name.split(' ').length.clamp(0, 2).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final color = _parseColor(widget.org['color']);
    final photo = widget.org['photo'] ?? '';
    final name = widget.org['name'] ?? '';
    final initials = widget.org['initials'] ?? _getInitials(name);
    final isArchived = widget.org['is_archived'] == 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 4),
              transform: _isHovered ? (Matrix4.identity()..scale(1.01)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: _isHovered ? ThemeHelper.surface(context).withOpacity(0.9) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        photo.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.memory(base64Decode(photo), width: 52, height: 52, fit: BoxFit.cover),
                              )
                            : Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                                child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
                              ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isArchived ? textDimColor : textColor))),
                                  if (isArchived)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('Archivee', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<List<int>>(
                                future: Future.wait([
                                  LocalBackend().getOrganizationProjectCount(widget.org['id']),
                                  LocalBackend().getOrganizationMemberCount(widget.org['id']),
                                ]),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox();
                                  final projCount = snapshot.data![0];
                                  final memberCount = snapshot.data![1];
                                  return Text(
                                    '$projCount projet${projCount > 1 ? 's' : ''} · $memberCount membre${memberCount > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 13, color: textDimColor),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
