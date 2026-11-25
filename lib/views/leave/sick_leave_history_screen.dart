import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_menu_button.dart';
import 'sick_leave_form_dialog.dart';
import 'sick_leave_detail_screen.dart';

class SickLeaveHistoryScreen extends StatefulWidget {
  const SickLeaveHistoryScreen({super.key});

  @override
  State<SickLeaveHistoryScreen> createState() => _SickLeaveHistoryScreenState();
}

class _SickLeaveHistoryScreenState extends State<SickLeaveHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _leaveData = [];
  List<Map<String, dynamic>> _filteredLeaveData = [];
  bool _isFilterExpanded = false;
  String _filterType = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> _months = [
    {'label': 'Semua Bulan', 'value': 'Semua'},
    {'label': 'Januari', 'value': '01'},
    {'label': 'Februari', 'value': '02'},
    {'label': 'Maret', 'value': '03'},
    {'label': 'April', 'value': '04'},
    {'label': 'Mei', 'value': '05'},
    {'label': 'Juni', 'value': '06'},
    {'label': 'Juli', 'value': '07'},
    {'label': 'Agustus', 'value': '08'},
    {'label': 'September', 'value': '09'},
    {'label': 'Oktober', 'value': '10'},
    {'label': 'November', 'value': '11'},
    {'label': 'Desember', 'value': '12'},
  ];

  List<String> get _availableYears {
    final years = <String>{};
    for (final l in _leaveData) {
      try {
        final parts = l['start_date'].toString().split(' ')[0].split('-');
        if (parts.isNotEmpty) years.add(parts[0]);
      } catch (_) {}
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return ['Semua', ...sorted];
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _loadLeaveHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveHistory() async {
    final user = DatabaseService().getCurrentUser();
    if (user == null) return;
    final leaves = await DatabaseService().getSickLeaves(userId: user['id']);
    setState(() {
      _leaveData = leaves;
      _applyFilter();
    });
    _animController.forward(from: 0.0);
  }

  void _applyFilter() {
    var data = _leaveData;
    if (_filterType == 'Dengan Lampiran') {
      data = data.where((l) => l['has_attachment'] == true).toList();
    } else if (_filterType == 'Tanpa Lampiran') {
      data = data.where((l) => l['has_attachment'] != true).toList();
    }
    if (_filterMonth != 'Semua' || _filterYear != 'Semua') {
      data = data.where((l) {
        try {
          final parts = l['start_date'].toString().split(' ')[0].split('-');
          if (parts.length < 2) return false;
          final monthOk = _filterMonth == 'Semua' || parts[1] == _filterMonth;
          final yearOk = _filterYear == 'Semua' || parts[0] == _filterYear;
          return monthOk && yearOk;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    _filteredLeaveData = data;
    _animController.forward(from: 0.0);
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null) return '-';
    try {
      final s = DateTime.parse(start.split(' ')[0]);
      final sStr = DateFormat('dd MMM yyyy', 'id_ID').format(s);
      if (end == null || end == start) return sStr;
      final e = DateTime.parse(end.split(' ')[0]);
      final eStr = DateFormat('dd MMM yyyy', 'id_ID').format(e);
      return '$sStr - $eStr';
    } catch (_) {
      return '$start - ${end ?? ''}';
    }
  }

  Color _typeColor(String t) =>
      t.contains('Sakit') ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6);

  IconData _typeIcon(String t) => t.contains('Sakit')
      ? Icons.medical_services_rounded
      : Icons.event_busy_rounded;

  int get _countSick => _leaveData
      .where((l) => l['leave_type'].toString().contains('Sakit'))
      .length;
  int get _countPermit => _leaveData
      .where((l) => l['leave_type'].toString().contains('Izin'))
      .length;
  int get _countAttachment =>
      _leaveData.where((l) => l['has_attachment'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
        ],
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadLeaveHistory,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildStatsOverview(),
                      _buildCollapsibleFilter(),
                      _buildListHeader(),
                    ],
                  ),
                ),
              ),
              _filteredLeaveData.isEmpty
                  ? SliverFillRemaining(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildEmptyState(),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              final slideVal =
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animController,
                                      curve: Interval(
                                        (index /
                                                (_filteredLeaveData.isEmpty
                                                    ? 1
                                                    : _filteredLeaveData
                                                          .length))
                                            .clamp(0.0, 1.0),
                                        1.0,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                  );
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: slideVal,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildLeaveCard(_filteredLeaveData[index]),
                          );
                        }, childCount: _filteredLeaveData.length),
                      ),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => const SickLeaveFormDialog(),
            );
            if (result == true) _loadLeaveHistory();
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 6,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Ajukan Izin / Sakit',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: 130.0,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat Izin / Sakit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kelola rekam jejak ketidakhadiran medis',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF022C1A),
                    Color(0xFF064E3B),
                    Color(0xFF059669),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ExportMenuButton(
              onCsv: (ctx) => ExportService.exportSickCsv(
                ctx,
                _filteredLeaveData,
                DatabaseService().getCurrentUser()?['name']?.toString() ??
                    'Karyawan',
              ),
              onPdf: (ctx) => ExportService.exportSickPdf(
                ctx,
                _filteredLeaveData,
                DatabaseService().getCurrentUser()?['name']?.toString() ??
                    'Karyawan',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              title: 'Total Sakit',
              value: '$_countSick',
              subtitle: 'Pengajuan',
              icon: Icons.medical_services_rounded,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              title: 'Total Izin',
              value: '$_countPermit',
              subtitle: 'Pengajuan',
              icon: Icons.event_busy_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              title: 'Lampiran',
              value: '$_countAttachment',
              subtitle: 'Ada Berkas',
              icon: Icons.attach_file_rounded,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Row(
        children: [
          const Text(
            'Daftar Riwayat',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_filteredLeaveData.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilter() {
    final activeCount =
        (_filterType != 'Semua' ? 1 : 0) +
        (_filterMonth != 'Semua' ? 1 : 0) +
        (_filterYear != 'Semua' ? 1 : 0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: activeCount > 0
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () =>
                  setState(() => _isFilterExpanded = !_isFilterExpanded),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: activeCount > 0
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: activeCount > 0
                            ? Colors.white
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Filter & Pencarian',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$activeCount aktif',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (activeCount > 0)
                      GestureDetector(
                        onTap: () => setState(() {
                          _filterType = 'Semua';
                          _filterMonth = 'Semua';
                          _filterYear = 'Semua';
                          _applyFilter();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isFilterExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterContent(),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Bulan',
                  icon: Icons.calendar_month_rounded,
                  value: _filterMonth,
                  items: _months
                      .map((m) => (m['label']!, m['value']!))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _filterMonth = v;
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: 'Tahun',
                  icon: Icons.date_range_rounded,
                  value: _filterYear,
                  items: _availableYears
                      .map((y) => (y == 'Semua' ? 'Semua Tahun' : y, y))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _filterYear = v;
                    _applyFilter();
                  }),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LAMPIRAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildChip('Semua', _filterType, Icons.dashboard_rounded, (
                      v,
                    ) {
                      setState(() {
                        _filterType = v;
                        _applyFilter();
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Dengan Lampiran',
                      _filterType,
                      Icons.attach_file_rounded,
                      (v) {
                        setState(() {
                          _filterType = v;
                          _applyFilter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Tanpa Lampiran',
                      _filterType,
                      Icons.block_rounded,
                      (v) {
                        setState(() {
                          _filterType = v;
                          _applyFilter();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.$2,
                      child: Text(e.$1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    String label,
    String current,
    IconData icon,
    ValueChanged<String> onTap,
  ) {
    final selected = current == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                size: 52,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum Ada Riwayat Izin',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _filterType = 'Semua';
                _filterMonth = 'Semua';
                _filterYear = 'Semua';
                _applyFilter();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Reset Filter',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final hasAttachment = leave['has_attachment'] == true;
    final tc = _typeColor(leave['leave_type'].toString());
    final reason = leave['reason']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SickLeaveDetailScreen(leave: leave),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tc.withValues(alpha: 0.18),
                            tc.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tc.withValues(alpha: 0.25)),
                      ),
                      child: Icon(
                        _typeIcon(leave['leave_type'].toString()),
                        color: tc,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leave['leave_type']?.toString() ?? 'Izin',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _formatDateRange(
                                    leave['start_date']?.toString(),
                                    leave['end_date']?.toString(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasAttachment)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 12,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Lampiran',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    const Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
