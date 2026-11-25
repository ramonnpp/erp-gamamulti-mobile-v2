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

class AdminActivityLogScreen extends StatefulWidget {
  const AdminActivityLogScreen({super.key});

  @override
  State<AdminActivityLogScreen> createState() => _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState extends State<AdminActivityLogScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _allLogs = [];
  final List<Map<String, dynamic>> _filteredLogs = [];
  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = true;
  bool _isFilterVisible = true;

  // Filter states
  String _filterEmployeeId = 'Semua';
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
      _loadActivityLogs(),
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

  Future<void> _loadActivityLogs() async {
    try {
      final rawList = await AdminDatabaseService().getAllActivityLogs();

      final List<Map<String, dynamic>> processed = [];
      for (final r in rawList) {
        final actDateStr = r['activity_date']?.toString() ?? '';
        final parts = actDateStr.split(' ')[0].split('-');
        final y = parts.isNotEmpty ? parts[0] : '';
        final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '';

        processed.add({
          ...r,
          '_month': m,
          '_year': y,
        });
      }

      if (mounted) {
        setState(() {
          _allLogs
            ..clear()
            ..addAll(processed);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error load activity logs: $e');
    }
  }

  void _applyFilters() {
    final List<Map<String, dynamic>> res = [];
    for (final item in _allLogs) {
      if (_filterEmployeeId != 'Semua' &&
          item['user_id']?.toString() != _filterEmployeeId) {
        continue;
      }
      if (_filterMonth != 'Semua' && item['_month'] != _filterMonth) {
        continue;
      }
      if (_filterYear != 'Semua' && item['_year'] != _filterYear) {
        continue;
      }
      res.add(Map.from(item));
    }

    setState(() {
      _filteredLogs
        ..clear()
        ..addAll(res);
    });
    _animController.forward(from: 0.0);
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterEmployeeId != 'Semua') c++;
    if (_filterMonth != 'Semua') c++;
    if (_filterYear != 'Semua') c++;
    return c;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final d = DateTime.parse(raw.split(' ').first);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(d);
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatCreatedAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
  }

  // --- Read-Only Detail Dialog / Modal ---
  void _showDetailBottomSheet(Map<String, dynamic> log) {
    final userName = log['user_name'] ?? 'Karyawan';
    final userRole = log['user_role'] ?? 'Staff';
    final actDate = _formatDate(log['activity_date']);
    final createdAt = _formatCreatedAt(log['created_at']);
    final content = log['log']?.toString().trim() ?? '';
    final wordCount = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header: Identity
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      userName.toString().isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          userRole,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Read-Only',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date info chips
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal Aktivitas',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            actDate,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dicatat Pada',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Isi Catatan Kegiatan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '$wordCount kata',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Log Content Container
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    content.isEmpty ? '(Tidak ada rincian kegiatan)' : content,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Delete Action ---
  Future<void> _showDeleteConfirm(Map<String, dynamic> log) async {
    final userName = log['user_name'] ?? 'Karyawan';
    final actDate = _formatDate(log['activity_date']);

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
                'Hapus Log Aktivitas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus catatan log milik $userName pada $actDate?\nTindakan ini akan dicatat ke audit log.',
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

      final ok = await AdminDatabaseService().deleteEmployeeActivityLog(
        logId: int.parse(log['id'].toString()),
        deletedByUserId: adminId,
      );

      if (!mounted) return;
      if (ok) {
        CustomSnackbar.success(context, 'Log aktivitas berhasil dihapus');
        _loadActivityLogs();
      } else {
        CustomSnackbar.error(context, 'Gagal menghapus log aktivitas');
      }
    }
  }

  // --- Export ---
  Future<void> _handleExport(BuildContext ctx, {required bool isPdf}) async {
    final currentAdmin = DatabaseService().getCurrentUser();
    final adminName = currentAdmin?['name']?.toString() ?? 'Admin';

    final exportRows = _filteredLogs.map((e) {
      return {
        'user_name': e['user_name'] ?? '',
        'user_role': e['user_role'] ?? '',
        'activity_date': e['activity_date'] ?? '',
        'log': e['log'] ?? '',
        'created_at': e['created_at'] ?? '',
      };
    }).toList();

    if (isPdf) {
      await AdminExportService().exportAllActivityLogsPdf(ctx, exportRows, adminName);
    } else {
      await AdminExportService().exportAllActivityLogsCsv(ctx, exportRows, adminName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredLogs.length;

    // Distinct employees in current filtered logs
    final distinctEmps = _filteredLogs.map((e) => e['user_id']).toSet().length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFDCE4EC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 165,
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
                  'Kelola Log Aktivitas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                actions: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
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
                    child: _statsRow(total: total, distinctEmployees: distinctEmps),
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
                // Filter Toggle Bar
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
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
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
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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
                        _isFilterVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      label: Text(
                        _isFilterVisible ? 'Sembunyikan' : 'Tampilkan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
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

                // List Header
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
                      'Semua Log Aktivitas ($total)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Ketuk kartu untuk detail',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
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
                else if (_filteredLogs.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredLogs.map((log) => _buildLogCard(log)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow({required int total, required int distinctEmployees}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total Log Tercatat', '$total', Colors.white),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
          _statItem('Karyawan Mengisi', '$distinctEmployees', const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
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
          // Filter Karyawan
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
                    setState(() {
                      _filterEmployeeId = v;
                      _applyFilters();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Baris Filter Bulan & Tahun
          Row(
            children: [
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
                            const DropdownMenuItem(value: 'Semua', child: Text('Semua Bulan')),
                            ..._monthItems.map((m) => DropdownMenuItem(
                                  value: m['code'],
                                  child: Text(m['full']!),
                                )),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _filterMonth = v;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

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
    for (final e in _allLogs) {
      if (e['_year']?.toString().isNotEmpty == true) {
        years.add(e['_year']!.toString());
      }
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
              setState(() {
                _filterYear = v;
                _applyFilters();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final userName = log['user_name'] ?? 'Karyawan';
    final userRole = log['user_role'] ?? 'Staff';
    final actDate = _formatDate(log['activity_date']);
    final timeStr = _formatTime(log['created_at']);
    final content = log['log']?.toString().trim() ?? '';

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailBottomSheet(log),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar, Name, Role, & Timestamp
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        userName.toString().isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                userRole,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  actDate,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Content snippet
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  content.isEmpty ? '(Tidak ada rincian kegiatan)' : content,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Footer: Detail Hint & Delete Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirm(log),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: AppTheme.errorColor,
                      ),
                      label: const Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.errorColor,
                        ),
                      ),
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
          const Icon(Icons.assignment_late_outlined, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada log aktivitas sesuai filter.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _filterEmployeeId = 'Semua';
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
