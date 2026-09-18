import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';

class OrgListScreen extends StatefulWidget {
  const OrgListScreen({super.key});

  @override
  State<OrgListScreen> createState() => _OrgListScreenState();
}

class _OrgListScreenState extends State<OrgListScreen> {
  final _renameController = TextEditingController();
  final _notifService = NotificationService();

  final List<_Org> _orgs = [
    _Org(id: '1', name: 'TechCorp', initials: 'TC', color: const Color(0xFF00CEC9), lastMessage: '3 new projects created', time: '14:32', unread: 5),
    _Org(id: '2', name: 'StartupLab', initials: 'SL', color: const Color(0xFF00B894), lastMessage: 'Team member joined', time: '13:15', unread: 2),
  ];

  @override
  void initState() {
    super.initState();
    _notifService.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final surfaceColor = ThemeHelper.surface(context);
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
                child: Center(child: SvgPicture.asset('assets/icons/orgs.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
              ),
              const SizedBox(width: 12),
              Text('ORGANIZATIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
              const Spacer(),
              if (_notifService.totalUnread > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${_notifService.totalUnread} non lu${_notifService.totalUnread > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _orgs.map((org) => Column(
                children: [
                  GestureDetector(
                    onLongPress: () => _showOrgOptions(org),
                    child: _OrgCard(
                      org: org,
                      onTap: () {
                        _notifService.clearUnread(org.id);
                        setState(() => org.unread = 0);
                        context.go('/organization');
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrgOptions(_Org org) {
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
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [org.color, org.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
                      child: Center(child: Text(org.initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 12),
                    Text(org.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                  ],
                ),
                const SizedBox(height: 20),
                _buildOption('edit.svg', 'Renommer', AppColors.primary, () { Navigator.pop(context); _renameOrg(org); }),
                _buildOption('archive.svg', org.isArchived ? 'Désarchiver' : 'Archiver', AppColors.warning, () { Navigator.pop(context); setState(() => org.isArchived = !org.isArchived); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(org.isArchived ? 'Organisation archivée' : 'Organisation désarchivée'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }),
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

  void _renameOrg(_Org org) {
    _renameController.text = org.name;
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
                const Text('Renommer l\'organisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
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
                    Expanded(child: GestureDetector(onTap: () { setState(() => org.name = _renameController.text); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Organisation renommée'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteOrg(_Org org) {
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
                Text('Supprimer "${org.name}" ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Tous les projets seront supprimés.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))), child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14)))))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () { setState(() => _orgs.remove(org)); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Organisation supprimée'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))))),
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

class _Org {
  final String id;
  String name;
  final String initials;
  final Color color;
  final String lastMessage;
  final String time;
  int unread;
  bool isArchived;
  _Org({required this.id, required this.name, required this.initials, required this.color, required this.lastMessage, required this.time, this.unread = 0, this.isArchived = false});
}

class _OrgCard extends StatelessWidget {
  final _Org org;
  final VoidCallback onTap;
  const _OrgCard({required this.org, required this.onTap});

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
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [org.color, org.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(50)),
              child: Center(child: Text(org.initials, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(org.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: org.isArchived ? textDimColor : textColor))),
                      if (org.isArchived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Archivé', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(org.lastMessage, style: TextStyle(fontSize: 13, color: textDimColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(org.time, style: TextStyle(fontSize: 12, color: textDimColor)),
                if (org.unread > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$org.unread',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
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
