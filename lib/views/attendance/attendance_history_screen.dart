import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_menu_button.dart';
import '../../widgets/custom_snackbar.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _allData = [];
  final List<dynamic> _filteredList = [];
  final List<String> _yearsList = ['Semua'];
  bool _isLoading = true;
  bool _isPeriodPanelOpen = false;
  bool _isFilterHubVisible = true;
  String _filterStatus = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';
  int _expandedIndex = -1;
  List<Map<String, dynamic>> _shifts = [];
  bool _isSavingShift = false;

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

  String _formatTimeShort(String raw) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return raw;
    return '${match.group(1)}.${match.group(2)}';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAttendanceHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadShifts() async {
    final shifts = await DatabaseService().getShifts();
    if (mounted) setState(() => _shifts = shifts);
  }

  Future<void> _loadAttendanceHistory() async {
    final user = DatabaseService().getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Load shifts concurrently with history
    _loadShifts();

    final history = await DatabaseService().getAttendanceHistory(
      userId: user['id'],
    );

    final Map<String, dynamic> grouped = {};
    for (final record in history) {
      final date = record['date'].toString();
      final type = record['type'].toString();
      final timestamp = record['timestamp'].toString();
      if (!grouped.containsKey(date)) {
        grouped[date] = {
          'checkIn': '-',
          'checkOut': '-',
          'shift_name': '',
          'shift_time': '',
          'status': '',
        };
      }
      if (type == 'CheckIn') {
        grouped[date]['checkIn'] = timestamp;
        // Ambil shift dan status dari record CheckIn pertama hari itu
        final shiftName = record['shift_name']?.toString();
        final start = record['shift_start']?.toString();
        final end = record['shift_end']?.toString();
        final statusVal = record['status']?.toString();

        if (shiftName != null && shiftName.isNotEmpty) {
          grouped[date]['shift_name'] = shiftName;
        }
        if (start != null && end != null) {
          grouped[date]['shift_time'] = '${_formatTimeShort(start)} - ${_formatTimeShort(end)}';
        }
        if (statusVal != null && statusVal.isNotEmpty) {
          grouped[date]['status'] = statusVal;
        }
      } else if (type == 'CheckOut') {
        grouped[date]['checkOut'] = timestamp;
      }
    }

    final List<dynamic> processed = [];
    final Map<String, bool> yearMap = {};
    grouped.forEach((date, times) {
      try {
        final dateOnly = date.toString().split(' ')[0].replaceAll('T', '');
        final dt = DateTime.parse(dateOnly);
        final dayName = DateFormat('EEEE', 'id_ID').format(dt);
        final shortMonth = DateFormat('MMM', 'id_ID').format(dt).toUpperCase();
        final dayNum = DateFormat('dd', 'id_ID').format(dt);
        final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
        final isWeekend = dt.weekday == 6 || dt.weekday == 7;
        final checkInStr = times['checkIn']?.toString() ?? '-';
        final checkOutStr = times['checkOut']?.toString() ?? '-';
        final hasCheckIn = checkInStr != '-';
        final storedStatus = (times['status'] as String?)?.trim();
        final shiftName = (times['shift_name'] as String?)?.trim() ?? '';
        final shiftTime = (times['shift_time'] as String?)?.trim() ?? '';

        yearMap[dateOnly.split('-')[0]] = true;

        // Tentukan status: Libur > (dari DB) > Tepat Waktu/Terlambat > Tidak Hadir
        String status;
        if (isWeekend) {
          status = 'Libur';
        } else if (storedStatus == 'Terlambat' || storedStatus == 'Tepat Waktu') {
          status = storedStatus!;
        } else if (hasCheckIn) {
          status = 'Tepat Waktu';
        } else {
          status = 'Tidak Hadir';
        }

        processed.add({
          'date': formattedDate,
          'day': dayName,
          'shortMonth': shortMonth,
          'dayNum': dayNum,
          'rawDate': dateOnly,
          'checkIn': checkInStr,
          'checkOut': checkOutStr,
          'status': status,
          'shift_name': shiftName,
          'shift_time': shiftTime,
          'duration': _calculateDuration(checkInStr, checkOutStr),
        });
      } catch (e) {
        debugPrint('Error parsing date "$date": $e');
      }
    });

    processed.sort(
      (a, b) => b['rawDate'].toString().compareTo(a['rawDate'].toString()),
    );

    final sortedYears = yearMap.keys.map((y) => y.toString()).toList()..sort();

    if (mounted) {
      setState(() {
        _allData
          ..clear()
          ..addAll(processed);
        _yearsList
          ..clear()
          ..add('Semua')
          ..addAll(sortedYears);
        _applyFilters();
        _isLoading = false;
      });
      _animController.forward(from: 0.0);
    }
  }

  void _applyFilters() {
    final List<dynamic> result = [];
    for (final e in _allData) {
      final raw = e['rawDate'].toString();
      final parts = raw.split('-');
      final month = parts.length > 1 ? parts[1] : '';
      final year = parts.isNotEmpty ? parts[0] : '';

      if (_filterStatus != 'Semua' && e['status'] != _filterStatus) {
        continue;
      }
      if (_filterMonth != 'Semua' && month != _filterMonth) {
        continue;
      }
      if (_filterYear != 'Semua' && year != _filterYear) {
        continue;
      }
      result.add(Map.from(e));
    }
    _filteredList
      ..clear()
      ..addAll(result);
    _expandedIndex = -1;
    _animController.forward(from: 0.0);
  }

  String _calculateDuration(String checkIn, String checkOut) {
    if (checkIn == '-' || checkOut == '-') return '-';
    try {
      final cleanIn = checkIn
          .toUpperCase()
          .replaceAll('WIB', '')
          .replaceAll('WITA', '')
          .replaceAll('WIT', '')
          .replaceAll('.', ':')
          .trim();
      final cleanOut = checkOut
          .toUpperCase()
          .replaceAll('WIB', '')
          .replaceAll('WITA', '')
          .replaceAll('WIT', '')
          .replaceAll('.', ':')
          .trim();

      final inParts = cleanIn.split(':');
      final outParts = cleanOut.split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMin - inMin;
      if (diff < 0) return '-';
      return '${diff ~/ 60}j ${diff % 60}m';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _showShiftSelector(Map record) async {
    int? selectedShiftId = record['shift_id'] as int?;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ubah Shift',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record['date'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._shifts.map((shift) {
                    final shiftId = shift['id'] as int;
                    final shiftName = shift['name'] as String;
                    final startTime = _formatTimeShort(shift['start_time'] ?? '');
                    final endTime = _formatTimeShort(shift['end_time'] ?? '');
                    final isSelected = selectedShiftId == shiftId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setModalState(() => selectedShiftId = shiftId),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shiftName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$startTime - $endTime',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedShiftId != null
                              ? () => Navigator.pop(ctx, selectedShiftId)
                              : null,
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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
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
      },
    );
    if (result != null) {
      await _confirmEditShift(record, result);
    }
  }

  Future<void> _confirmEditShift(Map record, int newShiftId) async {
    if (_isSavingShift) return;
    final user = DatabaseService().getCurrentUser();
    if (user == null) return;
    setState(() => _isSavingShift = true);
    final ok = await DatabaseService().updateAttendanceShift(
      userId: user['id'] as int,
      date: record['rawDate'],
      shiftId: newShiftId,
    );
    setState(() => _isSavingShift = false);
    if (!mounted) return;
    if (ok) {
      await _loadAttendanceHistory();
      CustomSnackbar.success(context, 'Shift berhasil diubah');
    } else {
      CustomSnackbar.error(context, 'Gagal mengubah shift. Coba lagi.');
    }
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterStatus != 'Semua') c++;
    if (_filterMonth != 'Semua') c++;
    if (_filterYear != 'Semua') c++;
    return c;
  }

  String get _periodLabel {
    if (_filterMonth == 'Semua' && _filterYear == 'Semua') {
      return 'Semua Periode';
    }
    String mLabel = '';
    if (_filterMonth != 'Semua') {
      for (final item in _monthItems) {
        if (item['code'] == _filterMonth) {
          mLabel = item['full'] ?? '';
          break;
        }
      }
    }
    final yLabel = _filterYear == 'Semua' ? '' : _filterYear;
    return '$mLabel $yLabel'.trim();
  }

  void _selectQuickPreset(String preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      if (preset == 'all') {
        _filterMonth = 'Semua';
        _filterYear = 'Semua';
      } else if (preset == 'this_month') {
        _filterMonth = now.month.toString().padLeft(2, '0');
        _filterYear = now.year.toString();
      } else if (preset == 'last_month') {
        final prev = DateTime(now.year, now.month - 1, 1);
        _filterMonth = prev.month.toString().padLeft(2, '0');
        _filterYear = prev.year.toString();
      }
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        DatabaseService().getCurrentUser()?['name']?.toString() ?? 'Karyawan';

    final total = _filteredList.length;
    final hadir = _filteredList
        .where((d) => d['status'] == 'Tepat Waktu')
        .length;
    final libur = _filteredList.where((d) => d['status'] == 'Libur').length;
    final tidakHadir = _filteredList
        .where((d) => d['status'] == 'Tidak Hadir')
        .length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFDCE4EC),
        body: Column(
          children: [
            // --- HEADER HIJAU TETAP DI ATAS DENGAN DESAIN HALUS & TIDAK KAKU ---
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 10,
                14,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          size: 22,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'History Presensi',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_periodLabel • $total catatan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentColor.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        child: ExportMenuButton(
                          onCsv: (ctx) async {
                            final exportRows = [
                              for (final e in _filteredList)
                                {
                                  for (final entry in (e as Map).entries)
                                    entry.key.toString(): entry.value,
                                },
                            ];
                            await ExportService.exportAttendanceCsv(
                              ctx,
                              exportRows,
                              userName,
                            );
                          },
                          onPdf: (ctx) async {
                            final exportRows = [
                              for (final e in _filteredList)
                                {
                                  for (final entry in (e as Map).entries)
                                    entry.key.toString(): entry.value,
                                },
                            ];
                            await ExportService.exportAttendancePdf(
                              ctx,
                              exportRows,
                              userName,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _darkSegmentedGauge(
                    total: total,
                    hadir: hadir,
                    libur: libur,
                    tidakHadir: tidakHadir,
                  ),
                ],
              ),
            ),

            // --- KONTEN BAWAH YANG BISA DI-SCROLL DENGAN AMAN DARI NAVBAR ---
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _loadAttendanceHistory,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  // PADDING BAWAH 130: Mencegah item terbawah tertutup navbar melayang
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                  children: [
                    // Toggle Button Bar untuk Sembunyikan/Tampilkan Filter
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
                              'Filter',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
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
                            setState(() {
                              _isFilterHubVisible = !_isFilterHubVisible;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          icon: Icon(
                            _isFilterHubVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _isFilterHubVisible ? 'Sembunyikan' : 'Tampilkan',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Animated Collapse/Expand Filter Card dengan kurva halus
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: _isFilterHubVisible
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _interactiveFilterHub(),
                            )
                          : const SizedBox.shrink(),
                    ),

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
                          'Catatan Harian',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Ketuk baris untuk rincian',
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
                          padding: EdgeInsets.all(42),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    else if (_filteredList.isEmpty)
                      _emptyStateCard()
                    else
                      Column(
                        children: [
                          for (
                            int index = 0;
                            index < _filteredList.length;
                            index++
                          )
                            _AnimatedEntry(
                              delayMs: 80 + ((index > 8 ? 8 : index) * 35),
                              child: _richAccordionCard(
                                record: _filteredList[index],
                                index: index,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interactiveFilterHub() {
    int countAll = 0;
    int countHadir = 0;
    int countLibur = 0;
    int countAbsen = 0;

    for (final e in _allData) {
      final raw = e['rawDate'].toString();
      final parts = raw.split('-');
      final month = parts.length > 1 ? parts[1] : '';
      final year = parts.isNotEmpty ? parts[0] : '';

      if (_filterMonth != 'Semua' && month != _filterMonth) continue;
      if (_filterYear != 'Semua' && year != _filterYear) continue;

      countAll++;
      final st = e['status'].toString();
      if (st == 'Tepat Waktu') countHadir++;
      if (st == 'Libur') countLibur++;
      if (st == 'Tidak Hadir') countAbsen++;
    }

    final statusOptions = [
      {
        'label': 'Semua',
        'count': countAll,
        'icon': Icons.apps_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'label': 'Tepat Waktu',
        'count': countHadir,
        'icon': Icons.verified_rounded,
        'color': AppTheme.successColor,
      },
      {
        'label': 'Libur',
        'count': countLibur,
        'icon': Icons.weekend_rounded,
        'color': const Color(0xFFD97706),
      },
      {
        'label': 'Tidak Hadir',
        'count': countAbsen,
        'icon': Icons.cancel_rounded,
        'color': AppTheme.errorColor,
      },
    ];

    final now = DateTime.now();
    final thisMonthCode = now.month.toString().padLeft(2, '0');
    final thisYearCode = now.year.toString();
    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevMonthCode = prevDate.month.toString().padLeft(2, '0');
    final prevYearCode = prevDate.year.toString();

    final isAllPreset = _filterMonth == 'Semua' && _filterYear == 'Semua';
    final isThisMonthPreset =
        _filterMonth == thisMonthCode && _filterYear == thisYearCode;
    final isLastMonthPreset =
        _filterMonth == prevMonthCode && _filterYear == prevYearCode;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC2CFDD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFE9EFF5),
              border: Border(bottom: BorderSide(color: Color(0xFFD0DCE8))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_alt_rounded,
                    size: 14,
                    color: AppTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Menu Filter',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_activeFilterCount > 0)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _filterStatus = 'Semua';
                        _filterMonth = 'Semua';
                        _filterYear = 'Semua';
                        _applyFilters();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 13,
                            color: AppTheme.errorColor,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: statusOptions.map((item) {
                      final label = item['label'].toString();
                      final count = item['count'] as int;
                      final icon = item['icon'] as IconData;
                      final chipColor = item['color'] as Color;
                      final active = _filterStatus == label;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _filterStatus = label;
                              _applyFilters();
                            });
                          },
                          child: AnimatedScale(
                            scale: active ? 1.0 : 0.97,
                            duration: const Duration(milliseconds: 160),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active ? chipColor : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? chipColor
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: chipColor.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
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
                                    color: active ? Colors.white : chipColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: active
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? Colors.white.withValues(alpha: 0.22)
                                          : chipColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: active
                                            ? Colors.white
                                            : chipColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _presetChip(
                        label: 'Semua',
                        active: isAllPreset,
                        onTap: () => _selectQuickPreset('all'),
                      ),
                      const SizedBox(width: 6),
                      _presetChip(
                        label: 'Bulan Ini',
                        active: isThisMonthPreset,
                        onTap: () => _selectQuickPreset('this_month'),
                      ),
                      const SizedBox(width: 6),
                      _presetChip(
                        label: 'Bulan Lalu',
                        active: isLastMonthPreset,
                        onTap: () => _selectQuickPreset('last_month'),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isPeriodPanelOpen = !_isPeriodPanelOpen;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6.5,
                          ),
                          decoration: BoxDecoration(
                            color: _isPeriodPanelOpen
                                ? AppTheme.primaryColor
                                : const Color(0xFFE7EEF6),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _isPeriodPanelOpen
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFC2CFDD),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_view_month_rounded,
                                size: 14,
                                color: _isPeriodPanelOpen
                                    ? AppTheme.accentColor
                                    : AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Pilih Bulan',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _isPeriodPanelOpen
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              AnimatedRotation(
                                turns: _isPeriodPanelOpen ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: _isPeriodPanelOpen
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _isPeriodPanelOpen
                      ? Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E3E29),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_note_rounded,
                                    size: 14,
                                    color: AppTheme.accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Tahun:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: Row(
                                        children: _yearsList.map((y) {
                                          final selected = _filterYear == y;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() {
                                                  _filterYear = y;
                                                  _applyFilters();
                                                });
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 160,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? AppTheme.accentColor
                                                      : Colors.white.withValues(
                                                          alpha: 0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  y,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: selected
                                                        ? AppTheme.primaryColor
                                                        : Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 4,
                                mainAxisSpacing: 7,
                                crossAxisSpacing: 7,
                                childAspectRatio: 2.35,
                                children: _monthItems.map((m) {
                                  final code = m['code'].toString();
                                  final shortLabel = m['short'].toString();
                                  final selected = _filterMonth == code;

                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _filterMonth = selected
                                            ? 'Semua'
                                            : code;
                                        _applyFilters();
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 170,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppTheme.accentColor
                                            : Colors.black.withValues(
                                                alpha: 0.25,
                                              ),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.accentColor
                                              : Colors.white.withValues(
                                                  alpha: 0.14,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        shortLabel,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: selected
                                              ? AppTheme.primaryColor
                                              : Colors.white.withValues(
                                                  alpha: 0.88,
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
            width: active ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _darkSegmentedGauge({
    required int total,
    required int hadir,
    required int libur,
    required int tidakHadir,
  }) {
    final safeTotal = total == 0 ? 1 : total;
    final hadirFlex = total == 0 ? 1 : (hadir * 100 ~/ safeTotal).clamp(0, 100);
    final liburFlex = total == 0 ? 0 : (libur * 100 ~/ safeTotal).clamp(0, 100);
    final absenFlex = total == 0
        ? 0
        : (tidakHadir * 100 ~/ safeTotal).clamp(0, 100);

    final int rate = (hadir + tidakHadir) == 0
        ? 100
        : ((hadir * 100) ~/ (hadir + tidakHadir));

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tingkat Kedisiplinan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rate% Hadir',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 7,
              child: total == 0
                  ? Container(color: Colors.white.withValues(alpha: 0.16))
                  : Row(
                      children: [
                        if (hadirFlex > 0)
                          Expanded(
                            flex: hadirFlex,
                            child: Container(color: const Color(0xFF34D399)),
                          ),
                        if (liburFlex > 0)
                          Expanded(
                            flex: liburFlex,
                            child: Container(color: AppTheme.accentColor),
                          ),
                        if (absenFlex > 0)
                          Expanded(
                            flex: absenFlex,
                            child: Container(color: const Color(0xFFF87171)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _darkLegend('Total', '$total', Colors.white),
              _darkLegend('Hadir', '$hadir', const Color(0xFF34D399)),
              _darkLegend('Libur', '$libur', AppTheme.accentColor),
              _darkLegend('Absen', '$tidakHadir', const Color(0xFFF87171)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkLegend(String label, String value, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: dotColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _richAccordionCard({required Map record, required int index}) {
    final bool isExpanded = _expandedIndex == index;
    final status = record['status'].toString();
    final isLibur = status == 'Libur';
    final isTidakHadir = status == 'Tidak Hadir';

    final accentColor = isLibur
        ? const Color(0xFFD97706)
        : (isTidakHadir ? AppTheme.errorColor : AppTheme.successColor);
    final headerTint = isLibur
        ? const Color(0xFFFEF6E4)
        : (isTidakHadir ? const Color(0xFFFEECEC) : const Color(0xFFE7F7F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? accentColor.withValues(alpha: 0.65)
              : const Color(0xFFC5D1DE),
          width: isExpanded ? 1.4 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: isExpanded ? headerTint : Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? -1 : index;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 48,
                      decoration: BoxDecoration(
                        color: headerTint,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            record['dayNum'].toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            record['shortMonth'].toString(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['day'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isLibur)
                            const Text(
                              'Akhir Pekan • Libur',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  record['checkIn'].toString(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.logout_rounded,
                                  size: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    record['checkOut'].toString(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Tampilkan shift jika ada
                        if (record['shift_name'] != null && record['shift_name'].toString().isNotEmpty && !isLibur)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  record['shift_name'].toString(),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                if (record['shift_time'] != null && record['shift_time'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '(${record['shift_time']})',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isLibur) ...[
                              Text(
                                record['duration'].toString(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Material(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _showShiftSelector(record);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4.5,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF3F8),
                border: Border(top: BorderSide(color: Color(0xFFD5DFEA))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Lengkap: ${record['date']}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          'Masuk',
                          record['checkIn'].toString(),
                          AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _detailTile(
                          'Pulang',
                          record['checkOut'].toString(),
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _detailTile(
                          'Durasi',
                          record['duration'].toString(),
                          const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC5D1DE)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 38,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada catatan presensi pada filter ini.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _filterStatus = 'Semua';
                _filterMonth = 'Semua';
                _filterYear = 'Semua';
                _applyFilters();
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Reset Semua Filter',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedEntry extends StatefulWidget {
  final int delayMs;
  final Widget child;
  const _AnimatedEntry({required this.delayMs, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.delayMs;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.03),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}