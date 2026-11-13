import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Employee';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final _roleOptions = [
    {
      'label': 'Employee',
      'desc': 'Staf operasional',
      'icon': Icons.person_outline_rounded,
    },
    {
      'label': 'Manager',
      'desc': 'Kepala divisi',
      'icon': Icons.supervisor_account_outlined,
    },
    {
      'label': 'HR',
      'desc': 'Sumber daya manusia',
      'icon': Icons.groups_outlined,
    },
    {
      'label': 'Admin',
      'desc': 'Administrator sistem',
      'icon': Icons.admin_panel_settings_outlined,
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _backToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final db = DatabaseService();
      final success = await db.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      if (success) {
        CustomSnackbar.success(
          context,
          'Registrasi berhasil! Silakan masuk dengan akun Anda.',
        );
        _backToLogin();
      } else {
        CustomSnackbar.error(
          context,
          'Gagal registrasi. Email mungkin sudah terdaftar.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.error(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2F6),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Top Navigation Bar dengan Hero Logo Terhubung
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _backToLogin,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDCE3EC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                                color: AppTheme.primaryColor,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Hero(
                        tag: 'gama_multi_logo',
                        child: Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: const Color(0xFFDCE3EC)),
                          ),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.business_center_rounded,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Form Content dengan Staggered Entrance
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Registrasi Karyawan',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lengkapi informasi berikut untuk mendaftarkan akun baru.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Card 1: Identitas
                        _AnimatedSectionCard(
                          delayMs: 60,
                          step: '01',
                          title: 'Informasi Identitas',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Lengkap',
                                  hintText: 'Nama lengkap beserta gelar',
                                  fillColor: Color(0xFFF8FAFC),
                                  prefixIcon: Icon(
                                    Icons.badge_outlined,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Nama tidak boleh kosong'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email Perusahaan',
                                  hintText: 'nama@gamamulti.co.id',
                                  fillColor: Color(0xFFF8FAFC),
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Email tidak boleh kosong'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nomor HP / WhatsApp',
                                  hintText: '081234567890',
                                  fillColor: Color(0xFFF8FAFC),
                                  prefixIcon: Icon(
                                    Icons.phone_outlined,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Nomor HP tidak boleh kosong'
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Card 2: Role / Jabatan
                        _AnimatedSectionCard(
                          delayMs: 140,
                          step: '02',
                          title: 'Hak Akses & Jabatan',
                          child: Column(
                            children: _roleOptions.map((item) {
                              final label = item['label'] as String;
                              final desc = item['desc'] as String;
                              final icon = item['icon'] as IconData;
                              final isSelected = _selectedRole == label;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selectedRole = label),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withValues(
                                                    alpha: 0.14,
                                                  )
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 19,
                                            color: isSelected
                                                ? AppTheme.accentColor
                                                : AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                desc,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Colors.white.withValues(
                                                          alpha: 0.78,
                                                        )
                                                      : AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          child: Icon(
                                            isSelected
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons
                                                      .radio_button_off_rounded,
                                            key: ValueKey(isSelected),
                                            size: 20,
                                            color: isSelected
                                                ? AppTheme.accentColor
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Card 3: Keamanan (Password 2x)
                        _AnimatedSectionCard(
                          delayMs: 220,
                          step: '03',
                          title: 'Keamanan Akun',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Minimal 6 karakter',
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        key: ValueKey(_obscurePassword),
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password tidak boleh kosong';
                                  }
                                  if (value.length < 6) {
                                    return 'Password minimal 6 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                decoration: InputDecoration(
                                  labelText: 'Konfirmasi Password',
                                  hintText: 'Ulangi password di atas',
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        key: ValueKey(_obscureConfirmPassword),
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Konfirmasi password wajib diisi';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Password tidak cocok';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFDCE3EC))),
                  ),
                  child: _PressScaleButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _isLoading
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'Selesaikan Pendaftaran',
                                key: ValueKey('label'),
                              ),
                      ),
                    ),
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

class _AnimatedSectionCard extends StatefulWidget {
  final int delayMs;
  final String step;
  final String title;
  final Widget child;

  const _AnimatedSectionCard({
    required this.delayMs,
    required this.step,
    required this.title,
    required this.child,
  });

  @override
  State<_AnimatedSectionCard> createState() => _AnimatedSectionCardState();
}

class _AnimatedSectionCardState extends State<_AnimatedSectionCard> {
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
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE3EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.step,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PressScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _PressScaleButton({required this.onPressed, required this.child});

  @override
  State<_PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<_PressScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
