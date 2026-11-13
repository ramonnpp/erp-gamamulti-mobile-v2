import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';

class ConnectionFailedScreen extends StatelessWidget {
  const ConnectionFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                // Badge Ikon Error yang Rapi
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Koneksi ke Server Terputus',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sistem tidak dapat menjangkau server ERP Gama Multi saat ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Kartu Panduan Troubleshooting Singkat
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hal yang dapat diperiksa:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10),
                      _CheckItem(
                        text:
                            'Pastikan Wi-Fi atau data seluler aktif dan stabil.',
                      ),
                      SizedBox(height: 6),
                      _CheckItem(
                        text:
                            'Periksa akses jaringan internal / VPN jika diperlukan.',
                      ),
                      SizedBox(height: 6),
                      _CheckItem(
                        text: 'Hubungi tim IT Support jika kendala berlanjut.',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                  ),
                  style: ElevatedButton.styleFrom(elevation: 0),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Hubungkan Ulang'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'Kembali ke Halaman Login',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
