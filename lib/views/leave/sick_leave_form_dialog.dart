import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';

class SickLeaveFormDialog extends StatefulWidget {
  const SickLeaveFormDialog({super.key});

  @override
  State<SickLeaveFormDialog> createState() => _SickLeaveFormDialogState();
}

class _SickLeaveFormDialogState extends State<SickLeaveFormDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  String _leaveCategory = 'Sakit';
  bool _isSubmitting = false;

  String? _attachmentPath;
  Uint8List? _attachmentBytes;
  String _attachmentType = 'none';

  String? _errorDate;
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

  Future<String?> _copyToAppDir(String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final dest = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (sourcePath != dest.path) {
        await File(sourcePath).copy(dest.path);
      }
      _attachmentBytes = await dest.readAsBytes();
      return dest.path;
    } catch (e) {
      debugPrint('Copy attachment failed: $e');
      _attachmentBytes = null;
      return sourcePath;
    }
  }

  String _attachmentMime(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Pilih Tanggal';
    return DateFormat('dd MMM yyyy', 'id_ID').format(d);
  }

  int get _calculatedDays {
    if (_startDate == null || _endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _errorDate = null;
      });
    }
  }

  // VALIDASI TINGGI/BERBAHAYA (HIGH-RISK WARNING DIALOG)
  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFFFFF1F2), // Merah pastel peringatan
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
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Peringatan Penting!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF991B1B),
                  letterSpacing: -0.3,
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
              'Data pengajuan sakit/izin yang dikirim bersifat PERMANEN dan langsung tercatat pada sistem HR. Pastikan seluruh informasi dan dokumen sudah benar karena tidak dapat dibatalkan.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF7F1D1D),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  _confirmRow('Kategori', _leaveCategory),
                  const Divider(height: 14, color: Color(0xFFFEE2E2)),
                  _confirmRow(
                    'Periode',
                    '${_fmt(_startDate)} - ${_fmt(_endDate)}',
                  ),
                  const Divider(height: 14, color: Color(0xFFFEE2E2)),
                  _confirmRow('Durasi', '$_calculatedDays Hari'),
                  const Divider(height: 14, color: Color(0xFFFEE2E2)),
                  _confirmRow(
                    'Lampiran',
                    _attachmentType == 'none'
                        ? 'Tanpa Lampiran'
                        : 'Dilampirkan',
                  ),
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
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ya, Kirim Data',
                    style: TextStyle(
                      color: Colors.white,
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
    return result ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF7F1D1D),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF991B1B),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _errorDate = (_startDate == null || _endDate == null)
          ? 'Periode tanggal wajib dipilih'
          : null;
      _errorReason = _reasonController.text.trim().isEmpty
          ? 'Alasan wajib diisi'
          : null;
    });
    if (_errorDate != null || _errorReason != null) return;

    final confirmed = await _confirmSubmit();
    if (!confirmed || !mounted) return;

    final user = DatabaseService().getCurrentUser();
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final bool hasAttachment = _attachmentType != 'none';
    final String? pathToSubmit = hasAttachment ? _attachmentPath : null;

    Uint8List? bytesToSubmit = hasAttachment ? _attachmentBytes : null;
    if (hasAttachment &&
        (bytesToSubmit == null || bytesToSubmit.isEmpty) &&
        pathToSubmit != null) {
      try {
        final f = File(pathToSubmit);
        if (await f.exists()) {
          bytesToSubmit = await f.readAsBytes();
          _attachmentBytes = bytesToSubmit;
        }
      } catch (e) {
        debugPrint('Gagal baca bytes lampiran: $e');
      }
    }

    if (hasAttachment && (bytesToSubmit == null || bytesToSubmit.isEmpty)) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        CustomSnackbar.error(
          context,
          'Lampiran gagal dibaca. Silakan pilih ulang file.',
        );
      }
      return;
    }

    final success = await DatabaseService()
        .submitSickLeaveRequestWithAttachment(
          userId: user['id'],
          leaveType: '$_leaveCategory / Izin',
          startDate: _startDate.toString().split(' ')[0],
          endDate: _endDate.toString().split(' ')[0],
          reason: _reasonController.text.trim(),
          attachmentPath: pathToSubmit,
          attachmentBytes: bytesToSubmit,
          attachmentName: pathToSubmit != null
              ? File(pathToSubmit).uri.pathSegments.last
              : null,
          attachmentMime: _attachmentMime(pathToSubmit),
        );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (success) {
      CustomSnackbar.success(context, 'Pengajuan berhasil disimpan!');
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.error(context, 'Gagal menyimpan ke database');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: const Color(0xFFF0FDF4), // Hijau mint pastel senada
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER ORGANIK & HALUS (SELARAS FORM CUTI)
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
                          Icons.medical_services_rounded,
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
                              'Formulir Izin / Sakit',
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
                          Row(
                            children: ['Sakit', 'Izin'].map((cat) {
                              final selected = _leaveCategory == cat;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: cat == 'Sakit' ? 8 : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _leaveCategory = cat),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
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
                                      alignment: Alignment.center,
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // PERIODE TANGGAL
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
                          GestureDetector(
                            onTap: () => _pickDateRange(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _errorDate != null
                                      ? AppTheme.errorColor
                                      : const Color(0xFFE2E8F0),
                                ),
                                color: const Color(0xFFF8FAFC),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.date_range_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _startDate != null && _endDate != null
                                          ? '${_fmt(_startDate)} - ${_fmt(_endDate)}'
                                          : 'Pilih rentang tanggal mulai & selesai',
                                      style: TextStyle(
                                        color: _startDate != null
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFF94A3B8),
                                        fontWeight: _startDate != null
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
                          if (_startDate != null && _endDate != null) ...[
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
                                    'Durasi Total: $_calculatedDays Hari',
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
                          if (_errorDate != null) _errorText(_errorDate!),
                          const SizedBox(height: 24),

                          // ALASAN / CATATAN
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
                          if (_errorReason != null) _errorText(_errorReason!),
                          const SizedBox(height: 24),

                          // LAMPIRAN SURAT DOKTER
                          const Text(
                            'LAMPIRAN SURAT DOKTER (OPSIONAL)',
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
                              _attachOption(
                                'none',
                                Icons.close_rounded,
                                'Tanpa',
                              ),
                              const SizedBox(width: 8),
                              _attachOption(
                                'gallery',
                                Icons.image_outlined,
                                'Galeri',
                                () async {
                                  final photo = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (photo != null) {
                                    final saved = await _copyToAppDir(
                                      photo.path,
                                    );
                                    setState(() {
                                      _attachmentType = 'gallery';
                                      _attachmentPath = saved;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              _attachOption(
                                'camera',
                                Icons.camera_alt_outlined,
                                'Kamera',
                                () async {
                                  final photo = await ImagePicker().pickImage(
                                    source: ImageSource.camera,
                                  );
                                  if (photo != null) {
                                    final saved = await _copyToAppDir(
                                      photo.path,
                                    );
                                    setState(() {
                                      _attachmentType = 'camera';
                                      _attachmentPath = saved;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              _attachOption(
                                'file',
                                Icons.folder_open_outlined,
                                'File',
                                () async {
                                  final files = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png',
                                      'doc',
                                      'docx',
                                    ],
                                  );
                                  if (files.isNotEmpty) {
                                    final filePath = files.first.path;
                                    if (filePath != null) {
                                      final saved = await _copyToAppDir(
                                        filePath,
                                      );
                                      setState(() {
                                        _attachmentType = 'file';
                                        _attachmentPath = saved;
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_attachmentPath != null &&
                              _attachmentPath!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
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
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF059669),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _attachmentPath!.split('/').last,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _attachmentPath = null;
                                      _attachmentType = 'none';
                                    }),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 6),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachOption(
    String type,
    IconData icon,
    String label, [
    VoidCallback? onTap,
  ]) {
    final selected = _attachmentType == type;
    return Expanded(
      child: GestureDetector(
        onTap:
            onTap ??
            () => setState(() {
              _attachmentType = type;
              _attachmentPath = null;
            }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? AppTheme.primaryColor
                    : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppTheme.primaryColor
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
