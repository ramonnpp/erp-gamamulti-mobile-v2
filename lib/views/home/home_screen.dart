import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _checkInTime = '--:--';
  String _checkOutTime = '--:--';
  bool _isLoading = true;
  List _sickToday = [];
  List _leaveToday = [];
  List _announcements = [];

  String _infoFilter = 'Semua';
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
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
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseService();
    final currentUser = db.getCurrentUser();
    final userId = currentUser?['id'] ?? 1;
    final data = await db.getTodayAttendance(userId);
    final info = await db.getTodayLeaveInfo();
    final ann = await db.getAnnouncements();

    if (!mounted) return;
    setState(() {
      _checkInTime = data['checkIn']?.toString() ?? '--:--';
      _checkOutTime = data['checkOut']?.toString() ?? '--:--';
      _sickToday = (info['sick'] as List?) ?? [];
      _leaveToday = (info['leave'] as List?) ?? [];
      _announcements = ann;
      _isLoading = false;
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

  DateTime? _parseTimeToday(String raw) {
    final cleaned = raw
        .toUpperCase()
        .replaceAll('WIB', '')
        .replaceAll('WITA', '')
        .replaceAll('WIT', '')
        .replaceAll('.', ':')
        .trim();

    if (cleaned.isEmpty || cleaned == '--:--' || !cleaned.contains(':')) {
      return null;
    }

    final parts = cleaned.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    final second = parts.length >= 3 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;

    if (hour == null || minute == null) return null;
    return DateTime(_now.year, _now.month, _now.day, hour, minute, second);
  }

  String _formatShortTime(String raw) {
    final dt = _parseTimeToday(raw);
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt);
  }

  void _showAnnouncementDetail(String title, String content, String? date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (date != null && date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '$title\n\n$content'),
                          );
                          Navigator.pop(ctx);
                          CustomSnackbar.success(
                            context,
                            'Teks pengumuman berhasil disalin',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          side: const BorderSide(color: AppTheme.primaryColor),
                          foregroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text(
                          'Salin',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                        ),
                        child: const Text('Tutup'),
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = DatabaseService().getCurrentUser();
    final String userName = currentUser?['name'] ?? 'Karyawan';
    final String userRole = currentUser?['role'] ?? 'Staff';
    final String? profileImgPath = currentUser?['profile_image']?.toString();
    final Uint8List? profileImgBytes =
        currentUser?['profile_image_data'] as Uint8List?;
    final File? profileFile =
        (profileImgPath != null &&
            profileImgPath.isNotEmpty &&
            File(profileImgPath).existsSync())
        ? File(profileImgPath)
        : null;

    final String initial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'K';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFE4EAF1),
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // 1. Header Hijau Original (Tanpa Kotak-Kotak Grid)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: AppTheme.primaryColor,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 14,
                    20,
                    22,
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
                              backgroundImage: profileFile != null
                                  ? FileImage(profileFile)
                                  : (profileImgBytes != null
                                        ? MemoryImage(profileImgBytes)
                                        : null),
                              child:
                                  (profileFile == null &&
                                      profileImgBytes == null)
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
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
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
              ),

              // 2. Konten Utama
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedDashboardBlock(
                        delayMs: 50,
                        child: _featuredAttendanceCard(),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 140,
                        child: _todayInfoCard(),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 230,
                        child: _announcementCard(),
                      ),
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

  Widget _featuredAttendanceCard() {
    final checkInDt = _parseTimeToday(_checkInTime);
    final checkOutDt = _parseTimeToday(_checkOutTime);

    final bool hasCheckedIn = checkInDt != null;
    final bool hasCheckedOut = checkOutDt != null;
    final bool isActivelyWorking = hasCheckedIn && !hasCheckedOut;

    Duration workedDuration = Duration.zero;
    if (hasCheckedIn) {
      final endPoint = hasCheckedOut ? checkOutDt : _now;
      if (endPoint.isAfter(checkInDt)) {
        workedDuration = endPoint.difference(checkInDt);
      }
    }

    const targetDuration = Duration(hours: 8);
    final double progressRatio = hasCheckedIn
        ? (workedDuration.inSeconds / targetDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    final int h = workedDuration.inHours;
    final int m = workedDuration.inMinutes.remainder(60);
    final int s = workedDuration.inSeconds.remainder(60);

    final bool isOvertime = workedDuration > targetDuration;
    final Duration overtimeDuration = isOvertime
        ? workedDuration - targetDuration
        : Duration.zero;

    String statusText = 'Belum Absen';
    if (isActivelyWorking) {
      statusText = isOvertime ? 'Lembur Berjalan' : 'Sedang Bekerja';
    } else if (hasCheckedIn && hasCheckedOut) {
      statusText = 'Selesai';
    }

    final bool isLate =
        hasCheckedIn &&
        (checkInDt.hour > 8 || (checkInDt.hour == 8 && checkInDt.minute > 0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E5535),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Status Presensi Hari Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActivelyWorking) ...[
                      const _LivePulseDot(color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasCheckedIn
                    ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                    : '00:00:00',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ 08:00:00',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progressRatio),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasCheckedIn
                    ? 'Estimasi pulang ${DateFormat('HH:mm').format(checkInDt.add(targetDuration))} WIB'
                    : 'Jam kerja standar 08:00 - 17:00 WIB',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (isOvertime)
                Text(
                  '+${overtimeDuration.inHours}j ${overtimeDuration.inMinutes.remainder(60)}m lembur',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor,
                  ),
                )
              else
                Text(
                  '${(progressRatio * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _darkGlassTile(
                  icon: Icons.login_rounded,
                  label: 'Jam Datang',
                  time: _isLoading ? '--:--' : _formatShortTime(_checkInTime),
                  note: hasCheckedIn
                      ? (isLate ? 'Terlambat' : 'Tepat Waktu')
                      : 'Belum Absen',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _darkGlassTile(
                  icon: Icons.logout_rounded,
                  label: 'Jam Pulang',
                  time: _isLoading ? '--:--' : _formatShortTime(_checkOutTime),
                  note: hasCheckedOut ? 'Tercatat' : 'Belum Absen',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkGlassTile({
    required IconData icon,
    required String label,
    required String time,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
        ],
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
                      final date =
                          a['date']?.toString() ?? a['created_at']?.toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PressScaleTile(
                          onTap: () =>
                              _showAnnouncementDetail(title, content, date),
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
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

class _LivePulseDot extends StatefulWidget {
  final Color color;
  const _LivePulseDot({required this.color});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
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
