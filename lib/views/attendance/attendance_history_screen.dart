import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_menu_button.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;
  bool _isFilterExpanded = false;
  String _filterStatus = 'Semua';
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';

  final List<String> _months = [
    'Semua',
    '01',
    '02',
    '03',
    '04',
    '05',
    '06',
    '07',
    '08',
    '09',
    '10',
    '11',
    '12',
  ];
  final List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    final user = DatabaseService().getCurrentUser();
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final history = await DatabaseService().getAttendanceHistory(
      userId: user['id'],
    );
    Map<String, Map<String, String>> grouped = {};
    for (var record in history) {
      String date = record['date'].toString();
      String type = record['type'].toString();
      String timestamp = record['timestamp'].toString();
      if (!grouped.containsKey(date)) {
        grouped[date] = {'checkIn': '-', 'checkOut': '-'};
      }
      if (type == 'CheckIn') {
        grouped[date]!['checkIn'] = timestamp;
      } else if (type == 'CheckOut') {
        grouped[date]!['checkOut'] = timestamp;
      }
    }
    List<Map<String, dynamic>> processed = [];
    grouped.forEach((date, times) {
      try {
        String dateOnly = date.split(' ')[0].replaceAll('T', '');
        DateTime dt = DateTime.parse(dateOnly);
        String dayName = DateFormat('EEEE', 'id_ID').format(dt);
        String formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
        bool isWeekend = dt.weekday == 6 || dt.weekday == 7;
        bool hasCheckIn = times['checkIn'] != '-';
        processed.add({
          'date': formattedDate,
          'day': dayName,
          'rawDate': dateOnly,
          'checkIn': times['checkIn'],
          'checkOut': times['checkOut'],
          'status': isWeekend
              ? 'Libur'
              : (hasCheckIn ? 'Tepat Waktu' : 'Tidak Hadir'),
          'duration': _calculateDuration(times['checkIn']!, times['checkOut']!),
        });
      } catch (e) {
        debugPrint('Error parsing date "$date": $e');
      }
    });
    processed.sort(
      (a, b) => b['rawDate'].toString().compareTo(a['rawDate'].toString()),
    );
    setState(() {
      _allData = processed;
      _isLoading = false;
    });
  }

  String _calculateDuration(String checkIn, String checkOut) {
    if (checkIn == '-' || checkOut == '-') return '-';
    try {
      final inParts = checkIn.replaceAll(' WIB', '').split(':');
      final outParts = checkOut.replaceAll(' WIB', '').split(':');
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMin - inMin;
      if (diff < 0) return '-';
      return '${diff ~/ 60}j ${diff % 60}m';
    } catch (e) {
      return '-';
    }
  }

  List<String> get _availableYears {
    final years =
        _allData
            .map((e) => e['rawDate'].toString().split('-')[0])
            .toSet()
            .toList()
          ..sort();
    return ['Semua', ...years];
  }

  List<Map<String, dynamic>> get _filtered {
    return _allData.where((e) {
      final raw = e['rawDate'].toString();
      final parts = raw.split('-');
      final month = parts.length > 1 ? parts[1] : '';
      final year = parts.isNotEmpty ? parts[0] : '';
      if (_filterStatus != 'Semua' && e['status'] != _filterStatus) {
        return false;
      }
      if (_filterMonth != 'Semua' && month != _filterMonth) {
        return false;
      }
      if (_filterYear != 'Semua' && year != _filterYear) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterStatus != 'Semua') c++;
    if (_filterMonth != 'Semua') c++;
    if (_filterYear != 'Semua') c++;
    return c;
  }

  void _resetFilter() {
    setState(() {
      _filterStatus = 'Semua';
      _filterMonth = 'Semua';
      _filterYear = 'Semua';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            actions: [
              ExportMenuButton(
                onCsv: (ctx) => ExportService.exportAttendanceCsv(
                  ctx,
                  filtered,
                  DatabaseService().getCurrentUser()?['name']?.toString() ??
                      'Karyawan',
                ),
                onPdf: (ctx) => ExportService.exportAttendancePdf(
                  ctx,
                  filtered,
                  DatabaseService().getCurrentUser()?['name']?.toString() ??
                      'Karyawan',
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B4A2E), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'History Presensi',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Riwayat absensi harian',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${filtered.length} dari ${_allData.length} hari',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCollapsibleFilter(),
                  const SizedBox(height: 20),
                  _statsCard(filtered),
                  const SizedBox(height: 20),
                  const Text(
                    'Riwayat Presensi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Tidak ada data sesuai filter',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((record) => _historyCard(record)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_activeFilterCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_activeFilterCount aktif',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isFilterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterContent(),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Semua', 'Tepat Waktu', 'Libur', 'Tidak Hadir'].map((s) {
              final selected = _filterStatus == s;
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => setState(() => _filterStatus = s),
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bulan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _filterMonth,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _months.map((m) {
                          final label = m == 'Semua'
                              ? 'Semua Bulan'
                              : _monthNames[int.parse(m) - 1];
                          return DropdownMenuItem(
                            value: m,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _filterMonth = v ?? 'Semua'),
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
                    const Text(
                      'Tahun',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _filterYear,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _availableYears.map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(
                              y == 'Semua' ? 'Semua Tahun' : y,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _filterYear = v ?? 'Semua'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetFilter,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(List<Map<String, dynamic>> data) {
    final total = data.length;
    final hadir = data.where((d) => d['status'] == 'Tepat Waktu').length;
    final libur = data.where((d) => d['status'] == 'Libur').length;
    final tidakHadir = data.where((d) => d['status'] == 'Tidak Hadir').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B4A2E), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCard(
                label: 'Total',
                value: '$total',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Hadir',
                value: '$hadir',
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Libur',
                value: '$libur',
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Tidak Hadir',
                value: '$tidakHadir',
                color: AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> record) {
    final isLibur = record['status'] == 'Libur';
    final isTidakHadir = record['status'] == 'Tidak Hadir';
    final color = isLibur
        ? AppTheme.textSecondary
        : (isTidakHadir ? AppTheme.errorColor : AppTheme.successColor);
    final icon = isLibur
        ? Icons.weekend_rounded
        : (isTidakHadir ? Icons.cancel_rounded : Icons.check_circle_rounded);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${record['day']}, ${record['date']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record['status'].toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLibur) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.login_rounded,
                            size: 14,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            record['checkIn'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            record['checkOut'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        record['duration'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
