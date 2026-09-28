import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';

class ProjectActionsPage extends StatefulWidget {
  final String projectId;
  const ProjectActionsPage({super.key, required this.projectId});

  @override
  State<ProjectActionsPage> createState() => _ProjectActionsPageState();
}

class _ProjectActionsPageState extends State<ProjectActionsPage> {
  final _backend = LocalBackend();
  bool _showAddForm = false;
  final _nameController = TextEditingController();
  final _endpointController = TextEditingController();
  String _selectedMethod = 'GET';

  List<Map<String, dynamic>> _actions = [];

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    final actions = await _backend.getActions(widget.projectId);
    if (mounted) setState(() => _actions = actions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildActionsList()),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeHelper.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeHelper.borderLight(context)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/projects/${widget.projectId}'),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
              ),
            ),
            const SizedBox(width: 10),
            SvgPicture.asset('assets/icons/actions.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Text('ACTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: ThemeHelper.textDim(context))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_actions.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsList() {
    if (_actions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/actions.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            const SizedBox(height: 16),
            Text('Aucune action', style: TextStyle(fontSize: 16, color: ThemeHelper.textDim(context))),
            const SizedBox(height: 8),
            Text('Ajoutez un endpoint autorisé', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context).withOpacity(0.6))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        final action = _actions[index];
        return _ActionCard(
          name: (action['name'] as String?) ?? 'Action',
          endpoint: (action['endpoint'] as String?) ?? '',
          method: (action['method'] as String?) ?? 'GET',
          onDelete: () async {
            await _backend.deleteAction(widget.projectId, action['id'] as String);
            _loadActions();
          },
        );
      },
    );
  }

  Widget _buildAddForm() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nouvelle Action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                const SizedBox(height: 8),
                Text('Définir un endpoint autorisé', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                const SizedBox(height: 24),
                _buildInput('Nom', _nameController, 'Get Users'),
                const SizedBox(height: 12),
                _buildInput('Endpoint', _endpointController, '/api/users'),
                const SizedBox(height: 12),
                _buildMethodSelector(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showAddForm = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: ThemeHelper.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeHelper.borderLight(context))),
                          child: Center(child: Text('Annuler', style: TextStyle(color: ThemeHelper.textDim(context), fontSize: 14))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _addAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: ThemeHelper.textDim(context).withOpacity(0.5)),
            filled: true,
            fillColor: ThemeHelper.bg(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeHelper.borderLight(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    final methods = ['GET', 'POST', 'PUT', 'DELETE'];
    final colors = {
      'GET': AppColors.success,
      'POST': AppColors.primary,
      'PUT': AppColors.warning,
      'DELETE': AppColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Méthode', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
        const SizedBox(height: 6),
        Row(
          children: methods.map((m) {
            final isSelected = _selectedMethod == m;
            final color = colors[m]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMethod = m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.2) : ThemeHelper.bg(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? color : ThemeHelper.borderLight(context)),
                  ),
                  child: Center(
                    child: Text(m, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : ThemeHelper.textDim(context))),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _addAction() async {
    if (_nameController.text.isEmpty || _endpointController.text.isEmpty) return;
    await _backend.createAction(widget.projectId, _nameController.text.trim(), _selectedMethod, _endpointController.text.trim());
    if (!mounted) return;
    setState(() {
      _showAddForm = false;
      _nameController.clear();
      _endpointController.clear();
      _selectedMethod = 'GET';
    });
    _loadActions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Action ajoutée'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }
}

class _ActionCard extends StatelessWidget {
  final String name;
  final String endpoint;
  final String method;
  final VoidCallback onDelete;

  const _ActionCard({required this.name, required this.endpoint, required this.method, required this.onDelete});

  Color _methodColor(BuildContext context) {
    switch (method) {
      case 'GET': return AppColors.success;
      case 'POST': return AppColors.primary;
      case 'PUT': return AppColors.warning;
      case 'DELETE': return AppColors.error;
      default: return ThemeHelper.textDim(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _methodColor(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(method, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _methodColor(context), fontFamily: 'monospace')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
                      const SizedBox(height: 4),
                      Text(endpoint, style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: SvgPicture.asset('assets/icons/trash.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(AppColors.error, BlendMode.srcIn)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
