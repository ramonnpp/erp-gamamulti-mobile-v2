import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';

class LeaveFormDialog extends StatefulWidget {
  const LeaveFormDialog({super.key});

  @override
  State<LeaveFormDialog> createState() => _LeaveFormDialogState();
}

class _LeaveFormDialogState extends State<LeaveFormDialog>
    with SingleTickerProviderStateMixin {
  String _selectedLeaveType = 'Cuti Tahunan';
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  String? _errorStart;
  String? _errorEnd;
  String? _errorReason;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Pilih Tanggal';
    return DateFormat('dd MMM yyyy', 'id_ID').format(d);
  }

  int? get _durationDays {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(
          0xFFFFF1F2,
        ), // Merah pastel lembut untuk peringatan
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Konfirmasi Permanen',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data cuti yang dikirim akan langsung tersimpan dan tidak bisa ditarik ulang. Mohon periksa kembali:',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7F1D1D),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  _confirmRow('Jenis', _selectedLeaveType),
                  const Divider(height: 16, color: Color(0xFFFEE2E2)),
                  _confirmRow('Mulai', _fmt(_startDate)),
                  const Divider(height: 16, color: Color(0xFFFEE2E2)),
                  _confirmRow('Selesai', _fmt(_endDate)),
                  if (_durationDays != null) ...[
                    const Divider(height: 16, color: Color(0xFFFEE2E2)),
                    _confirmRow('Durasi', '$_durationDays Hari Kerja'),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cek Lagi',
                    style: TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ya, Simpan Data',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF7F1D1D),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF991B1B),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _errorStart = _startDate == null ? 'Pilih tanggal mulai' : null;
      _errorEnd = _endDate == null ? 'Pilih tanggal selesai' : null;
      _errorReason = _reasonController.text.trim().isEmpty
          ? 'Alasan wajib diisi'
          : null;
      if (_startDate != null &&
          _endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        _errorEnd = 'Tanggal selesai tidak valid';
      }
    });
    if (_errorStart != null || _errorEnd != null || _errorReason != null)
      return;

    final confirmed = await _confirmSubmit();
    if (!confirmed || !mounted) return;

    final user = DatabaseService().getCurrentUser();
    if (user == null) return;

    setState(() => _isSubmitting = true);
    final success = await DatabaseService().submitLeaveRequest(
      userId: user['id'],
      leaveType: _selectedLeaveType,
      startDate: _startDate.toString().split(' ')[0],
      endDate: _endDate.toString().split(' ')[0],
      reason: _reasonController.text.trim(),
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (success) {
      CustomSnackbar.success(context, 'Permohonan cuti berhasil disimpan!');
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.error(context, 'Gagal menyimpan ke database');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: const Color(
            0xFFF0FDF4,
          ), // Hijau mint pastel yang adem & organik
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER ORGANIK & HALUS
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Formulir Cuti',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF064E3B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rencanakan waktu istirahat Anda',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF064E3B),
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // KONTEN UTAMA DENGAN CARD PUTIH MELENGKUNG (FLOWING DESIGN)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF064E3B,
                            ).withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PILIH KATEGORI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // PILIHAN KATEGORI CUTI LEBIH FLUID & EMPUK
                          Row(
                            children:
                                [
                                  'Cuti Tahunan',
                                  'Cuti Bersama',
                                  'Cuti Darurat',
                                ].map((type) {
                                  final selected = _selectedLeaveType == type;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedLeaveType = type,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeInOut,
                                        margin: EdgeInsets.only(
                                          right: type != 'Cuti Darurat' ? 8 : 0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: selected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFFF8FAFC),
                                          border: Border.all(
                                            color: selected
                                                ? AppTheme.primaryColor
                                                : const Color(0xFFE2E8F0),
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          type.replaceAll('Cuti ', ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            'PERIODE TANGGAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFluidDateField(
                                  'Mulai',
                                  _startDate,
                                  _errorStart,
                                  () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _startDate = picked;
                                        _errorStart = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFluidDateField(
                                  'Selesai',
                                  _endDate,
                                  _errorEnd,
                                  () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: _startDate ?? DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _endDate = picked;
                                        _errorEnd = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          if (_durationDays != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Durasi Total: $_durationDays Hari Kerja',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF064E3B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          const Text(
                            'ALASAN / CATATAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reasonController,
                            maxLines: 3,
                            onChanged: (_) =>
                                setState(() => _errorReason = null),
                            decoration: InputDecoration(
                              hintText: 'Tuliskan alasan atau keterangan...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: _errorReason != null
                                      ? AppTheme.errorColor
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: _errorReason != null
                                      ? AppTheme.errorColor
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          if (_errorReason != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _errorReason!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // TOMBOL AKSI BAWAH
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Kirim Pengajuan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
    );
  }

  Widget _buildFluidDateField(
    String label,
    DateTime? date,
    String? error,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: error != null
                    ? AppTheme.errorColor
                    : const Color(0xFFE2E8F0),
              ),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fmt(date),
                    style: TextStyle(
                      color: date != null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF94A3B8),
                      fontWeight: date != null
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              error,
              style: const TextStyle(fontSize: 11, color: AppTheme.errorColor),
            ),
          ),
      ],
    );
  }
}
