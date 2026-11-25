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

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _groupedList = [];
  final List<Map<String, dynamic>> _filteredList = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _shifts = [];
  final List<String> _yearsList = ['Semua'];

  bool _isLoading = true;
  bool _isFilterVisible = true;

  // Filter states
  String _filterEmployeeId = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';
  String _filterShiftId = 'Semua';
  String _filterStatus = 'Semua';

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
      _loadEmployeesAndShifts(),
      _loadAttendance(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployeesAndShifts() async {
    try {
      final emps = await AdminDatabaseService().getAllEmployees();
      final shfs = await DatabaseService().getShifts();
      if (mounted) {
        setState(() {
          _employees = emps;
          _shifts = shfs;
        });
      }
    } catch (e) {
      debugPrint('Error load employees or shifts: $e');
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final rawList = await AdminDatabaseService().getAllAttendance();

      // Group by user_id and date so 1 card represents 1 day's attendance
      final Map<String, Map<String, dynamic>> grouped = {};
      final Set<String> detectedYears = {};

      for (final r in rawList) {
        final dateStr = r['date']?.toString() ?? '';
        final dateOnly = dateStr.split(' ')[0].replaceAll('T', '').trim();
        final userId = r['user_id']?.toString() ?? r['user_name']?.toString() ?? '';
        final groupKey = '${userId}_$dateOnly';

        if (dateOnly.contains('-')) {
          detectedYears.add(dateOnly.split('-')[0]);
        }

        if (!grouped.containsKey(groupKey)) {
          grouped[groupKey] = {
            'user_id': r['user_id'],
            'user_name': r['user_name'] ?? 'Karyawan',
            'user_role': r['user_role'] ?? 'Staff',
            'rawDate': dateOnly,
            'checkInId': null,
            'checkIn': '-',
            'checkOutId': null,
            'checkOut': '-',
            'shift_id': r['shift_id'],
            'shift_name': r['shift_name'] ?? 'N/A',
            'status': r['status'] ?? 'Tepat Waktu',
          };
        }

        final type = r['type']?.toString();
        final timeStr = r['timestamp']?.toString() ?? '-';
        final attId = int.tryParse(r['id']?.toString() ?? '');

        if (type == 'CheckIn') {
          grouped[groupKey]!['checkInId'] = attId;
          grouped[groupKey]!['checkIn'] = timeStr;
          grouped[groupKey]!['shift_id'] = r['shift_id'];
          grouped[groupKey]!['shift_name'] = r['shift_name'] ?? 'N/A';
          grouped[groupKey]!['status'] = r['status'] ?? 'Tepat Waktu';
        } else if (type == 'CheckOut') {
          grouped[groupKey]!['checkOutId'] = attId;
          grouped[groupKey]!['checkOut'] = timeStr;
        }
      }

      final List<Map<String, dynamic>> processed = [];
      grouped.forEach((key, map) {
        try {
          final dt = DateTime.parse(map['rawDate']);
          map['day'] = DateFormat('EEEE', 'id_ID').format(dt);
          map['date'] = DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
          map['dayNum'] = DateFormat('dd', 'id_ID').format(dt);
          map['shortMonth'] = DateFormat('MMM', 'id_ID').format(dt).toUpperCase();
          map['duration'] = _calculateDuration(
            map['checkIn'].toString(),
            map['checkOut'].toString(),
          );
          processed.add(map);
        } catch (_) {
          map['day'] = '-';
          map['date'] = map['rawDate'];
          map['dayNum'] = '--';
          map['shortMonth'] = '-';
          map['duration'] = '-';
          processed.add(map);
        }
      });

      processed.sort((a, b) => b['rawDate'].toString().compareTo(a['rawDate'].toString()));

      final sortedYears = detectedYears.toList()..sort();

      if (mounted) {
        setState(() {
          _groupedList
            ..clear()
            ..addAll(processed);
          _yearsList
            ..clear()
            ..add('Semua')
            ..addAll(sortedYears);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error load attendance history: $e');
    }
  }

  void _applyFilters() {
    final List<Map<String, dynamic>> res = [];
    for (final item in _groupedList) {
      final raw = item['rawDate'].toString();
      final parts = raw.split('-');
      final y = parts.isNotEmpty ? parts[0] : '';
      final m = parts.length > 1 ? parts[1] : '';

      // Filter Employee
      if (_filterEmployeeId != 'Semua' &&
          item['user_id']?.toString() != _filterEmployeeId) {
        continue;
      }
      // Filter Month
      if (_filterMonth != 'Semua' && m != _filterMonth) {
        continue;
      }
      // Filter Year
      if (_filterYear != 'Semua' && y != _filterYear) {
        continue;
      }
      // Filter Shift
      if (_filterShiftId != 'Semua' &&
          item['shift_id']?.toString() != _filterShiftId) {
        continue;
      }
      // Filter Status
      if (_filterStatus != 'Semua' && item['status'] != _filterStatus) {
        continue;
      }

      res.add(item);
    }

    setState(() {
      _filteredList
        ..clear()
        ..addAll(res);
    });
    _animController.forward(from: 0.0);
  }

  String _calculateDuration(String checkIn, String checkOut) {
    if (checkIn == '-' || checkOut == '-') return '-';
    try {
      final inClean = checkIn.replaceAll(RegExp(r'[^\d:]'), '').trim();
      final outClean = checkOut.replaceAll(RegExp(r'[^\d:]'), '').trim();
      final inParts = inClean.split(':');
      final outParts = outClean.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMin - inMin;
      if (diff < 0) return '-';
      return '${diff ~/ 60}j ${diff % 60}m';
    } catch (_) {
      return '-';
    }
  }

  // --- Actions: Edit Dialog ---
  Future<void> _showEditDialog(Map<String, dynamic> record) async {
    final inCtrl = TextEditingController(
      text: record['checkIn'] == '-' ? '' : record['checkIn'],
    );
    final outCtrl = TextEditingController(
      text: record['checkOut'] == '-' ? '' : record['checkOut'],
    );

    int? selectedShiftId = int.tryParse(record['shift_id']?.toString() ?? '');
    if (selectedShiftId == null || selectedShiftId <= 0) {
      if (_shifts.isNotEmpty) {
        selectedShiftId = _shifts.first['id'] as int?;
      }
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_calendar_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Presensi: ${record['user_name']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${record['date']} (${record['user_role']})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Shift Selector
                    const Text(
                      'Pilih Shift Kerja',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedShiftId,
                          isExpanded: true,
                          items: _shifts.map((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text(
                                '${s['name']} (${s['start_time']} - ${s['end_time']})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedShiftId = v);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Check In Time
                    const Text(
                      'Jam Masuk (Format: HH:mm atau HH:mm:ss)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: inCtrl,
                      decoration: InputDecoration(
                        hintText: 'Misal: 08:00:00',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        prefixIcon: const Icon(Icons.login_rounded, size: 18),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Check Out Time
                    const Text(
                      'Jam Keluar (Format: HH:mm atau HH:mm:ss)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: outCtrl,
                      decoration: InputDecoration(
                        hintText: 'Misal: 17:00:00',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        prefixIcon: const Icon(Icons.logout_rounded, size: 18),
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
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Simpan',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final currentAdmin = DatabaseService().getCurrentUser();
      final adminId = currentAdmin?['id'] as int? ?? 1;
      final shiftId = selectedShiftId ?? 1;

      bool success = true;

      // Update CheckIn if exists
      if (record['checkInId'] != null) {
        final okIn = await AdminDatabaseService().updateEmployeeAttendance(
          attendanceId: record['checkInId'] as int,
          time: inCtrl.text.trim().isEmpty ? '08:00:00' : inCtrl.text.trim(),
          shiftId: shiftId,
          updatedByUserId: adminId,
        );
        if (!okIn) success = false;
      }

      // Update CheckOut if exists
      if (record['checkOutId'] != null) {
        final okOut = await AdminDatabaseService().updateEmployeeAttendance(
          attendanceId: record['checkOutId'] as int,
          time: outCtrl.text.trim().isEmpty ? '17:00:00' : outCtrl.text.trim(),
          shiftId: shiftId,
          updatedByUserId: adminId,
        );
        if (!okOut) success = false;
      }

      if (!mounted) return;
      if (success) {
        CustomSnackbar.success(context, 'Data presensi berhasil diperbarui');
        _loadAttendance();
      } else {
        CustomSnackbar.error(context, 'Gagal memperbarui beberapa record');
      }
    }
  }

  // --- Actions: Delete Dialog ---
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
                'Hapus Data Presensi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus catatan presensi milik ${record['user_name']} pada tanggal ${record['date']}?\nTindakan ini akan dicatat ke audit log.',
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

      bool ok = true;
      if (record['checkInId'] != null) {
        ok = await AdminDatabaseService().deleteEmployeeAttendance(
          attendanceId: record['checkInId'] as int,
          deletedByUserId: adminId,
        );
      }
      if (record['checkOutId'] != null) {
        final okOut = await AdminDatabaseService().deleteEmployeeAttendance(
          attendanceId: record['checkOutId'] as int,
          deletedByUserId: adminId,
        );
        if (!okOut) ok = false;
      }

      if (!mounted) return;
      if (ok) {
        CustomSnackbar.success(context, 'Data presensi berhasil dihapus');
        _loadAttendance();
      } else {
        CustomSnackbar.error(context, 'Gagal menghapus presensi');
      }
    }
  }

  // --- Export Handling ---
  Future<void> _handleExport(BuildContext ctx, {required bool isPdf}) async {
    final currentAdmin = DatabaseService().getCurrentUser();
    final adminName = currentAdmin?['name']?.toString() ?? 'Admin';

    final exportRows = _filteredList.map((e) {
      return {
        'user_name': e['user_name'] ?? '',
        'user_role': e['user_role'] ?? '',
        'date': e['date'] ?? '',
        'day': e['day'] ?? '',
        'checkIn': e['checkIn'] ?? '-',
        'checkOut': e['checkOut'] ?? '-',
        'duration': e['duration'] ?? '-',
        'status': e['status'] ?? 'Tepat Waktu',
      };
    }).toList();

    if (isPdf) {
      await AdminExportService().exportAllAttendancePdf(ctx, exportRows, adminName);
    } else {
      await AdminExportService().exportAllAttendanceCsv(ctx, exportRows, adminName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredList.length;
    final tepatWaktu = _filteredList.where((d) => d['status'] == 'Tepat Waktu').length;
    final terlambat = _filteredList.where((d) => d['status'] == 'Terlambat').length;
    final libur = _filteredList.where((d) => d['status'] == 'Libur').length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFDCE4EC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 180,
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
                  'Kelola Presensi Karyawan',
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
                      MediaQuery.of(context).padding.top + 60,
                      18,
                      16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _statsGaugeBar(
                          total: total,
                          tepatWaktu: tepatWaktu,
                          terlambat: terlambat,
                          libur: libur,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: _loadAttendance,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Collapsible Filter Header
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
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isFilterVisible = !_isFilterVisible);
                      },
                      icon: Icon(
                        _isFilterVisible
                            ? Icons.filter_list_off_rounded
                            : Icons.filter_list_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      label: Text(
                        _isFilterVisible ? 'Tutup Filter' : 'Buka Filter',
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

                // Collapsible Filter Content
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _isFilterVisible
                      ? _buildFilterCard()
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 14),

                // List of Records Header
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
                      'Semua Presensi ($total data)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
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
                else if (_filteredList.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredList.map((record) => _buildAttendanceCard(record)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsGaugeBar({
    required int total,
    required int tepatWaktu,
    required int terlambat,
    required int libur,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', '$total', Colors.white),
          _statItem('Tepat Waktu', '$tepatWaktu', const Color(0xFF34D399)),
          _statItem('Terlambat', '$terlambat', const Color(0xFFFBBF24)),
          _statItem('Libur', '$libur', const Color(0xFF93C5FD)),
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
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
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
          const Text(
            'Karyawan',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
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
                  ..._employees.map((e) {
                    return DropdownMenuItem<String>(
                      value: e['id'].toString(),
                      child: Text('${e['name']} (${e['role']})'),
                    );
                  }),
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

          // Baris Filter Bulan, Tahun & Shift
          Row(
            children: [
              // Bulan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bulan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
                            ..._monthItems.map((m) {
                              return DropdownMenuItem<String>(
                                value: m['code'],
                                child: Text(m['short']!),
                              );
                            }),
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
              const SizedBox(width: 8),

              // Tahun
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tahun',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
                          value: _filterYear,
                          isExpanded: true,
                          items: _yearsList.map((y) {
                            return DropdownMenuItem<String>(value: y, child: Text(y));
                          }).toList(),
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
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Shift
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
                          value: _filterShiftId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: 'Semua', child: Text('Semua')),
                            ..._shifts.map((s) {
                              return DropdownMenuItem<String>(
                                value: s['id'].toString(),
                                child: Text(s['name'] ?? ''),
                              );
                            }),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _filterShiftId = v;
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
            ],
          ),

          const SizedBox(height: 12),

          // Status Filter Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Semua', 'Tepat Waktu', 'Terlambat', 'Libur', 'Tidak Hadir'].map((st) {
              final active = _filterStatus == st;
              return ChoiceChip(
                label: Text(st),
                selected: active,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filterStatus = st;
                      _applyFilters();
                    });
                  }
                },
                selectedColor: AppTheme.primaryColor,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final status = record['status']?.toString() ?? 'Tepat Waktu';
    final isTerlambat = status == 'Terlambat';
    final isLibur = status == 'Libur';

    final Color badgeColor = isTerlambat
        ? const Color(0xFFD97706)
        : isLibur
            ? const Color(0xFF2563EB)
            : AppTheme.successColor;

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
          // Header Card: Employee Name, Role, & Date
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    record['user_name'] != null && record['user_name'].toString().isNotEmpty
                        ? record['user_name'].toString()[0].toUpperCase()
                        : '?',
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
                        record['user_name'] ?? '-',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            record['user_role'] ?? 'Staff',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            '${record['day']}, ${record['date']}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Info Body: Shift, Masuk, Keluar, Durasi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _timeCol('Shift', record['shift_name'] ?? '-', Icons.work_outline_rounded),
                _timeCol('Masuk', record['checkIn'] ?? '-', Icons.login_rounded),
                _timeCol('Keluar', record['checkOut'] ?? '-', Icons.logout_rounded),
                _timeCol('Durasi', record['duration'] ?? '-', Icons.timer_outlined),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer Action Buttons: Edit & Delete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(record),
                  icon: const Icon(Icons.edit_rounded, size: 15, color: AppTheme.primaryColor),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirm(record),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.errorColor),
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
    );
  }

  Widget _timeCol(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
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
          const Icon(Icons.event_busy_rounded, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada riwayat presensi yang sesuai filter.',
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
                _filterShiftId = 'Semua';
                _filterStatus = 'Semua';
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
