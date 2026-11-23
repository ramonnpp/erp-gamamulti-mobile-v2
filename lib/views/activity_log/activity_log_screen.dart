import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import 'add_activity_log_sheet.dart';
import 'activity_log_detail_sheet.dart';
import '../../widgets/custom_snackbar.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  bool _isFilterExpanded = false;
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

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseService().getActivityLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _applyFilter();
      _isLoading = false;
    });
  }

  String _formatCreatedAt(String raw) {
    try {
      return DateFormat(
        'dd MMM yyyy, HH:mm',
        'id_ID',
      ).format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatActivityDate(String raw) {
    try {
      return DateFormat(
        'dd MMMM yyyy',
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
        final parts = log['activity_date'].toString().split('-');
        if (parts.isNotEmpty) years.add(parts[0]);
      } catch (_) {}
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return ['Semua', ...sorted];
  }

  void _applyFilter() {
    var data = _logs;
    if (_filterMonth != 'Semua') {
      data = data.where((log) {
        try {
          final p = log['activity_date'].toString().split('-');
          return p.length >= 2 && p[1] == _filterMonth;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_filterYear != 'Semua') {
      data = data.where((log) {
        try {
          final p = log['activity_date'].toString().split('-');
          return p.isNotEmpty && p[0] == _filterYear;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    _filteredLogs = data;
  }

  // ── Filter Widget (inline) ────────────────────────────────────────────────
  Widget _buildFilterWidget() {
    if (!_isFilterExpanded) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filter Berdasarkan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _filterMonth = 'Semua';
                  _filterYear = 'Semua';
                  _applyFilter();
                }),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5),
          const SizedBox(height: 8),
          const Text(
            'Bulan',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _months.map((m) {
              final s = _filterMonth == m['value'];
              return ChoiceChip(
                label: Text(m['label']!),
                selected: s,
                onSelected: (_) => setState(() {
                  _filterMonth = m['value']!;
                  _applyFilter();
                }),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: s ? Colors.white : AppTheme.textSecondary,
                  fontWeight: s ? FontWeight.w700 : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tahun',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableYears.map((y) {
              final s = _filterYear == y;
              return ChoiceChip(
                label: Text(y),
                selected: s,
                onSelected: (_) => setState(() {
                  _filterYear = y;
                  _applyFilter();
                }),
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: s ? Colors.white : AppTheme.textSecondary,
                  fontWeight: s ? FontWeight.w700 : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Card Widget (inline) ──────────────────────────────────────────────────
  Widget _buildLogCard(
    Map<String, dynamic> log,
    String actDate,
    String createdAt,
  ) {
    return InkWell(
      onTap: () => ActivityLogDetailSheet.show(
        context,
        log: log,
        formattedActivityDate: actDate,
        formattedCreatedAt: createdAt,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentColor.withValues(alpha: 0.2),
                          AppTheme.accentColor.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.note_alt_rounded,
                      size: 20,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      actDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                log['log']?.toString() ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showDeleteDialog(context, log),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Lihat Detail',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext ctx, Map<String, dynamic> log) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Log Aktivitas?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Log yang dihapus tidak dapat dikembalikan.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await DatabaseService().deleteActivityLog(log['id'] as int);
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              if (ok) {
                CustomSnackbar.success(context, 'Log berhasil dihapus.');
                _loadLogs();
              } else {
                CustomSnackbar.error(context, 'Gagal menghapus log.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 74.0 + (safeBottom > 0 ? safeBottom : 16.0);
    final bottomPad = 16.0 + navBarHeight + 16.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Log Aktivitas'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isFilterExpanded
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterWidget(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.note_outlined,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Belum Ada Log Aktivitas',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Mulai catat kegiatan harianmu!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (ctx, i) {
                      final log = _filteredLogs[i];
                      final actDate = _formatActivityDate(
                        log['activity_date']?.toString() ?? '',
                      );
                      final createdAt = _formatCreatedAt(
                        log['created_at']?.toString() ?? '',
                      );
                      return _buildLogCard(log, actDate, createdAt);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: navBarHeight),
        child: FloatingActionButton.extended(
          onPressed: () =>
              AddActivityLogSheet.show(context, onSuccess: _loadLogs),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          label: const Text('Tambah Log'),
          icon: const Icon(Icons.edit_rounded),
        ),
      ),
    );
  }
}
