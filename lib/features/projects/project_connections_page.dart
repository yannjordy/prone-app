import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../app/app.dart';

class ProjectConnectionsPage extends StatefulWidget {
  final String projectId;
  const ProjectConnectionsPage({super.key, required this.projectId});

  @override
  State<ProjectConnectionsPage> createState() => _ProjectConnectionsPageState();
}

class _ProjectConnectionsPageState extends State<ProjectConnectionsPage> {
  bool _showAddForm = false;
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();

  final List<_Connection> _connections = [
    _Connection(name: 'Production API', url: 'https://api.example.com', status: 'online', type: 'REST'),
    _Connection(name: 'Staging API', url: 'https://staging.example.com', status: 'degraded', type: 'REST'),
    _Connection(name: 'Auth Service', url: 'https://auth.example.com', status: 'online', type: 'REST'),
    _Connection(name: 'Payment Gateway', url: 'https://payments.example.com', status: 'offline', type: 'REST'),
  ];

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeHelper.bg(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildConnectionsList()),
            ],
          ),

          if (_showAddForm)
            GestureDetector(
              onTap: () => setState(() => _showAddForm = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),

          if (_showAddForm) _buildAddForm(),

          Positioned(
            bottom: 24,
            right: 24,
            child: GestureDetector(
              onTap: () => setState(() => _showAddForm = true),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16)],
                ),
                child: Center(
                  child: SvgPicture.asset('assets/icons/plus.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/connections.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('CONNECTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: textDimColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_connections.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsList() {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);

    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/connections.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(textDimColor, BlendMode.srcIn)),
            const SizedBox(height: 16),
            Text('Aucune connexion', style: TextStyle(fontSize: 16, color: textDimColor)),
            const SizedBox(height: 8),
            Text('Connectez votre backend pour commencer', style: TextStyle(fontSize: 13, color: textDimColor.withOpacity(0.6))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final conn = _connections[index];
        final statusColor = conn.status == 'online' ? AppColors.success : (conn.status == 'degraded' ? AppColors.warning : AppColors.error);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: SvgPicture.asset('assets/icons/connections.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(statusColor, BlendMode.srcIn))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conn.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          Text(conn.url, style: TextStyle(fontSize: 12, color: textDimColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddForm() {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Connecter un Backend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                Text('URL de votre API + clé d\'accès', style: TextStyle(fontSize: 13, color: textDimColor)),
                const SizedBox(height: 24),
                _buildInput('Nom', _nameController, 'Mon Backend'),
                const SizedBox(height: 12),
                _buildInput('URL', _urlController, 'https://api.example.com'),
                const SizedBox(height: 12),
                _buildInput('Clé API', _keyController, 'Bearer token...'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showAddForm = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(child: Text('Annuler', style: TextStyle(color: textDimColor, fontSize: 14))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _addConnection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('Connecter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint) {
    final textColor = ThemeHelper.text(context);
    final textDimColor = ThemeHelper.textDim(context);
    final borderColor = ThemeHelper.borderLight(context);
    final bgColor = ThemeHelper.bg(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textDimColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textDimColor.withOpacity(0.5)),
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _addConnection() {
    if (_nameController.text.isEmpty || _urlController.text.isEmpty) return;
    setState(() {
      _connections.add(_Connection(name: _nameController.text, url: _urlController.text, status: 'online', type: 'REST'));
      _showAddForm = false;
      _nameController.clear();
      _urlController.clear();
      _keyController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Backend connecté'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}

class _Connection {
  final String name;
  final String url;
  final String status;
  final String type;
  _Connection({required this.name, required this.url, required this.status, required this.type});
}
