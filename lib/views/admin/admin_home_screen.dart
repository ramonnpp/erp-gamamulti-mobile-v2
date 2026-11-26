import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/admin_database_service.dart';
import '../../announcements/announce-detail-screen.dart';
import '../../widgets/custom_snackbar.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with WidgetsBindingObserver {
  List _sickToday = [];
  List _leaveToday = [];
  List _announcements = [];
  List<Map<String, dynamic>> _weekly = [];
  List<Map<String, dynamic>> _auditLogs = [];

  String _infoFilter = 'Semua';
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DatabaseService().profileImageVersion.addListener(_onProfileChanged);
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DatabaseService().profileImageVersion.removeListener(_onProfileChanged);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  // Saat app kembali dari background, ambil foto/nama terbaru dari database
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DatabaseService().refreshCurrentUser();
    }
  }

  Future<void> _loadData() async {
    final db = DatabaseService();
    final profileRefresh = db.refreshCurrentUser(); // sinkron foto & nama
    final info = await db.getTodayLeaveInfo();
    final ann = await db.getActiveAnnouncements();

    List<Map<String, dynamic>> weekly = [];
    List<Map<String, dynamic>> logs = [];
    try {
      final adminDb = AdminDatabaseService();
      weekly = await adminDb.getAttendanceLast7Days();
      logs = await adminDb.getRecentAuditLogs(limit: 5);
    } catch (e) {
      debugPrint('Error load data admin: $e');
    }
    await profileRefresh;

    if (!mounted) return;
    setState(() {
      _sickToday = (info['sick'] as List?) ?? [];
      _leaveToday = (info['leave'] as List?) ?? [];
      _announcements = ann;
      _weekly = weekly;
      _auditLogs = logs;
    });
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String get _todayId => DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_now);

  void _openAnnouncementDetail(Map<String, dynamic> announcement) {
    Navigator.push(context, AnnounceDetailScreen.route(announcement));
  }

  // ---------- Kartu umum (header abu-abu + garis aksen, sama seperti Home) ----------
  Widget _cardShell({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFDCE3EC))),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ---------- Grafik kehadiran 7 hari terakhir ----------
  static const Color _lateColor = Color(0xFFEA580C);

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _attendanceChartCard() {
    const double maxBarHeight = 110;
    int maxVal = 1;
    for (final d in _weekly) {
      final v = (d['present'] as int?) ?? 0;
      if (v > maxVal) maxVal = v;
    }
    final today = DateTime(_now.year, _now.month, _now.day);

    return _cardShell(
      title: 'Kehadiran 7 Hari Terakhir',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendDot(AppTheme.primaryColor, 'Tepat'),
          const SizedBox(width: 10),
          _legendDot(_lateColor, 'Terlambat'),
        ],
      ),
      child: _weekly.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Data kehadiran belum tersedia.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_weekly.length, (i) {
                final d = _weekly[i];
                final present = (d['present'] as int?) ?? 0;
                final late = (d['late'] as int?) ?? 0;
                final parsed = DateTime.tryParse(d['date']?.toString() ?? '');
                final date = parsed == null
                    ? null
                    : DateTime(parsed.year, parsed.month, parsed.day);
                final isToday = date != null && date == today;
                final label = date == null
                    ? '-'
                    : DateFormat('E', 'id_ID').format(date);

                final ratio = present / maxVal;
                final totalH = present == 0 ? 3.0 : (maxBarHeight * ratio).clamp(8.0, maxBarHeight);
                final lateH = present == 0 ? 0.0 : totalH * (late / present);
                final onTimeH = totalH - lateH;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$present',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isToday
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Batang tumbuh dari bawah, tiap hari sedikit lebih lambat
                      TweenAnimationBuilder<double>(
                        key: ValueKey('bar_${d['date']}_${present}_$late'),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 500 + i * 70),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                            child: SizedBox(
                              width: 22,
                              height: totalH * v,
                              child: present == 0
                                  ? const ColoredBox(color: Color(0xFFCBD5E1))
                                  : Column(
                                      children: [
                                        if (late > 0)
                                          Expanded(
                                            flex: (lateH * 100).round().clamp(1, 1000000),
                                            child: const ColoredBox(
                                              color: _lateColor,
                                              child: SizedBox.expand(),
                                            ),
                                          ),
                                        Expanded(
                                          flex: (onTimeH * 100).round().clamp(1, 1000000),
                                          child: ColoredBox(
                                            color: isToday
                                                ? AppTheme.primaryColor
                                                : AppTheme.primaryColor.withValues(alpha: 0.78),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.accentColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isToday
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  // ---------- Aktivitas admin terbaru ----------
  ({String label, IconData icon, Color color}) _auditMeta(String action) {
    switch (action) {
      case 'UPDATE_ATTENDANCE':
        return (
          label: 'Mengubah presensi',
          icon: Icons.edit_calendar_rounded,
          color: const Color(0xFFEA580C),
        );
      case 'DELETE_ATTENDANCE':
        return (
          label: 'Menghapus presensi',
          icon: Icons.event_busy_rounded,
          color: const Color(0xFFDC2626),
        );
      case 'DELETE_LEAVE_REQUEST':
        return (
          label: 'Menghapus pengajuan cuti',
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFDC2626),
        );
      case 'DELETE_ACTIVITY_LOG':
        return (
          label: 'Menghapus log aktivitas',
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFDC2626),
        );
      case 'CREATE_ANNOUNCEMENT':
        return (
          label: 'Membuat pengumuman',
          icon: Icons.campaign_rounded,
          color: const Color(0xFF15803D),
        );
      case 'UPDATE_ANNOUNCEMENT':
        return (
          label: 'Mengubah pengumuman',
          icon: Icons.edit_rounded,
          color: const Color(0xFFEA580C),
        );
      case 'DELETE_ANNOUNCEMENT':
        return (
          label: 'Menghapus pengumuman',
          icon: Icons.delete_forever_rounded,
          color: const Color(0xFFDC2626),
        );
      default:
        return (
          label: action.replaceAll('_', ' ').toLowerCase(),
          icon: Icons.history_rounded,
          color: AppTheme.textSecondary,
        );
    }
  }

  String _ago(int? seconds, String? created) {
    if (seconds == null) return '';
    if (seconds < 60) return 'Baru saja';
    if (seconds < 3600) return '${seconds ~/ 60} mnt lalu';
    if (seconds < 86400) return '${seconds ~/ 3600} jam lalu';
    if (seconds < 7 * 86400) return '${seconds ~/ 86400} hari lalu';
    final d = DateTime.tryParse((created ?? '').replaceFirst(' ', 'T'));
    return d == null ? '' : DateFormat('dd MMM yyyy', 'id_ID').format(d);
  }

  Widget _auditRow(Map<String, dynamic> log) {
    final meta = _auditMeta(log['action']?.toString() ?? '');
    final details = log['details'] as Map<String, dynamic>?;
    final extra = details?['title']?.toString();
    final admin = log['admin_name']?.toString() ?? 'Admin';
    final subtitle = (extra != null && extra.isNotEmpty)
        ? '$admin • $extra'
        : admin;
    final ago = _ago(log['age_seconds'] as int?, log['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, size: 18, color: meta.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ago,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _auditCard() {
    return _cardShell(
      title: 'Aktivitas Admin Terbaru',
      child: _auditLogs.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9E7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF7DC6F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_rounded, color: Color(0xFFB7791F), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada aktivitas admin.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF975A16),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(children: _auditLogs.map(_auditRow).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = DatabaseService().getCurrentUser();
    final String userName = currentUser?['name'] ?? 'Admin';
    final String userRole = currentUser?['role'] ?? 'Admin';
    // Foto selalu dari database (bytes), sama persis di semua device
    final Uint8List? profileImgBytes =
        currentUser?['profile_image_data'] as Uint8List?;

    final String initial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'A';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Column(
          children: [
            // --- HEADER HIJAU UTAMA (Warnai Status Bar sampai Atas) ---
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 10,
                20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentColor,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          backgroundImage: profileImgBytes != null
                              ? MemoryImage(profileImgBytes)
                              : null,
                          child: profileImgBytes == null
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _greeting,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => CustomSnackbar.info(
                          context,
                          'Tidak ada notifikasi baru',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Tanggal & Jam Real-time
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13.5,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _todayId,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${DateFormat('HH:mm:ss', 'id_ID').format(_now)} WIB',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- KONTEN BAWAH YANG BISA DI-SCROLL ---
            Expanded(
              child: Container(
                color: const Color(0xFFE4EAF1),
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    // PADDING BAWAH 130: Mencegah tertutup navbar melayang
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                    children: [
                      _AnimatedDashboardBlock(
                        delayMs: 50,
                        child: _todayInfoCard(),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 140,
                        child: _attendanceChartCard(),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 230,
                        child: _announcementCard(),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 320,
                        child: _auditCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayInfoCard() {
    final total = _sickToday.length + _leaveToday.length;
    final showSick = _infoFilter == 'Semua' || _infoFilter == 'Sakit';
    final showLeave = _infoFilter == 'Semua' || _infoFilter == 'Cuti';

    final bool isFilteredEmpty =
        (_infoFilter == 'Sakit' && _sickToday.isEmpty) ||
        (_infoFilter == 'Cuti' && _leaveToday.isEmpty) ||
        (_infoFilter == 'Semua' && total == 0);

    final List<Widget> rows = [];
    if (showSick) {
      for (final item in _sickToday) {
        rows.add(_boxedPersonRow(item, AppTheme.errorColor, 'Izin/Sakit'));
      }
    }
    if (showLeave) {
      for (final item in _leaveToday) {
        rows.add(_boxedPersonRow(item, const Color(0xFF0284C7), 'Cuti'));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFDCE3EC))),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Info Hari Ini',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total Tidak Hadir',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _filterPill('Semua', total),
                    const SizedBox(width: 8),
                    _filterPill('Sakit', _sickToday.length),
                    const SizedBox(width: 8),
                    _filterPill('Cuti', _leaveToday.length),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isFilteredEmpty
                        ? Container(
                            key: ValueKey('empty_$_infoFilter'),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.successColor,
                                  size: 19,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    total == 0
                                        ? 'Seluruh karyawan hadir bekerja hari ini.'
                                        : 'Tidak ada data kategori $_infoFilter hari ini.',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            key: ValueKey('list_$_infoFilter'),
                            children: rows,
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

  Widget _filterPill(String label, int count) {
    final bool active = _infoFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _infoFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppTheme.primaryColor : const Color(0xFFD5DDE7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? AppTheme.accentColor : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boxedPersonRow(dynamic item, Color color, String fallbackTag) {
    final e = item is Map ? item : {};
    final name = e['name']?.toString() ?? '-';
    final type = e['type']?.toString() ?? fallbackTag;
    final reason = e['reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFDCE3EC))),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Pengumuman Perusahaan',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _announcements.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF7DC6F)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          color: Color(0xFFB7791F),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tidak ada pengumuman.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF975A16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _announcements.map((item) {
                      final a = item is Map ? item : {};
                      final title =
                          a['title']?.toString() ?? 'Pengumuman Perusahaan';
                      final content = a['content']?.toString() ?? '';
                      final category = a['category']?.toString() ?? 'Umum';
                      final hasAttachment =
                          (a['attachment_name']?.toString() ?? '').isNotEmpty;
                      final catColor = category == 'Urgent'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFEA580C);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PressScaleTile(
                          onTap: () => _openAnnouncementDetail(
                            Map<String, dynamic>.from(a),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (category != 'Umum') ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: catColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: catColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                color: AppTheme.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        content,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasAttachment)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.attach_file_rounded,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDashboardBlock extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedDashboardBlock({required this.delayMs, required this.child});

  @override
  State<_AnimatedDashboardBlock> createState() =>
      _AnimatedDashboardBlockState();
}

class _AnimatedDashboardBlockState extends State<_AnimatedDashboardBlock> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.045),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _PressScaleTile extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressScaleTile({required this.onTap, required this.child});

  @override
  State<_PressScaleTile> createState() => _PressScaleTileState();
}

class _PressScaleTileState extends State<_PressScaleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
