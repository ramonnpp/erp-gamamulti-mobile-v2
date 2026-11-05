import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_menu_button.dart';
import 'leave_form_dialog.dart';
import 'leave_detail_screen.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  List<Map<String, dynamic>> _leaveData = [];
  List<Map<String, dynamic>> _filteredLeaveData = [];
  bool _isLoading = true;
  bool _isFilterExpanded = false;
  String _filterType = 'Semua';
  String _filterStatus = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';

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
    _loadLeaveHistory();
  }

  Future<void> _loadLeaveHistory() async {
    setState(() => _isLoading = true);
    final user = DatabaseService().getCurrentUser();
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final leaves = await DatabaseService().getLeaves(userId: user['id']);
    setState(() {
      _leaveData = leaves;
      _applyFilter();
      _isLoading = false;
    });
  }

  String _statusOf(Map<String, dynamic> leave) {
    final now = DateTime.now();
    try {
      final s = DateTime.parse(leave['start_date'].toString().split(' ')[0]);
      final e = DateTime.parse(leave['end_date'].toString().split(' ')[0]);
      if (now.isBefore(s)) return 'Akan Datang';
      if (now.isAfter(e)) return 'Selesai';
      return 'Sedang Berlangsung';
    } catch (_) {
      return 'Selesai';
    }
  }

  void _applyFilter() {
    var data = _leaveData;
    if (_filterType != 'Semua') {
      data = data.where((l) => l['leave_type'] == _filterType).toList();
    }
    if (_filterStatus != 'Semua') {
      data = data.where((l) => _statusOf(l) == _filterStatus).toList();
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
  }

  Color _statusColor(String s) => s == 'Sedang Berlangsung'
      ? const Color(0xFF10B981)
      : s == 'Akan Datang'
      ? const Color(0xFF3B82F6)
      : const Color(0xFF64748B);

  IconData _typeIcon(String t) => t.contains('Bersama')
      ? Icons.groups_rounded
      : t.contains('Darurat')
      ? Icons.emergency_rounded
      : Icons.beach_access_rounded;

  Color _typeColor(String t) => t.contains('Bersama')
      ? const Color(0xFF8B5CF6)
      : t.contains('Darurat')
      ? const Color(0xFFF59E0B)
      : const Color(0xFF0EA5E9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Cuti'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          ExportMenuButton(
            onCsv: (ctx) => ExportService.exportLeaveCsv(
              ctx,
              _filteredLeaveData,
              DatabaseService().getCurrentUser()?['name']?.toString() ??
                  'Karyawan',
              _statusOf,
            ),
            onPdf: (ctx) => ExportService.exportLeavePdf(
              ctx,
              _filteredLeaveData,
              DatabaseService().getCurrentUser()?['name']?.toString() ??
                  'Karyawan',
              _statusOf,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCollapsibleFilter(),
                Expanded(
                  child: _filteredLeaveData.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadLeaveHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: _filteredLeaveData.length,
                            itemBuilder: (context, index) =>
                                _buildLeaveCard(_filteredLeaveData[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const LeaveFormDialog(),
          );
          if (result == true) _loadLeaveHistory();
        },
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Ajukan Cuti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCollapsibleFilter() {
    final activeCount =
        (_filterType != 'Semua' ? 1 : 0) +
        (_filterStatus != 'Semua' ? 1 : 0) +
        (_filterMonth != 'Semua' ? 1 : 0) +
        (_filterYear != 'Semua' ? 1 : 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header - always visible, tap to expand/collapse
          InkWell(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      size: 17,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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
                        _filterStatus = 'Semua';
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
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
          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
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
        // Bulan & Tahun side by side
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
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
        // Jenis Cuti
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JENIS CUTI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('Semua', _filterType, Icons.apps_rounded, (v) {
                      setState(() {
                        _filterType = v;
                        _applyFilter();
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Cuti Tahunan',
                      _filterType,
                      Icons.beach_access_rounded,
                      (v) {
                        setState(() {
                          _filterType = v;
                          _applyFilter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Cuti Bersama',
                      _filterType,
                      Icons.groups_rounded,
                      (v) {
                        setState(() {
                          _filterType = v;
                          _applyFilter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Cuti Darurat',
                      _filterType,
                      Icons.emergency_rounded,
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
        // Status
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('Semua', _filterStatus, Icons.apps_rounded, (v) {
                      setState(() {
                        _filterStatus = v;
                        _applyFilter();
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Akan Datang',
                      _filterStatus,
                      Icons.schedule_rounded,
                      (v) {
                        setState(() {
                          _filterStatus = v;
                          _applyFilter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Sedang Berlangsung',
                      _filterStatus,
                      Icons.play_circle_fill_rounded,
                      (v) {
                        setState(() {
                          _filterStatus = v;
                          _applyFilter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      'Selesai',
                      _filterStatus,
                      Icons.check_circle_rounded,
                      (v) {
                        setState(() {
                          _filterStatus = v;
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
            Icon(icon, size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
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
                fontSize: 12,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.beach_access_outlined,
              size: 56,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tidak ada riwayat cuti',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba ubah filter atau reset filter',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final status = _statusOf(leave);
    final sc = _statusColor(status);
    final tc = _typeColor(leave['leave_type'].toString());
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LeaveDetailScreen(leave: leave)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: tc,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: tc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _typeIcon(leave['leave_type'].toString()),
                              color: tc,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leave['leave_type'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${leave['start_date']} → ${leave['end_date']}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: sc,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: sc,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (leave['reason'] != null &&
                          leave['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  leave['reason'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
