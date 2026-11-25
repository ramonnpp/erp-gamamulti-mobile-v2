import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/admin_database_service.dart';
import '../../theme/app_theme.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, int> _todaySummary = {};
  List _activeAnnouncements = [];

  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DatabaseService().refreshCurrentUser();
    }
  }

  Future<void> _loadData() async {
    try {
      final db = AdminDatabaseService();
      final summary = await db.getTodayDashboardSummary();
      final announcements = await db.getActiveAnnouncements();
      setState(() {
        _todaySummary = summary;
        _activeAnnouncements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error load admin home data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant AdminHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget != widget) {
      _loadData();
    }
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  // --- Dashboard Summary Card ---
  Widget _summaryCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final attendanceCount = _todaySummary['attendance'] ?? 0;
    final leaveCount = _todaySummary['leaves'] ?? 0;
    final activityCount = _todaySummary['activity'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Aktivitas Hari Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricCard('Presensi', attendanceCount, Colors.green),
              const SizedBox(width: 16),
              _metricCard('Izin/Sakit', leaveCount, Colors.blue),
              const SizedBox(width: 16),
              _metricCard('Log Aktivitas', activityCount, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Active Announcements Card ---
  Widget _announcementsCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengumuman Aktif',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_activeAnnouncements.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9E7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF7DC6F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.campaign_outlined, color: Color(0xFFB7791F), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tidak ada pengumuman aktif.',
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
          else
            Column(
              children: _activeAnnouncements.map((a) {
                final title = a['title'] as String? ?? '';
                final content = a['content'] as String? ?? '';
                final publishedAt = a['published_at'] as String?;
                return ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    content.length > 50 ? '${content.substring(0, 50)}...' : content,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: publishedAt != null
                      ? Text(
                          DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(publishedAt)),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        )
                      : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = DatabaseService().getCurrentUser();
    final userName = user?['name'] ?? 'Admin';
    final userRole = user?['role'] ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Header dengan animasi melengkung
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: user?['profile_image_data'] != null
                            ? MemoryImage(user!['profile_image_data'] as Uint8List)
                            : null,
                        child: user?['profile_image_data'] == null
                            ? Text(
                                (userName.isNotEmpty ? userName[0].toUpperCase() : 'A'),
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
                          Text(
                            'Selamat ${_greeting}, $userName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          Text(
                            'Role: $userRole',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Selamat ${_greeting}, $userName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Role: $userRole',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- KONTEN UTAMA ---
          Expanded(
            child: Container(
              color: const Color(0xFFE4EAF1),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    _AnimatedDashboardBlock(delayMs: 50, child: _summaryCard()),
                    const SizedBox(height: 16),
                    _AnimatedDashboardBlock(delayMs: 140, child: _announcementsCard()),
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

// Helper widget for dashboard summary cards
class _AnimatedDashboardBlock extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedDashboardBlock({required this.delayMs, required this.child});

  @override
  State<_AnimatedDashboardBlock> createState() => _AnimatedDashboardBlockState();
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