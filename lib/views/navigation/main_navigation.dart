import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../home/home_screen.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/attendance_history_screen.dart';
import '../leave/leave_history_screen.dart';
import '../leave/sick_leave_history_screen.dart';
import '../activity_log/activity_log_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_home_screen.dart';
import '../admin/admin_attendance_screen.dart';
import '../admin/admin_leave_screen.dart';
import '../admin/admin_activity_log_screen.dart';
import '../admin/admin_announcement_screen.dart';

enum _NavKind { screen, attendanceGroup, leaveGroup }

enum _PopupGroup { none, attendance, leave }

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  _PopupGroup _activePopup = _PopupGroup.none;
  double? _popupAnchorCenterX;

  final GlobalKey _attendanceTabKey = GlobalKey();
  final GlobalKey _leaveTabKey = GlobalKey();

  late Widget _activeScreen;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _popupController;
  late Animation<double> _popupScale;
  late Animation<double> _popupOpacity;
  late Animation<Offset> _popupSlide;

  bool _isAdmin = false;

  List<_NavItem> get _items {
    if (_isAdmin) {
      return const [
        _NavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Home',
          kind: _NavKind.screen,
          screenIndex: 0,
        ),
        _NavItem(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          label: 'Presensi',
          kind: _NavKind.screen,
          screenIndex: 1,
        ),
        _NavItem(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
          label: 'Izin',
          kind: _NavKind.screen,
          screenIndex: 2,
        ),
        _NavItem(
          icon: Icons.timeline_outlined,
          selectedIcon: Icons.timeline_rounded,
          label: 'Log Activity',
          kind: _NavKind.screen,
          screenIndex: 3,
        ),
        _NavItem(
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign_rounded,
          label: 'Pengumuman',
          kind: _NavKind.screen,
          screenIndex: 4,
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profil',
          kind: _NavKind.screen,
          screenIndex: 5,
        ),
      ];
    }
    return const [
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
        kind: _NavKind.screen,
        screenIndex: 0,
      ),
      _NavItem(
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on_rounded,
        label: 'Presensi',
        kind: _NavKind.attendanceGroup,
      ),
      _NavItem(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        label: 'Izin',
        kind: _NavKind.leaveGroup,
      ),
      _NavItem(
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        label: 'Log Activity',
        kind: _NavKind.screen,
        screenIndex: 3,
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Profile',
        kind: _NavKind.screen,
        screenIndex: 4,
      ),
    ];
  }

  Widget _getScreenForIndex(int index) {
    if (_isAdmin) {
      switch (index) {
        case 0:
          return const AdminHomeScreen();
        case 1:
          return const AdminAttendanceScreen();
        case 2:
          return const AdminLeaveScreen();
        case 3:
          return const AdminActivityLogScreen();
        case 4:
          return const AdminAnnouncementScreen();
        case 5:
          return const ProfileScreen();
        default:
          return const AdminHomeScreen();
      }
    } else {
      switch (index) {
        case 0:
          return const HomeScreen();
        case 1:
          return const AttendanceScreen();
        case 2:
          return const SickLeaveHistoryScreen();
        case 3:
          return const ActivityLogScreen();
        case 4:
          return const ProfileScreen();
        default:
          return const HomeScreen();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final user = DatabaseService().getCurrentUser();
    _isAdmin = user?['role']?.toString().toLowerCase() == 'admin';
    _activeScreen = _getScreenForIndex(0);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final curvedIn = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _popupScale = Tween<double>(begin: 0.78, end: 1.0).animate(curvedIn);
    _popupOpacity = CurvedAnimation(
      parent: _popupController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    _popupSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(curvedIn);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _popupController.dispose();
    super.dispose();
  }

  double? _measureTabCenterX(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft.dx + (box.size.width / 2);
  }

  void _openPopup(_PopupGroup group) {
    final anchorKey = group == _PopupGroup.attendance
        ? _attendanceTabKey
        : _leaveTabKey;
    final centerX = _measureTabCenterX(anchorKey);

    setState(() {
      _activePopup = group;
      if (centerX != null) {
        _popupAnchorCenterX = centerX;
      }
    });
    _popupController.forward(from: 0.0);
  }

  Future<void> _closePopup({VoidCallback? afterClose}) async {
    if (_activePopup == _PopupGroup.none) {
      afterClose?.call();
      return;
    }
    await _popupController.reverse();
    if (!mounted) return;
    setState(() {
      _activePopup = _PopupGroup.none;
    });
    afterClose?.call();
  }

  Future<bool> _onWillPop() async {
    if (_activePopup != _PopupGroup.none) {
      await _closePopup();
      return false;
    }
    if (_currentIndex != 0) {
      _switchToScreen(widget: _getScreenForIndex(0), navIndex: 0);
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

  void _switchToScreen({required Widget widget, required int navIndex}) {
    HapticFeedback.selectionClick();
    final sameTab = navIndex == _currentIndex;

    setState(() {
      _currentIndex = navIndex;
    });

    if (sameTab) {
      setState(() => _activeScreen = widget);
      return;
    }

    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _activeScreen = widget;
      });
      _fadeController.forward();
    });
  }

  void _onNavTap(int index) {
    final item = _items[index];
    HapticFeedback.selectionClick();

    if (item.kind == _NavKind.attendanceGroup) {
      if (_activePopup == _PopupGroup.attendance) {
        _closePopup();
      } else {
        _openPopup(_PopupGroup.attendance);
      }
      return;
    }

    if (item.kind == _NavKind.leaveGroup) {
      if (_activePopup == _PopupGroup.leave) {
        _closePopup();
      } else {
        _openPopup(_PopupGroup.leave);
      }
      return;
    }

    _closePopup(
      afterClose: () {
        if (!mounted) return;
        _switchToScreen(
          widget: _getScreenForIndex(item.screenIndex ?? index),
          navIndex: index,
        );
      },
    );
  }

  List<_PopupOption> _currentPopupOptions() {
    if (_activePopup == _PopupGroup.attendance) {
      return [
        _PopupOption(
          icon: Icons.location_on_rounded,
          label: 'Presensi',
          accentColor: AppTheme.primaryColor,
          onTap: () => _closePopup(
            afterClose: () {
              if (!mounted) return;
              _switchToScreen(widget: const AttendanceScreen(), navIndex: 1);
            },
          ),
        ),
        _PopupOption(
          icon: Icons.history_rounded,
          label: 'History',
          accentColor: AppTheme.accentColor,
          onTap: () => _closePopup(
            afterClose: () {
              if (!mounted) return;
              _switchToScreen(
                widget: const AttendanceHistoryScreen(),
                navIndex: 1,
              );
            },
          ),
        ),
      ];
    }

    if (_activePopup == _PopupGroup.leave) {
      return [
        _PopupOption(
          icon: Icons.medical_services_outlined,
          label: 'Izin / Sakit',
          accentColor: AppTheme.primaryColor,
          onTap: () => _closePopup(
            afterClose: () {
              if (!mounted) return;
              _switchToScreen(
                widget: const SickLeaveHistoryScreen(),
                navIndex: 2,
              );
            },
          ),
        ),
        _PopupOption(
          icon: Icons.calendar_month_rounded,
          label: 'Cuti',
          accentColor: AppTheme.accentColor,
          onTap: () => _closePopup(
            afterClose: () {
              if (!mounted) return;
              _switchToScreen(widget: const LeaveHistoryScreen(), navIndex: 2);
            },
          ),
        ),
      ];
    }

    return const [];
  }

  Widget _buildFloatingPill(_PopupOption option) {
    const radius = BorderRadius.all(Radius.circular(22));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: Colors.white,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: option.accentColor.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: option.onTap,
                splashColor: option.accentColor.withValues(alpha: 0.08),
                highlightColor: option.accentColor.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: option.accentColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          option.icon,
                          color: option.accentColor,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        option.label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupOverlay(double bottomPadding, double screenWidth) {
    final options = _currentPopupOptions();
    if (_activePopup == _PopupGroup.none || options.isEmpty) {
      return const SizedBox.shrink();
    }

    final double navBottomMargin = bottomPadding > 0 ? bottomPadding + 6 : 16;
    final double bottomOffset = navBottomMargin + 88;
    final double fallbackCenterX =
        screenWidth * (_activePopup == _PopupGroup.attendance ? 0.30 : 0.50);
    final double centerX = _popupAnchorCenterX ?? fallbackCenterX;

    const double estimatedClusterWidth = 256;
    final double rawLeft = centerX - (estimatedClusterWidth / 2);
    final double clampedLeft = rawLeft.clamp(
      16.0,
      (screenWidth - estimatedClusterWidth - 16.0).clamp(16.0, double.infinity),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _closePopup(),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: clampedLeft,
            bottom: bottomOffset,
            child: FadeTransition(
              opacity: _popupOpacity,
              child: SlideTransition(
                position: _popupSlide,
                child: ScaleTransition(
                  scale: _popupScale,
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingPill(options[0]),
                      const SizedBox(width: 10),
                      _buildFloatingPill(options[1]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  GlobalKey? _tabKeyForIndex(int index) {
    final kind = _items[index].kind;
    if (kind == _NavKind.attendanceGroup) return _attendanceTabKey;
    if (kind == _NavKind.leaveGroup) return _leaveTabKey;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;

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
        body: Stack(
          children: [
            FadeTransition(opacity: _fadeAnimation, child: _activeScreen),
            _buildPopupOverlay(bottomPadding, screenWidth),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomPadding > 0 ? bottomPadding + 6 : 16,
          ),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.75),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.09),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isPopupOpen =
                    (item.kind == _NavKind.attendanceGroup &&
                        _activePopup == _PopupGroup.attendance) ||
                    (item.kind == _NavKind.leaveGroup &&
                        _activePopup == _PopupGroup.leave);
                final selected = index == _currentIndex || isPopupOpen;

                return Expanded(
                  child: GestureDetector(
                    key: _tabKeyForIndex(index),
                    onTap: () => _onNavTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                key: ValueKey<String>(
                                  '${index}_${isPopupOpen}_$selected',
                                ),
                                isPopupOpen
                                    ? Icons.close_rounded
                                    : (selected
                                          ? item.selectedIcon
                                          : item.icon),
                                color: selected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: -0.1,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
  final _NavKind kind;
  final int? screenIndex;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.kind,
    this.screenIndex,
  });
}

class _PopupOption {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _PopupOption({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });
}
