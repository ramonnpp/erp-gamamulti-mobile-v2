import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/attendance_history_screen.dart';
import '../leave/leave_history_screen.dart';
import '../leave/sick_leave_history_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _goTo(0);
      return false;
    }

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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  size: 30,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Keluar Aplikasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Apakah Anda yakin ingin keluar dari aplikasi?',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ya, Keluar',
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
    return confirmed ?? false;
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();

    _fadeController.reverse().then((_) {
      setState(() {
        _currentIndex = index;
      });
      _fadeController.forward();
    });
  }

  // Daftar Screen (6 Menu Utama)
  final List<Widget> _screens = [
    const HomeScreen(), // 0. Home
    const AttendanceScreen(), // 1. Presensi
    const SickLeaveHistoryScreen(), // 2. Izin/Sakit
    const LeaveHistoryScreen(), // 3. Permohonan Cuti
    const AttendanceHistoryScreen(), // 4. History
    const ProfileScreen(), // 5. Profil
  ];

  // Daftar Menu & Ikon
  final List<_NavItem> _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.location_on_outlined, Icons.location_on_rounded, 'Presensi'),
    _NavItem(Icons.copy_all_outlined, Icons.copy_all_rounded, 'Izin/Sakit'),
    _NavItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Cuti',
    ),
    _NavItem(Icons.description_outlined, Icons.description_rounded, 'History'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomPadding > 0 ? bottomPadding + 6 : 16,
          ),
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // Menggunakan Row dengan spaceAround agar pas di tengah dan terbagi rata di semua layar HP
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = index == _currentIndex;

                return GestureDetector(
                  onTap: () => _goTo(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        // Indikator titik/lengkung kecil di bawah ikon yang aktif (seperti di referensi gambar)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: selected ? 5 : 0,
                          height: selected ? 5 : 0,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}
