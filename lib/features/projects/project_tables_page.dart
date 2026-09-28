import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';
import '../../core/local/local_backend.dart';
import '../../core/backend/backend_adapter.dart';
import '../../core/notifications/error_store.dart';

class ProjectTablesPage extends StatefulWidget {
  final String projectId;
  const ProjectTablesPage({super.key, required this.projectId});
  @override
  State<ProjectTablesPage> createState() => _ProjectTablesPageState();
}

class _ProjectTablesPageState extends State<ProjectTablesPage> {
  final _backend = LocalBackend();
  final _tableSearchController = TextEditingController();
  final _valueSearchController = TextEditingController();

  String _backendUrl = '';
  String _apiKey = '';
  String _backendType = 'generic';

  bool _loading = true;
  bool _loadingRows = false;
  String? _pageError;
  bool _offline = false;

  List<String> _tables = [];
  String? _selectedTable;
  TableResult? _result;
  SchemaResult? _schema;
  int _page = 0;
  int _pageSize = 25;
  String _filterField = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _tableSearchController.dispose();
    _valueSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() { _loading = true; _pageError = null; });
    final projects = await _backend.getProjects();
    final project = projects.where((p) => p['id'] == widget.projectId).toList();
    if (project.isEmpty) {
      setState(() { _loading = false; _pageError = 'Projet introuvable'; });
      return;
    }
    final p = project.first;
    _backendUrl = (p['backend_url'] as String?) ?? '';
    _apiKey = (p['api_key'] as String?) ?? '';
    _backendType = BackendAdapter.detect(_backendUrl, null).name;

    if (_backendUrl.isEmpty) {
      setState(() { _loading = false; _pageError = 'Aucun backend configure pour ce projet.'; });
      return;
    }

    try {
      final tables = await BackendAdapter.listTables(_backendUrl, _apiKey, type: _backendType);
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _loading = false;
        _offline = false;
      });
      if (tables.isEmpty) {
        setState(() => _pageError = 'Aucune table detectee sur ce backend.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _pageError = e.toString(); });
      await BackendErrorStore.instance.record(widget.projectId, 'Lecture des tables impossible: $e', level: ErrorLevel.error);
    }
  }

  Future<void> _openTable(String table) async {
    setState(() {
      _selectedTable = table;
      _page = 0;
      _tab = 0;
      _result = null;
      _schema = null;
      _filterField = '';
      _valueSearchController.clear();
    });
    await _loadSchema();
    await _loadRows();
  }

  Future<void> _loadSchema() async {
    final table = _selectedTable;
    if (table == null) return;
    try {
      final schema = await BackendAdapter.fetchSchema(_backendUrl, _apiKey, table, type: _backendType);
      if (mounted) setState(() => _schema = schema);
      if (!schema.ok && schema.error != null) {
        await BackendErrorStore.instance.record(
          widget.projectId,
          'Schema $table: ${schema.error}',
          command: '/schema $table',
          level: schema.offline ? ErrorLevel.offline : ErrorLevel.warning,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadRows({int? page}) async {
    final table = _selectedTable;
    if (table == null) return;
    final targetPage = page ?? _page;
    setState(() { _loadingRows = true; _pageError = null; });
    try {
      final value = _valueSearchController.text.trim();
      final res = await BackendAdapter.fetchRows(
        _backendUrl,
        _apiKey,
        table,
        limit: _pageSize,
        offset: targetPage * _pageSize,
        type: _backendType,
        searchField: value.isNotEmpty ? _filterField : null,
        searchValue: value.isNotEmpty ? value : null,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _page = targetPage;
        _loadingRows = false;
        _offline = res.offline;
        if (res.error != null) _pageError = res.error;
      });
      if (!res.ok) {
        await BackendErrorStore.instance.record(
          widget.projectId,
          'Lecture de $table: ${res.error}',
          command: '/table $table',
          level: res.offline ? ErrorLevel.offline : ErrorLevel.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingRows = false; _pageError = e.toString(); });
      await BackendErrorStore.instance.record(widget.projectId, 'Lecture de $table: $e', level: ErrorLevel.error);
    }
  }

  Future<void> _runFilter() async {
    if (_filterField.isEmpty || _valueSearchController.text.trim().isEmpty) return;
    await _loadRows(page: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 14),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : (_selectedTable == null ? _buildTableList() : _buildTableDetail())),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => _selectedTable == null
                ? context.go('/projects/${widget.projectId}')
                : setState(() { _selectedTable = null; _result = null; _schema = null; _pageError = null; }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: SvgPicture.asset('assets/icons/chevron-left.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            ),
          ),
          const SizedBox(width: 10),
          SvgPicture.asset('assets/icons/database.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedTable ?? 'INSPECTEUR DE TABLES',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: _selectedTable == null ? 1 : 0, color: ThemeHelper.textDim(context))),
              if (_selectedTable != null)
                Text(_offline ? 'Hors ligne' : '${_tables.length} tables',
                  style: TextStyle(fontSize: 11, color: _offline ? AppColors.error : ThemeHelper.textDim(context))),
            ]),
          ),
          GestureDetector(
            onTap: _selectedTable == null ? _loadTables : () => _loadRows(),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: ThemeHelper.borderLight(context))),
              child: SvgPicture.asset('assets/icons/refresh.svg', width: 15, height: 15, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTableList() {
    if (_pageError != null && _tables.isEmpty) return _buildErrorState(_pageError!);
    final query = _tableSearchController.text.trim().toLowerCase();
    final filtered = query.isEmpty ? _tables : _tables.where((t) => t.toLowerCase().contains(query)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildSearchField(_tableSearchController, 'Rechercher une table...', () => setState(() {})),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: filtered.isEmpty
            ? _buildErrorState('Aucune table ne correspond a "$query"')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = filtered[i];
                  return _GlassCard(
                    onTap: () => _openTable(t),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: SvgPicture.asset('assets/icons/database.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThemeHelper.text(context)))),
                      SvgPicture.asset('assets/icons/chevron-right.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
                    ]),
                  );
                },
              ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildTableDetail() {
    final cols = _result?.columns ?? const <String>[];
    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: ThemeHelper.borderLight(context))),
        child: Row(children: [
          _buildTab('Donnees', 0),
          _buildTab('Colonnes', 1),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: _tab == 0 ? _buildDataTab(cols) : _buildColumnsTab()),
    ]);
  }

  Widget _buildTab(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? AppColors.primary : ThemeHelper.textDim(context)))),
        ),
      ),
    );
  }

  Widget _buildDataTab(List<String> cols) {
    if (_loadingRows && _result == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_pageError != null && (_result == null || !_result!.ok)) {
      return _buildErrorState(_offline ? 'Backend hors ligne.\nLa reconnexion reprendra les requetes en file d\'attente.' : _pageError!, onRetry: () => _loadRows());
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 42,
              decoration: BoxDecoration(
                color: ThemeHelper.surface(context).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeHelper.borderLight(context)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterField.isEmpty ? null : _filterField,
                  hint: Text('Colonne', style: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                  isExpanded: true,
                  items: cols.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 13, color: ThemeHelper.text(context))))).toList(),
                  onChanged: (v) => setState(() => _filterField = v ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 42,
              decoration: BoxDecoration(
                color: ThemeHelper.surface(context).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeHelper.borderLight(context)),
              ),
              child: TextField(
                controller: _valueSearchController,
                style: TextStyle(fontSize: 13, color: ThemeHelper.text(context)),
                decoration: InputDecoration(hintText: 'Valeur', border: InputBorder.none, hintStyle: TextStyle(fontSize: 13, color: ThemeHelper.textDim(context))),
                onSubmitted: (_) => _runFilter(),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _runFilter,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
              child: Center(child: SvgPicture.asset('assets/icons/search.svg', width: 17, height: 17, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (_loadingRows) const LinearProgressIndicator(color: AppColors.primary, backgroundColor: Colors.transparent),
      Expanded(child: _buildDataGrid(cols)),
      const SizedBox(height: 8),
      _buildPagination(),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildDataGrid(List<String> cols) {
    final rows = _result?.rows ?? const <Map<String, dynamic>>[];
    if (rows.isEmpty) {
      return _buildErrorState(_result?.ok == true ? 'Aucune ligne' : 'Aucune donnee');
    }
    final widths = List<double>.filled(cols.length, 140);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppColors.primary.withOpacity(0.12)),
          headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemeHelper.text(context)),
          dataTextStyle: TextStyle(fontSize: 12, color: ThemeHelper.text(context), fontFamily: 'monospace'),
          columnSpacing: 18,
          horizontalMargin: 16,
          showCheckboxColumn: false,
          columns: [
            for (var i = 0; i < cols.length; i++)
              DataColumn(label: SizedBox(width: widths[i], child: Text(cols[i], maxLines: 1, overflow: TextOverflow.ellipsis))),
          ],
          rows: [
            for (var r = 0; r < rows.length; r++)
              DataRow(
                onSelectChanged: (_) => _showRowDetail(rows[r]),
                cells: [
                  for (var c = 0; c < cols.length; c++)
                    DataCell(SizedBox(
                      width: widths[c],
                      child: Text(_cellText(rows[r][cols[c]]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _cellText(dynamic value) {
    if (value == null) return 'null';
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{...}';
    final s = value.toString();
    return s.length > 40 ? '${s.substring(0, 40)}…' : s;
  }

  void _showRowDetail(Map<String, dynamic> row) {
    final surfaceColor = ThemeHelper.surface(context);
    final borderColor = ThemeHelper.borderLight(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor.withOpacity(0.97), border: Border(top: BorderSide(color: borderColor))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text('Ligne', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ThemeHelper.text(context))),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final e in row.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(
                            width: 120,
                            child: Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemeHelper.textDim(context), fontFamily: 'monospace')),
                          ),
                          Expanded(child: Text(_displayValue(e.value), style: TextStyle(fontSize: 13, color: ThemeHelper.text(context), fontFamily: 'monospace'))),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _displayValue(dynamic value) {
    if (value == null) return 'null';
    if (value is List || value is Map) return value.toString();
    final s = value.toString();
    return s;
  }

  Widget _buildPagination() {
    final res = _result;
    if (res == null) return const SizedBox.shrink();
    final total = res.total;
    final hasPrev = _page > 0;
    final hasNext = res.hasMore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ThemeHelper.surface(context).withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ThemeHelper.borderLight(context)),
        ),
        child: Row(children: [
          _PageBtn(enabled: hasPrev, onTap: hasPrev && !_loadingRows ? () => _loadRows(page: _page - 1) : null, icon: 'chevron-left.svg'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              Text('${total ?? res.rows.length} lignes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemeHelper.text(context))),
              Text('page ${_page + 1}${res.pageCount != null ? ' / ${res.pageCount}' : ''}', style: TextStyle(fontSize: 11, color: ThemeHelper.textDim(context))),
            ]),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            padding: EdgeInsets.zero,
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: ThemeHelper.bg(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: ThemeHelper.borderLight(context))),
              child: Text('$_pageSize', style: TextStyle(fontSize: 12, color: ThemeHelper.textDim(context))),
            ),
            color: ThemeHelper.surface(context),
            onSelected: (v) { setState(() => _pageSize = v); _loadRows(page: 0); },
            itemBuilder: (_) => [10, 25, 50, 100].map((n) => PopupMenuItem(value: n, child: Text('$n lignes', style: TextStyle(fontSize: 13, color: ThemeHelper.text(context))))).toList(),
          ),
          const SizedBox(width: 4),
          _PageBtn(enabled: hasNext, onTap: hasNext && !_loadingRows ? () => _loadRows(page: _page + 1) : null, icon: 'chevron-right.svg'),
        ]),
      ),
    );
  }

  Widget _buildColumnsTab() {
    final schema = _schema;
    if (schema == null) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (!schema.ok) {
      return _buildErrorState(schema.error ?? 'Schema indisponible', onRetry: _loadSchema);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: schema.columns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final col = schema.columns[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: ThemeHelper.surface(context).withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ThemeHelper.borderLight(context)),
          ),
          child: Row(children: [
            SvgPicture.asset('assets/icons/info.svg', width: 15, height: 15, colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
            const SizedBox(width: 12),
            Expanded(child: Text(col.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeHelper.text(context), fontFamily: 'monospace'))),            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(col.type, style: TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'monospace')),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildSearchField(TextEditingController ctrl, String hint, [VoidCallback? onChanged]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 46,
      decoration: BoxDecoration(
        color: ThemeHelper.surface(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeHelper.borderLight(context)),
      ),
      child: Row(children: [
        SvgPicture.asset('assets/icons/search.svg', width: 17, height: 17, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: TextStyle(fontSize: 14, color: ThemeHelper.text(context)),
            decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: TextStyle(fontSize: 14, color: ThemeHelper.textDim(context))),
            onChanged: (_) => onChanged?.call(),
          ),
        ),
        if (ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () { ctrl.clear(); onChanged?.call(); },
            child: SvgPicture.asset('assets/icons/x.svg', width: 15, height: 15, colorFilter: ColorFilter.mode(ThemeHelper.textDim(context), BlendMode.srcIn)),
          ),
      ]),
    );
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    final offline = message.toLowerCase().contains('hors ligne') || message.toLowerCase().contains('connexion');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SvgPicture.asset(offline ? 'assets/icons/warning.svg' : 'assets/icons/alert-circle.svg', width: 44, height: 44,
            colorFilter: ColorFilter.mode(offline ? AppColors.warning : AppColors.error, BlendMode.srcIn)),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: ThemeHelper.textDim(context))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry ?? _loadTables,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
              child: const Text('Reessayer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeHelper.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeHelper.borderLight(context)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;
  final String icon;
  const _PageBtn({required this.enabled, this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: enabled ? ThemeHelper.bg(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ThemeHelper.borderLight(context)),
          ),
          child: Center(child: SvgPicture.asset('assets/icons/$icon', width: 16, height: 16,
            colorFilter: ColorFilter.mode(enabled ? AppColors.primary : ThemeHelper.textDim(context), BlendMode.srcIn))),
        ),
      ),
    );
  }
}
