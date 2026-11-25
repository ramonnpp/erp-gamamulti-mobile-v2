import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/admin_database_service.dart';
import '../../services/admin_export_service.dart';
import '../../widgets/export_menu_button.dart';
import '../../widgets/custom_snackbar.dart';

class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _allData = [];
  final List<Map<String, dynamic>> _filteredList = [];
  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = true;
  bool _isFilterVisible = true;

  // Filter states
  String _filterEmployeeId = 'Semua';
  String _filterType = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';

  late AnimationController _animController;

  static const _monthItems = [
    {'code': '01', 'short': 'JAN', 'full': 'Januari'},
    {'code': '02', 'short': 'FEB', 'full': 'Februari'},
    {'code': '03', 'short': 'MAR', 'full': 'Maret'},
    {'code': '04', 'short': 'APR', 'full': 'April'},
    {'code': '05', 'short': 'MEI', 'full': 'Mei'},
    {'code': '06', 'short': 'JUN', 'full': 'Juni'},
    {'code': '07', 'short': 'JUL', 'full': 'Juli'},
    {'code': '08', 'short': 'AGU', 'full': 'Agustus'},
    {'code': '09', 'short': 'SEP', 'full': 'September'},
    {'code': '10', 'short': 'OKT', 'full': 'Oktober'},
    {'code': '11', 'short': 'NOV', 'full': 'November'},
    {'code': '12', 'short': 'DES', 'full': 'Desember'},
  ];

  final List<String> _leaveTypes = ['Semua', 'Cuti Tahunan', 'Cuti Bersama', 'Sakit/Izin'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadEmployees(),
      _loadLeaveRequests(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final emps = await AdminDatabaseService().getAllEmployees();
      if (mounted) {
        setState(() => _employees = emps);
      }
    } catch (e) {
      debugPrint('Error load employees: $e');
    }
  }

  Future<void> _loadLeaveRequests() async {
    try {
      final rawList = await AdminDatabaseService().getAllLeaveRequests();

      final List<Map<String, dynamic>> processed = [];
      for (final r in rawList) {
        try {
          final startDateStr = r['start_date']?.toString() ?? '';
          final endDateStr = r['end_date']?.toString() ?? '';
          final startDate = DateTime.tryParse(startDateStr.split(' ')[0]);
          final endDate = DateTime.tryParse(endDateStr.split(' ')[0]);

          processed.add({
            ...r,
            '_startDateParsed': startDate,
            '_endDateParsed': endDate,
            '_status': _computeStatus(startDate, endDate),
            '_monthCode': startDate != null ? startDate.month.toString().padLeft(2, '0') : '',
            '_year': startDate != null ? startDate.year.toString() : '',
          });
        } catch (_) {
          processed.add({...r, '_status': '-', '_monthCode': '', '_year': ''});
        }
      }

      if (mounted) {
        setState(() {
          _allData
            ..clear()
            ..addAll(processed);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error load leave requests: $e');
    }
  }

  String _computeStatus(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    if (start == null || end == null) return '-';
    if (now.isBefore(start)) return 'Akan Datang';
    if (now.isAfter(end)) return 'Selesai';
    return 'Sedang Berlangsung';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Sedang Berlangsung':
        return const Color(0xFF15803D);
      case 'Akan Datang':
        return const Color(0xFF4338CA);
      case 'Selesai':
        return const Color(0xFF475569);
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Sedang Berlangsung':
        return const Color(0xFFDCFCE7);
      case 'Akan Datang':
        return const Color(0xFFEEF2FF);
      case 'Selesai':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  void _applyFilters() {
    final List<Map<String, dynamic>> result = [];
    for (final item in _allData) {
      if (_filterEmployeeId != 'Semua' && item['user_id']?.toString() != _filterEmployeeId) continue;
      if (_filterType != 'Semua' && item['leave_type']?.toString() != _filterType) continue;
      if (_filterMonth != 'Semua' && item['_monthCode'] != _filterMonth) continue;
      if (_filterYear != 'Semua' && item['_year'] != _filterYear) continue;
      result.add(Map.from(item));
    }
    setState(() {
      _filteredList
        ..clear()
        ..addAll(result);
    });
    _animController.forward(from: 0.0);
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterEmployeeId != 'Semua') c++;
    if (_filterType != 'Semua') c++;
    if (_filterMonth != 'Semua') c++;
    if (_filterYear != 'Semua') c++;
    return c;
  }

  // --- Delete Action ---
  Future<void> _showDeleteConfirm(Map<String, dynamic> record) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.errorColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hapus Permintaan Cuti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus permintaan cuti milik ${record['user_name']}?\nTindakan ini akan dicatat ke audit log.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ya, Hapus',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      final currentAdmin = DatabaseService().getCurrentUser();
      final adminId = currentAdmin?['id'] as int? ?? 1;

      final ok = await AdminDatabaseService().deleteLeaveRequest(
        requestId: int.parse(record['id'].toString()),
        deletedByUserId: adminId,
      );

      if (!mounted) return;
      if (ok) {
        CustomSnackbar.success(context, 'Permintaan cuti berhasil dihapus');
        _loadLeaveRequests();
      } else {
        CustomSnackbar.error(context, 'Gagal menghapus permintaan cuti');
      }
    }
  }

  // --- Export ---
  Future<void> _handleExport(BuildContext ctx, {required bool isPdf}) async {
    final currentAdmin = DatabaseService().getCurrentUser();
    final adminName = currentAdmin?['name']?.toString() ?? 'Admin';

    final exportRows = _filteredList.map((e) {
      return {
        'user_name': e['user_name'] ?? '',
        'user_role': e['user_role'] ?? '',
        'leave_type': e['leave_type'] ?? '',
        'start_date': e['start_date'] ?? '',
        'end_date': e['end_date'] ?? '',
        'reason': e['reason'] ?? '',
        'status': e['_status'] ?? '',
      };
    }).toList();

    if (isPdf) {
      await AdminExportService().exportAllLeavesPdf(
        ctx, exportRows, adminName, (Map<String, dynamic> r) => r['_status'] ?? '-',
      );
    } else {
      await AdminExportService().exportAllLeavesCsv(
        ctx, exportRows, adminName, (Map<String, dynamic> r) => r['_status'] ?? '-',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredList.length;
    final upcoming = _filteredList.where((d) => d['_status'] == 'Akan Datang').length;
    final active = _filteredList.where((d) => d['_status'] == 'Sedang Berlangsung').length;
    final finished = _filteredList.where((d) => d['_status'] == 'Selesai').length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFDCE4EC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 170,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: const Text(
                  'Kelola Izin & Cuti',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                actions: [
                  Theme(
                    data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
                    child: ExportMenuButton(
                      onPdf: (ctx) => _handleExport(ctx, isPdf: true),
                      onCsv: (ctx) => _handleExport(ctx, isPdf: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      MediaQuery.of(context).padding.top + 50,
                      18,
                      16,
                    ),
                    child: _statsRow(total: total, upcoming: upcoming, active: active, finished: finished),
                  ),
                ),
              ),
            ];
          },
          body: RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: _loadInitialData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Filter Toggle Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Panel Filter Admin',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isFilterVisible = !_isFilterVisible);
                      },
                      icon: Icon(
                        _isFilterVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      label: Text(
                        _isFilterVisible ? 'Sembunyikan' : 'Tampilkan',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Collapsible Filter Card
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _isFilterVisible ? _buildFilterCard() : const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // Data Header
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Semua Permintaan ($total)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredList.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredList.map((record) => _buildLeaveCard(record)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow({
    required int total,
    required int upcoming,
    required int active,
    required int finished,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', '$total', Colors.white),
          _statItem('Akan Datang', '$upcoming', const Color(0xFF4338CA)),
          _statItem('Aktif', '$active', const Color(0xFF15803D)),
          _statItem('Selesai', '$finished', const Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Karyawan Filter
          const Text('Karyawan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterEmployeeId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 'Semua', child: Text('Semua Karyawan')),
                  ..._employees.map((e) => DropdownMenuItem<String>(
                    value: e['id'].toString(),
                    child: Text('${e['name']} (${e['role']})'),
                  )),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() { _filterEmployeeId = v; _applyFilters(); });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Baris: Jenis, Bulan, Tahun
          Row(
            children: [
              // Jenis Pengajuan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jenis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          isExpanded: true,
                          items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() { _filterType = v; _applyFilters(); });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Bulan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterMonth,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: 'Semua', child: Text('Semua')),
                            ..._monthItems.map((m) => DropdownMenuItem(value: m['code'], child: Text(m['short']!))),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() { _filterMonth = v; _applyFilters(); });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tahun
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tahun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _buildYearDropdown(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    final years = <String>{'Semua'};
    for (final e in _allData) {
      if (e['_year']?.toString().isNotEmpty == true) years.add(e['_year']!.toString());
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterYear,
          isExpanded: true,
          items: sortedYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() { _filterYear = v; _applyFilters(); });
            }
          },
        ),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> record) {
    final userName = record['user_name']?.toString() ?? '-';
    final userRole = record['user_role']?.toString() ?? 'Staff';
    final leaveType = record['leave_type']?.toString() ?? '-';
    final startDate = record['_startDateParsed'] as DateTime?;
    final endDate = record['_endDateParsed'] as DateTime?;
    final reason = record['reason']?.toString() ?? '';
    final status = record['_status']?.toString() ?? '-';

    final statusColor = _statusColor(status);
    final statusBg = _statusBgColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Role, Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Row(
                        children: [
                          Text(
                            leaveType,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            userRole,
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body: Dates & Reason
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        startDate != null && endDate != null
                            ? '${DateFormat('dd MMM yyyy', 'id_ID').format(startDate)} — ${DateFormat('dd MMM yyyy', 'id_ID').format(endDate)}'
                            : '-',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer: Delete Button only (no edit per requirement)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showDeleteConfirm(record),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.errorColor),
                  label: const Text(
                    'Hapus',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.errorColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada data izin/cuti sesuai filter.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _filterEmployeeId = 'Semua';
                _filterType = 'Semua';
                _filterMonth = 'Semua';
                _filterYear = 'Semua';
                _applyFilters();
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filter'),
          ),
        ],
      ),
    );
  }
}