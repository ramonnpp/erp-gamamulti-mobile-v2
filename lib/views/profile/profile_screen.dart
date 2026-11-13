import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isEditing = false;
  bool _saving = false;

  late AnimationController _controller;
  late Animation<double> _headerFadeAnim;
  late Animation<Offset> _headerSlideAnim;
  late Animation<double> _card1FadeAnim;
  late Animation<Offset> _card1SlideAnim;
  late Animation<double> _card2FadeAnim;
  late Animation<Offset> _card2SlideAnim;
  late Animation<double> _actionsFadeAnim;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Staggered Animations untuk tiap bagian agar muncul berurutan dengan mulus
    _headerFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _headerSlideAnim =
        Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
          ),
        );

    _card1FadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _card1SlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _card2FadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );
    _card2SlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _actionsFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    final currentUser = DatabaseService().getCurrentUser();
    _nameController.text = currentUser?['name'] ?? '';
    _emailController.text = currentUser?['email'] ?? '';
    _phoneController.text = currentUser?['phone'] ?? '';
    _roleController.text = currentUser?['role'] ?? 'Employee';
    final img = currentUser?['profile_image']?.toString();
    final imgBytes = currentUser?['profile_image_data'] as Uint8List?;
    if (img != null && img.isNotEmpty && File(img).existsSync()) {
      _image = File(img);
    } else if (imgBytes != null && imgBytes.isNotEmpty) {
      _writeProfileImage(imgBytes, currentUser?['id']);
    }
  }

  Future<void> _writeProfileImage(Uint8List bytes, int? userId) async {
    final tmp = await getTemporaryDirectory();
    final path = '${tmp.path}/profile_$userId.png';
    final f = File(path);
    await f.writeAsBytes(bytes);
    if (mounted) {
      setState(() {
        _image = f;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    final f = await _picker.pickImage(source: source);
    if (f != null) setState(() => _image = File(f.path));
  }

  void _showImagePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(c).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ganti Foto Profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: const Text(
                'Ambil dari Kamera',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(c);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: const Text(
                'Pilih dari Galeri',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(c);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackbar.error(context, 'Nama tidak boleh kosong');
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final currentUser = DatabaseService().getCurrentUser();
    final userId = currentUser?['id'];
    bool ok = true;
    if (userId is int) {
      Uint8List? profileBytes;
      if (_image != null) {
        profileBytes = await _image!.readAsBytes();
      }
      ok = await DatabaseService().updateUser(
        userId: userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _roleController.text.trim(),
        profileImage: _image?.path ?? currentUser?['profile_image']?.toString(),
        profileImageBytes: profileBytes,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      CustomSnackbar.error(context, 'Gagal update profil');
      return;
    }
    setState(() => _isEditing = false);
    CustomSnackbar.success(context, 'Profil berhasil diperbarui');
  }

  Future<void> _showChangePassword() async {
    HapticFeedback.lightImpact();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final oldPass = oldCtrl.text.trim();
              final newPass = newCtrl.text.trim();
              final confirmPass = confirmCtrl.text.trim();
              if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                setDialogState(() => error = 'Semua field wajib diisi');
                return;
              }
              if (newPass.length < 6) {
                setDialogState(
                  () => error = 'Password baru minimal 6 karakter',
                );
                return;
              }
              if (newPass != confirmPass) {
                setDialogState(() => error = 'Konfirmasi password tidak sama');
                return;
              }
              setDialogState(() {
                loading = true;
                error = null;
              });
              final user = DatabaseService().getCurrentUser();
              bool ok = false;
              if (user != null && user['id'] is int) {
                ok = await DatabaseService().changePassword(
                  userId: user['id'],
                  newPassword: newPass,
                );
              }
              if (!mounted) return;
              setDialogState(() => loading = false);
              if (!ok) {
                setDialogState(() => error = 'Gagal mengganti password');
                return;
              }
              Navigator.pop(ctx);
              if (!mounted) return;
              CustomSnackbar.success(context, 'Password berhasil diubah');
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ganti Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Amankan akun Anda dengan sandi baru',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _passField(
                    controller: oldCtrl,
                    label: 'Password Lama',
                    obscure: obscureOld,
                    onToggle: () =>
                        setDialogState(() => obscureOld = !obscureOld),
                  ),
                  const SizedBox(height: 12),
                  _passField(
                    controller: newCtrl,
                    label: 'Password Baru',
                    obscure: obscureNew,
                    onToggle: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 12),
                  _passField(
                    controller: confirmCtrl,
                    label: 'Konfirmasi Password Baru',
                    obscure: obscureConfirm,
                    onToggle: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.errorColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: loading ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            foregroundColor: AppTheme.textSecondary,
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: loading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(fontWeight: FontWeight.w800),
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
      },
    );
  }

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: AppTheme.textSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  Icons.logout_rounded,
                  size: 30,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Keluar Akun',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Yakin ingin keluar dari aplikasi?',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 50),
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

    if (confirmed == true) {
      await DatabaseService().clearUserSession();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.isEmpty
        ? 'Pengguna'
        : _nameController.text;
    final role = _roleController.text.isEmpty
        ? 'Employee'
        : _roleController.text;
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryColor,
            toolbarHeight: 60,
            title: const Text(
              'Profil Pengguna',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),

          // Header dengan Animasi Masuk (Fade & Slide)
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFadeAnim,
              child: SlideTransition(
                position: _headerSlideAnim,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage: _image != null
                                  ? FileImage(_image!)
                                  : null,
                              child: _image == null
                                  ? Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePicker,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _emailController.text,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
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
            ),
          ),

          // Konten Form Utama dengan Staggered Animation
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card 1: Informasi Akun (Animasi Muncul Kedua)
                  FadeTransition(
                    opacity: _card1FadeAnim,
                    child: SlideTransition(
                      position: _card1SlideAnim,
                      child: _sectionCard(
                        title: 'Informasi Akun',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _field(
                            label: 'Nama Lengkap',
                            controller: _nameController,
                            icon: Icons.person_outline_rounded,
                            enabled: _isEditing,
                          ),
                          _field(
                            label: 'Email',
                            controller: _emailController,
                            icon: Icons.email_outlined,
                            enabled: false,
                          ),
                          _field(
                            label: 'Nomor HP',
                            controller: _phoneController,
                            icon: Icons.phone_outlined,
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                          ),
                          _roleField(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Keamanan & Sistem (Animasi Muncul Ketiga)
                  FadeTransition(
                    opacity: _card2FadeAnim,
                    child: SlideTransition(
                      position: _card2SlideAnim,
                      child: _sectionCard(
                        title: 'Keamanan & Sistem',
                        icon: Icons.security_rounded,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isEditing
                                    ? Icons.close_rounded
                                    : Icons.edit_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _isEditing
                                  ? 'Batalkan Edit Profil'
                                  : 'Edit Informasi Profil',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              _isEditing
                                  ? 'Keluar dari mode ubah data'
                                  : 'Ubah nama dan nomor HP Anda',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isEditing = !_isEditing);
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(
                              color: Color(0xFFF1F5F9),
                              height: 16,
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Ganti Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: const Text(
                              'Perbarui keamanan sandi akun Anda',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            onTap: _showChangePassword,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Aksi Tombol Simpan & Keluar (Animasi Muncul Terakhir)
                  FadeTransition(
                    opacity: _actionsFadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isEditing
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  key: const ValueKey('edit_active'),
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _saving ? null : _saveProfile,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        _saving
                                            ? 'Menyimpan...'
                                            : 'Simpan Perubahan Profil',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('edit_inactive'),
                                ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: AppTheme.errorColor,
                          ),
                          label: const Text(
                            'Keluar Akun',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            backgroundColor: AppTheme.errorColor.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _roleField() {
    const roles = ['Employee', 'Manager', 'Admin', 'HR'];
    final current = roles.contains(_roleController.text)
        ? _roleController.text
        : 'Employee';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role / Jabatan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _isEditing ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isEditing
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: _isEditing ? 1.2 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isExpanded: true,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              items: roles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isEditing
                  ? (v) {
                      if (v != null) setState(() => _roleController.text = v);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
                filled: true,
                fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
