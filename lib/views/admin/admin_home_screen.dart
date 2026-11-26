import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/admin_database_service.dart';
import '../../widgets/custom_snackbar.dart';

/// Satu jabatan / role pada sistem.
/// `value` = nilai yang disimpan di kolom users.role.
class _RoleInfo {
  final String key;
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _RoleInfo({
    required this.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

final List<_RoleInfo> _roleInfos = [
  const _RoleInfo(
    key: 'admin',
    label: 'Admin',
    value: 'admin',
    subtitle: 'Akses penuh sistem',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFFB7791F),
  ),
  const _RoleInfo(
    key: 'hr',
    label: 'HR',
    value: 'HR',
    subtitle: 'Kepegawaian',
    icon: Icons.badge_rounded,
    color: Color(0xFF7C3AED),
  ),
  const _RoleInfo(
    key: 'manajemen',
    label: 'Manajemen',
    value: 'Manajemen',
    subtitle: 'Jajaran manajemen',
    icon: Icons.business_center_rounded,
    color: Color(0xFF0369A1),
  ),
  _RoleInfo(
    key: 'employee',
    label: 'Employee',
    value: 'Employee',
    subtitle: 'Karyawan',
    icon: Icons.person_rounded,
    color: AppTheme.primaryColor,
  ),
];

/// Nilai role di database -> kunci jabatan. Nilai lama (mis. 'user', 'Staff')
/// dianggap Employee.
String _roleKey(dynamic role) {
  final r = (role?.toString() ?? '').trim().toLowerCase();
  if (r == 'admin') return 'admin';
  if (r == 'hr' || r == 'hrd') return 'hr';
  if (r == 'manajemen' || r == 'management' || r == 'manager') {
    return 'manajemen';
  }
  return 'employee';
}

_RoleInfo _infoOf(String key) =>
    _roleInfos.firstWhere((r) => r.key == key, orElse: () => _roleInfos.last);

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all' atau kunci jabatan
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ========== DATA ==========
  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await AdminDatabaseService().getAllUsersDetail();
      if (!mounted) return;
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error load users: $e');
      if (mounted) {
        CustomSnackbar.error(context, 'Gagal memuat data pengguna');
        setState(() => _isLoading = false);
      }
    }
  }

  int get _totalCount => _users.length;
  int _countOf(String key) =>
      _users.where((u) => _roleKey(u['role']) == key).length;

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final searchMatch = q.isEmpty || name.contains(q) || email.contains(q);
      final filterMatch =
          _selectedFilter == 'all' || _roleKey(user['role']) == _selectedFilter;
      return searchMatch && filterMatch;
    }).toList();
  }

  String _initial(String? name) {
    final n = (name ?? '').trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  String _fmtUpdated(dynamic raw) {
    final str = raw?.toString().trim() ?? '';
    if (str.isEmpty) return '';
    final d = DateTime.tryParse(str.replaceFirst(' ', 'T'));
    if (d == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(d);
  }

  // ========== STYLE HELPERS ==========
  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(const Color(0xFFE2E8F0)),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(AppTheme.primaryColor, 1.4),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ========== FORM TAMBAH / EDIT USER ==========
  void _showUserForm({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final adminId = DatabaseService().getCurrentUser()?['id'];
    if (adminId is! int) {
      CustomSnackbar.error(
        context,
        'Sesi admin tidak valid, silakan login ulang',
      );
      return;
    }
    final int? targetId = user?['id'] as int?;
    final originalRole = user?['role']?.toString() ?? 'user';

    final nameCtrl = TextEditingController(
      text: user?['name']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: user?['email']?.toString() ?? '',
    );
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(
      text: user?['phone']?.toString() ?? '',
    );

    final originalKey = _roleKey(originalRole);
    String selectedKey = isEdit ? originalKey : 'employee';
    bool obscure = true;
    String? error;
    bool loading = false;

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDS) {
            Future<void> onSubmit() async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final password = passwordCtrl.text;

              if (name.length < 3) {
                setDS(
                  () => error = 'Nama lengkap wajib diisi (min 3 karakter)',
                );
                return;
              }
              if (email.isEmpty) {
                setDS(() => error = 'Email wajib diisi');
                return;
              }
              if (!isEdit && password.length < 6) {
                setDS(() => error = 'Password minimal 6 karakter');
                return;
              }
              if (isEdit && password.isNotEmpty && password.length < 6) {
                setDS(() => error = 'Password baru minimal 6 karakter');
                return;
              }

              setDS(() {
                loading = true;
                error = null;
              });

              // Jika jabatan tidak diubah, pertahankan nilai asli di database.
              final resolvedRole = (isEdit && selectedKey == originalKey)
                  ? originalRole
                  : _infoOf(selectedKey).value;

              try {
                final phone = phoneCtrl.text.trim();
                final bool result;
                if (isEdit) {
                  result = await AdminDatabaseService().updateUser(
                    adminId: adminId,
                    targetUserId: targetId!,
                    name: name,
                    email: email,
                    role: resolvedRole,
                    phone: phone.isNotEmpty ? phone : null,
                    newPassword: password.isNotEmpty ? password : null,
                  );
                } else {
                  result = await AdminDatabaseService().createUser(
                    adminId: adminId,
                    name: name,
                    email: email,
                    password: password,
                    role: resolvedRole,
                    phone: phone.isNotEmpty ? phone : null,
                  );
                }
                if (!mounted || !dialogCtx.mounted) return;
                if (result) {
                  CustomSnackbar.success(
                    context,
                    isEdit
                        ? 'Data user berhasil diperbarui'
                        : 'User berhasil ditambahkan',
                  );
                  Navigator.pop(dialogCtx, true);
                  _loadData(silent: true);
                } else {
                  setDS(() {
                    loading = false;
                    error = 'Gagal menyimpan data user';
                  });
                }
              } catch (e) {
                setDS(() {
                  loading = false;
                  error = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            Widget roleTile(_RoleInfo info) {
              final selected = selectedKey == info.key;
              return Expanded(
                child: GestureDetector(
                  onTap: loading
                      ? null
                      : () => setDS(() => selectedKey = info.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? info.color.withValues(alpha: 0.08)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? info.color : const Color(0xFFE2E8F0),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: selected
                                ? info.color
                                : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            info.icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? info.color
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                info.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final showAdminWarning =
                selectedKey == 'admin' && (!isEdit || originalKey != 'admin');

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(dialogCtx).padding.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetHandle(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEdit
                                  ? Icons.manage_accounts_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit User' : 'Tambah User Baru',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  isEdit
                                      ? (user['name']?.toString() ?? '')
                                      : 'Buat akun baru dan tentukan jabatannya',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: error == null
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.errorColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
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
                                          fontSize: 12.5,
                                          color: AppTheme.errorColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          'Nama Lengkap *',
                          Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: _fieldDecoration(
                          'Email / Username *',
                          Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscure,
                        decoration: _fieldDecoration(
                          isEdit ? 'Password Baru' : 'Password *',
                          Icons.lock_outline_rounded,
                          hint: isEdit
                              ? 'Kosongkan jika tidak diubah'
                              : 'Minimal 6 karakter',
                          suffix: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setDS(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDecoration(
                          'Nomor Telepon (Opsional)',
                          Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Jabatan / Role',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          roleTile(_roleInfos[0]),
                          const SizedBox(width: 10),
                          roleTile(_roleInfos[1]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          roleTile(_roleInfos[2]),
                          const SizedBox(width: 10),
                          roleTile(_roleInfos[3]),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: !showAdminWarning
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppTheme.errorColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Akun ini akan memiliki akses penuh ke fitur Admin.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.errorColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: loading
                                  ? null
                                  : () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
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
                              onPressed: loading ? null : onSubmit,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                minimumSize: const Size(0, 50),
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isEdit ? 'Simpan Perubahan' : 'Simpan',
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
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Tunggu animasi tutup selesai sebelum controller dibuang.
      Future.delayed(const Duration(milliseconds: 450), () {
        nameCtrl.dispose();
        emailCtrl.dispose();
        passwordCtrl.dispose();
        phoneCtrl.dispose();
      });
    });
  }

  // ========== HAPUS USER ==========
  void _deleteUser(Map<String, dynamic> user) {
    final adminId = DatabaseService().getCurrentUser()?['id'];
    if (adminId is! int) {
      CustomSnackbar.error(
        context,
        'Sesi admin tidak valid, silakan login ulang',
      );
      return;
    }
    final targetId = user['id'] as int;
    final userName = user['name']?.toString() ?? 'pengguna ini';

    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              _sheetHandle(),
              const SizedBox(height: 22),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.errorColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hapus Pengguna',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'Yakin ingin menghapus akun '),
                    TextSpan(
                      text: userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '?\nTindakan ini tidak dapat dibatalkan dan akan dicatat ke audit log.',
                    ),
                  ],
                ),
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
                      onPressed: () async {
                        Navigator.pop(ctx, true);
                        try {
                          final result = await AdminDatabaseService()
                              .deleteUser(
                                adminId: adminId,
                                targetUserId: targetId,
                              );
                          if (!mounted) return;
                          if (result) {
                            CustomSnackbar.success(
                              context,
                              'User berhasil dihapus',
                            );
                            _loadData(silent: true);
                          }
                        } catch (e) {
                          if (!mounted) return;
                          CustomSnackbar.error(
                            context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      },
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
                        'Ya, Hapus',
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
  }

  // ========== HEADER STATS ==========
  Widget _statsRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _statBadge('Total', '$_totalCount', Colors.white),
          _statBadge('Admin', '${_countOf('admin')}', AppTheme.accentColor),
          _statBadge('HR', '${_countOf('hr')}', const Color(0xFFDDD6FE)),
          _statBadge(
            'Manajemen',
            '${_countOf('manajemen')}',
            const Color(0xFFBAE6FD),
          ),
          _statBadge(
            'Employee',
            '${_countOf('employee')}',
            const Color(0xFFA7F3D0),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String count, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SEARCH & FILTER ==========
  Widget _searchField() {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama atau email',
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.textSecondary,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppTheme.textSecondary,
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border(const Color(0xFFD0D9E4)),
        enabledBorder: border(const Color(0xFFD0D9E4)),
        focusedBorder: border(AppTheme.primaryColor, 1.4),
      ),
    );
  }

  Widget _filterChips() {
    final items = <(String, String, int)>[
      ('all', 'Semua', _totalCount),
      ...(_roleInfos.map((r) => (r.key, r.label, _countOf(r.key)))),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((t) {
          final (key, label, count) = t;
          final selected = _selectedFilter == key;
          final color = key == 'all'
              ? AppTheme.primaryColor
              : _infoOf(key).color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$label ($count)'),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedFilter = key),
              selectedColor: color,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? color : const Color(0xFFD0D9E4),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ========== KARTU USER ==========
  Widget _miniAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final c = enabled ? color : const Color(0xFF94A3B8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String text,
    required Color color,
    IconData? icon,
    bool filled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user, int index) {
    final info = _infoOf(_roleKey(user['role']));
    final isMe = user['id'] == DatabaseService().getCurrentUser()?['id'];
    final name = user['name']?.toString() ?? '-';
    final email = user['email']?.toString() ?? '-';
    final phone = (user['phone']?.toString() ?? '').trim();
    final updated = _fmtUpdated(user['updated_at']);

    return _AnimatedListItem(
      key: ValueKey('user_${user['id']}'),
      delayMs: (index > 8 ? 8 : index) * 55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD0D9E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: info.color.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    _initial(name),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: info.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            text: info.label,
                            color: info.color,
                            icon: info.icon,
                          ),
                          if (isMe)
                            _chip(
                              text: 'Anda',
                              color: AppTheme.primaryColor,
                              filled: false,
                            ),
                          if (phone.isNotEmpty)
                            _chip(
                              text: phone,
                              color: AppTheme.textSecondary,
                              icon: Icons.phone_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    updated.isEmpty
                        ? 'Belum ada pembaruan'
                        : 'Diperbarui $updated',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _miniAction(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: AppTheme.primaryColor,
                  onTap: () => _showUserForm(user: user),
                ),
                const SizedBox(width: 8),
                _miniAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  color: AppTheme.errorColor,
                  onTap: isMe ? null : () => _deleteUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({required bool noData}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            noData
                ? 'Belum ada data pengguna.'
                : 'Tidak ada pengguna yang cocok.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          if (noData) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Muat Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== MAIN BUILD ==========
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              automaticallyImplyLeading: false,
              title: const Text(
                'Kelola User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.of(context).padding.top + 55,
                    18,
                    16,
                  ),
                  child: _statsRow(),
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () => _loadData(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            children: [
              _searchField(),
              const SizedBox(height: 12),
              _filterChips(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                _emptyState(noData: _users.isEmpty)
              else
                ...List.generate(
                  filtered.length,
                  (i) => _userCard(filtered[i], i),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // Sama dengan tombol di halaman admin lain (bottom: 88).
        padding: const EdgeInsets.only(bottom: 88.0),
        child: FloatingActionButton.extended(
          onPressed: () => _showUserForm(),
          backgroundColor: AppTheme.primaryColor,
          elevation: 6,
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: const Text(
            'Tambah User',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Item list muncul berurutan: fade + slide naik tipis (sama seperti animasi di Home).
class _AnimatedListItem extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedListItem({
    super.key,
    required this.delayMs,
    required this.child,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> {
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
