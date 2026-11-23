import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_menu_button.dart';
import '../../widgets/custom_snackbar.dart';
import 'add_activity_log_sheet.dart';
import 'activity_log_detail_sheet.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  bool _isFilterExpanded = false;
  String _filterMonth = 'Semua';
  String _filterYear = 'Semua';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> _months = const [
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadLogs();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseService().getActivityLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _applyFilter();
      _isLoading = false;
    });
    _animController.forward(from: 0.0);
  }

  String _formatCreatedAt(String raw) {
    try {
      return DateFormat(
        'dd MMM yyyy • HH:mm',
        'id_ID',
      ).format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatActivityDate(String raw) {
    try {
      return DateFormat(
        'EEEE, dd MMM yyyy',
        'id_ID',
      ).format(DateTime.parse(raw.split(' ').first));
    } catch (_) {
      return raw;
    }
  }

  List<String> get _availableYears {
    final years = <String>{};
    for (final log in _logs) {
      try {
        final parts = log['activity_date']
            .toString()
            .split(' ')
            .first
            .split('-');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          years.add(parts[0]);
        }
      } catch (_) {}
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return ['Semua', ...sorted];
  }

  int get _activeFilterCount =>
      (_filterMonth != 'Semua' ? 1 : 0) + (_filterYear != 'Semua' ? 1 : 0);

  int get _countThisMonth {
    final now = DateTime.now();
    final currentYear = now.year.toString();
    final currentMonth = now.month.toString().padLeft(2, '0');
    return _logs.where((log) {
      try {
        final parts = log['activity_date']
            .toString()
            .split(' ')
            .first
            .split('-');
        return parts.length >= 2 &&
            parts[0] == currentYear &&
            parts[1] == currentMonth;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _countToday {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _logs.where((log) {
      final raw = log['activity_date']?.toString().split(' ').first ?? '';
      return raw == todayStr;
    }).length;
  }

  void _applyFilter() {
    var data = _logs;
    if (_filterMonth != 'Semua') {
      data = data.where((log) {
        try {
          final p = log['activity_date'].toString().split(' ').first.split('-');
          return p.length >= 2 && p[1] == _filterMonth;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_filterYear != 'Semua') {
      data = data.where((log) {
        try {
          final p = log['activity_date'].toString().split(' ').first.split('-');
          return p.isNotEmpty && p[0] == _filterYear;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    _filteredLogs = data;
    _animController.forward(from: 0.0);
  }

  void _resetFilter() {
    setState(() {
      _filterMonth = 'Semua';
      _filterYear = 'Semua';
      _applyFilter();
    });
  }

  void _showDeleteDialog(BuildContext ctx, Map<String, dynamic> log) {
    bool isDeleting = false;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Hapus Log Aktivitas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Catatan aktivitas ini akan dihapus permanen dan tidak dapat dikembalikan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: isDeleting
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  setDialogState(() => isDeleting = true);
                                  final ok = await DatabaseService()
                                      .deleteActivityLog(log['id'] as int);
                                  if (!dialogCtx.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  if (!mounted) return;
                                  if (ok) {
                                    CustomSnackbar.success(
                                      context,
                                      'Log aktivitas berhasil dihapus.',
                                    );
                                    _loadLogs();
                                  } else {
                                    CustomSnackbar.error(
                                      context,
                                      'Gagal menghapus log.',
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.errorColor
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Hapus',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

  Widget _buildSliverAppBar(String userName) {
    return SliverAppBar(
      pinned: true,
      snap: false,
      floating: false,
      elevation: 0,
      expandedHeight: 132.0,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.timeline_rounded,
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
                    'Log Aktivitas',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Catatan pekerjaan dan aktivitas harian',
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
        background: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ExportMenuButton(
              onCsv: (ctx) => ExportService.exportActivityLogsCsv(
                ctx,
                _filteredLogs,
                userName,
              ),
              onPdf: (ctx) => ExportService.exportActivityLogsPdf(
                ctx,
                _filteredLogs,
                userName,
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
              title: 'Total Log',
              value: '${_logs.length}',
              subtitle: 'Seluruh catatan',
              icon: Icons.assignment_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              title: 'Bulan Ini',
              value: '$_countThisMonth',
              subtitle: 'Periode berjalan',
              icon: Icons.calendar_today_rounded,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              title: 'Hari Ini',
              value: '$_countToday',
              subtitle: 'Tercatat hari ini',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF0F766E),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: color.withValues(alpha: 0.1),
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
                  fontFeatures: const [FontFeature.tabularFigures()],
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
              fontSize: 11.5,
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

  Widget _buildCollapsibleFilter() {
    final activeCount = _activeFilterCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeCount > 0
              ? AppTheme.primaryColor.withValues(alpha: 0.45)
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
                      'Filter Periode',
                      style: TextStyle(
                        fontSize: 13.5,
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
                        onTap: _resetFilter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isFilterExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
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
            duration: const Duration(milliseconds: 240),
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
          padding: const EdgeInsets.all(14),
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

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Row(
        children: [
          const Text(
            'Daftar Catatan Aktivitas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_filteredLogs.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = _activeFilterCount > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                size: 36,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Tidak Ada Log Sesuai Filter'
                  : 'Belum Ada Log Aktivitas',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Coba ubah pilihan bulan atau tahun, atau reset filter.'
                  : 'Tekan tombol Tambah Log untuk mencatat pekerjaan harian Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resetFilter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text(
                  'Reset Filter',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final actDate = _formatActivityDate(log['activity_date']?.toString() ?? '');
    final createdAt = _formatCreatedAt(log['created_at']?.toString() ?? '');
    final content = log['log']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () =>
              Navigator.push(context, ActivityLogDetailScreen.route(log)),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: AppTheme.accentColor,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dicatat $createdAt',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showDeleteDialog(context, log),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Hapus log',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Catatan Harian',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
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

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = 130.0 + (safeBottom > 0 ? safeBottom : 16.0);
    final userName =
        DatabaseService().getCurrentUser()?['name']?.toString() ?? 'Karyawan';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(userName),
        ],
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          backgroundColor: Colors.white,
          onRefresh: _loadLogs,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildStatsOverview(),
                      _buildCollapsibleFilter(),
                      _buildListHeader(),
                    ],
                  ),
                ),
              ),
              _isLoading
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : _filteredLogs.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildEmptyState(),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildLogCard(_filteredLogs[index]),
                          childCount: _filteredLogs.length,
                        ),
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
          elevation: 4,
          onPressed: () =>
              AddActivityLogSheet.show(context, onSuccess: _loadLogs),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'Tambah Log',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
