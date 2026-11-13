import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/database_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _checkInTime = '--:--';
  String _checkOutTime = '--:--';
  bool _saving = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    final db = DatabaseService();
    final userId = db.getCurrentUser()?['id'] ?? 1;
    final data = await db.getTodayAttendance(userId);
    if (mounted) {
      setState(() {
        _checkInTime = data['checkIn']?.toString() ?? '--:--';
        _checkOutTime = data['checkOut']?.toString() ?? '--:--';
      });
    }
  }

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

  Future<void> _confirmAndSubmit(bool isDatang) async {
    if (_saving) return;
    HapticFeedback.mediumImpact();

    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

    // Desain Redesign Total: Layout terpusat dengan Hero Icon & Split Info Card
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Garis Handle Atas
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Hero Icon Bundar di Tengah
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (isDatang ? AppTheme.successColor : AppTheme.primaryColor)
                          .withValues(alpha: 0.1),
                ),
                child: Icon(
                  isDatang ? Icons.login_rounded : Icons.logout_rounded,
                  size: 30,
                  color: isDatang
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Judul & Subjudul Terpusat
              Text(
                isDatang ? 'Konfirmasi Kehadiran' : 'Konfirmasi Kepulangan',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isDatang
                    ? 'Anda akan mencatat waktu masuk kerja'
                    : 'Anda akan mengakhiri sesi kerja hari ini',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Info Waktu Presensi Model Modern Grid/Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waktu Tercatat Saat Ini',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Catatan kecil
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan data sudah benar. Presensi tidak dapat dibatalkan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Tombol Aksi Berjajar Luas
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: AppTheme.textSecondary,
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        minimumSize: const Size(0, 50),
                        backgroundColor: isDatang
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isDatang ? 'Kirim Datang' : 'Kirim Pulang',
                        style: const TextStyle(
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

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final db = DatabaseService();
    final userId = db.getCurrentUser()?['id'] ?? 1;
    final ok = await db.recordAttendance(
      userId: userId,
      type: isDatang ? 'CheckIn' : 'CheckOut',
      time: timeStr,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (isDatang) {
          _checkInTime = timeStr;
        } else {
          _checkOutTime = timeStr;
        }
      });
      CustomSnackbar.success(
        context,
        isDatang
            ? 'Presensi Datang pukul $timeStr berhasil'
            : 'Presensi Pulang pukul $timeStr berhasil',
      );
    } else {
      CustomSnackbar.error(context, 'Gagal menyimpan presensi. Coba lagi.');
    }
  }

  String get _dateId => DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_now);
  String get _hourMin => DateFormat('HH:mm', 'id_ID').format(_now);
  String get _sec => DateFormat('ss', 'id_ID').format(_now);
  bool get _checkedIn => _parseTimeToday(_checkInTime) != null;
  bool get _checkedOut => _parseTimeToday(_checkOutTime) != null;

  @override
  Widget build(BuildContext context) {
    final bool isComplete = _checkedIn && _checkedOut;
    final bool isDatangMode = !_checkedIn;

    String phaseBadge = 'SIAP ABSEN DATANG';
    Color phaseBadgeBg = AppTheme.accentColor;
    Color phaseBadgeText = AppTheme.primaryColor;

    if (_checkedIn && !_checkedOut) {
      phaseBadge = 'SHIFT AKTIF • SIAP ABSEN PULANG';
      phaseBadgeBg = const Color(0xFF10B981);
      phaseBadgeText = Colors.white;
    } else if (isComplete) {
      phaseBadge = 'PRESENSI HARI INI SELESAI';
      phaseBadgeBg = Colors.white.withValues(alpha: 0.16);
      phaseBadgeText = Colors.white;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadAttendanceData,
          child: CustomScrollView(
            slivers: [
              // 1. Header Hijau Korporat Solid
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 14,
                    20,
                    28,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Terminal Presensi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: phaseBadgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              phaseBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: phaseBadgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _hourMin,
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: 1.5,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _sec,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_dateId • WIB',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Konten Utama
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                  child: Column(
                    children: [
                      _AnimatedEntry(
                        delayMs: 60,
                        child: _CircularTapAttendanceButton(
                          isComplete: isComplete,
                          isDatangMode: isDatangMode,
                          isSaving: _saving,
                          onTap: () => _confirmAndSubmit(isDatangMode),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _AnimatedEntry(
                        delayMs: 150,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD0D9E4)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _compactLogItem(
                                  icon: Icons.login_rounded,
                                  label: 'Jam Datang',
                                  time: _formatShortTime(_checkInTime),
                                  active: _checkedIn,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: const Color(0xFFE2E8F0),
                              ),
                              Expanded(
                                child: _compactLogItem(
                                  icon: Icons.logout_rounded,
                                  label: 'Jam Pulang',
                                  time: _formatShortTime(_checkOutTime),
                                  active: _checkedOut,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AnimatedEntry(
                        delayMs: 220,
                        child: Text(
                          isComplete
                              ? 'Terima kasih, seluruh catatan presensi hari ini sudah tersimpan.'
                              : (isDatangMode
                                    ? 'Ketuk tombol lingkaran di atas untuk mencatat kehadiran datang.'
                                    : 'Ketuk tombol lingkaran di atas saat jam kerja berakhir.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
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

  Widget _compactLogItem({
    required IconData icon,
    required String label,
    required String time,
    required bool active,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.12)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? color : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CircularTapAttendanceButton extends StatefulWidget {
  final bool isComplete;
  final bool isDatangMode;
  final bool isSaving;
  final VoidCallback onTap;

  const _CircularTapAttendanceButton({
    required this.isComplete,
    required this.isDatangMode,
    required this.isSaving,
    required this.onTap,
  });

  @override
  State<_CircularTapAttendanceButton> createState() =>
      _CircularTapAttendanceButtonState();
}

class _CircularTapAttendanceButtonState
    extends State<_CircularTapAttendanceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = !widget.isComplete && !widget.isSaving;

    final Color coreColor = widget.isComplete
        ? const Color(0xFF64748B)
        : (widget.isDatangMode ? AppTheme.successColor : AppTheme.primaryColor);

    final Color ringBorderColor = widget.isComplete
        ? const Color(0xFFCBD5E1)
        : (widget.isDatangMode ? AppTheme.successColor : AppTheme.accentColor);

    final IconData iconData = widget.isComplete
        ? Icons.verified_rounded
        : (widget.isDatangMode
              ? Icons.touch_app_rounded
              : Icons.logout_rounded);

    final String mainLabel = widget.isComplete
        ? 'SELESAI'
        : (widget.isDatangMode ? 'DATANG' : 'PULANG');

    final String subLabel = widget.isComplete
        ? 'Tercatat Lengkap'
        : (widget.isDatangMode ? 'Tap Masuk Kerja' : 'Tap Pulang Kerja');

    return SizedBox(
      width: 224,
      height: 224,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (enabled)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final t = _pulseController.value;
                return Transform.scale(
                  scale: 0.86 + (t * 0.24),
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: coreColor.withValues(alpha: (1.0 - t) * 0.45),
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: ringBorderColor.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: coreColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled
                ? (_) {
                    setState(() => _pressed = false);
                    widget.onTap();
                  }
                : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            child: AnimatedScale(
              scale: _pressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: coreColor,
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(
                      alpha: widget.isComplete ? 0.0 : 0.55,
                    ),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isSaving)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(iconData, size: 38, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      mainLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
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
