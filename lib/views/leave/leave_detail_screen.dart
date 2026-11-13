import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class LeaveDetailScreen extends StatelessWidget {
  final Map<String, dynamic> leave;
  const LeaveDetailScreen({super.key, required this.leave});

  // Transisi halaman custom yang mulus (Slide + Fade)
  static Route<void> route(Map<String, dynamic> leaveData) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          LeaveDetailScreen(leave: leaveData),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.08);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  String _formatDateId(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final d = DateTime.parse(raw.split(' ')[0]);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(d);
    } catch (_) {
      return raw;
    }
  }

  int _durationDays() {
    try {
      final s = DateTime.parse(leave['start_date'].toString().split(' ')[0]);
      final e = DateTime.parse(leave['end_date'].toString().split(' ')[0]);
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  String _statusText() {
    final now = DateTime.now();
    try {
      final s = DateTime.parse(leave['start_date'].toString().split(' ')[0]);
      final e = DateTime.parse(leave['end_date'].toString().split(' ')[0]);
      if (now.isBefore(s)) return 'Akan Datang';
      if (now.isAfter(e)) return 'Selesai';
      return 'Sedang Berlangsung';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _durationDays();
    final status = _statusText();
    final leaveType = leave['leave_type']?.toString() ?? 'Cuti';
    final reasonText = leave['reason']?.toString();

    // Variasi warna badge status yang bervariasi (Tidak monoton putih/hitam)
    Color statusBg;
    Color statusFg;
    if (status == 'Sedang Berlangsung') {
      statusBg = const Color(0xFFDCFCE7); // Hijau soft
      statusFg = const Color(0xFF15803D); // Hijau tua
    } else if (status == 'Akan Datang') {
      statusBg = const Color(0xFFEEF2FF); // Indigo/Biru pastel sangat soft
      statusFg = const Color(0xFF4338CA); // Indigo elegan
    } else {
      statusBg = const Color(0xFFF1F5F9); // Slate soft
      statusFg = const Color(0xFF475569); // Slate gelap
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // HEADER UTAMA: Solid Primary Green dengan Tombol Kembali Estetik
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              24,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  leaveType,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Total Durasi: $days Hari Kerja',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(
                          0xFFCBD5E1,
                        ), // Warna teks abu-abu terang bervariasi
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // KONTEN UTAMA DI BAWAH HEADER
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'WAKTU PELAKSANAAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // PANEL WAKTU DENGAN HIERARKI WARNA TEKS BERVARIASI
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildScheduleRow(
                        icon: Icons.flight_takeoff_rounded,
                        label: 'Mulai Cuti',
                        date: _formatDateId(leave['start_date']?.toString()),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Color(0xFFF1F5F9), height: 1),
                      ),
                      _buildScheduleRow(
                        icon: Icons.flight_land_rounded,
                        label: 'Selesai Cuti',
                        date: _formatDateId(leave['end_date']?.toString()),
                      ),
                      if (leave['created_at'] != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: Color(0xFFF1F5F9), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Diajukan Pada',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ), // Abu-abu lembut
                            ),
                            Text(
                              _formatDateId(leave['created_at']?.toString()),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(
                                  0xFF0F172A,
                                ), // Slate gelap berkarakter
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'CATATAN / ALASAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // PANEL ALASAN
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    (reasonText != null && reasonText.isNotEmpty)
                        ? reasonText
                        : 'Tidak ada catatan atau alasan tambahan yang disertakan.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(
                        0xFF475569,
                      ), // Warna slate medium yang nyaman dibaca (tidak hitam legam)
                      height: 1.6,
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

  Widget _buildScheduleRow({
    required IconData icon,
    required String label,
    required String date,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B), // Warna label abu-abu slate
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(
                    0xFF1E293B,
                  ), // Warna teks tanggal hitam kebiruan yang elegan
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
