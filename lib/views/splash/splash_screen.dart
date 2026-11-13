import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../auth/login_screen.dart';
import '../navigation/main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _subtleScale;

  String _statusText = 'Menyiapkan ruang kerja...';
  double _progress = 0.35;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _subtleScale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _statusText = 'Memverifikasi sesi pengguna...';
      _progress = 0.75;
    });

    final results = await Future.wait([
      DatabaseService().loadUserSession(),
      Future.delayed(const Duration(milliseconds: 950)),
    ]);

    if (!mounted) return;
    setState(() {
      _statusText = 'Membuka dashboard...';
      _progress = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final user = results[0];
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            user != null ? const MainNavigation() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Wadah logo putih bersih
                    ScaleTransition(
                      scale: _subtleScale,
                      child: Container(
                        width: 132,
                        height: 132,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.business_center_rounded,
                            size: 64,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'ERP GAMA MULTI MOBILE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enterprise Resource Planning System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Step status dinamis + progress bar deterministik
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: _progress),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) => LinearProgressIndicator(
                            value: value,
                            minHeight: 3.5,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'PT Gama Multi Usaha Mandiri  •  v2.0',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.3,
                        color: Colors.white.withValues(alpha: 0.52),
                      ),
                    ),

                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
