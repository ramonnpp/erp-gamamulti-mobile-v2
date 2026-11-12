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

class _SickLeaveFormDialogState extends State<SickLeaveFormDialog> {
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _date;
  String _duration = '1 Hari';
  bool _isSubmitting = false;
  String? _attachmentPath;
  Uint8List? _attachmentBytes;
  String _attachmentType = 'none';

  String? _errorDate;
  String? _errorReason;

  Future<String?> _copyToAppDir(String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final dest = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (sourcePath != dest.path) {
        await File(sourcePath).copy(dest.path);
      }
      // Baca bytes untuk disimpan ke DB
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
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(d);
  }

  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Pengajuan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
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
              'Data yang sudah dikirim tidak dapat dihapus atau diedit. Pastikan data sudah benar.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _confirmRow(Icons.calendar_today_rounded, 'Tanggal', _fmt(_date)),
            _confirmRow(Icons.schedule_rounded, 'Durasi', _duration),
            _confirmRow(
              Icons.attach_file_rounded,
              'Lampiran',
              _attachmentType == 'none'
                  ? 'Tanpa lampiran'
                  : _attachmentPath?.split('/').last ?? '-',
            ),
            if (_reasonController.text.trim().isNotEmpty)
              _confirmRow(
                Icons.notes_rounded,
                'Alasan',
                _reasonController.text.trim(),
              ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Tidak',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ya, Kirim',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _errorDate = _date == null ? 'Tanggal wajib dipilih' : null;
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
    int days = int.tryParse(_duration.split(' ')[0]) ?? 1;
    DateTime endDate = _date!.add(Duration(days: days - 1));

    final bool hasAttachment = _attachmentType != 'none';
    final String? pathToSubmit = hasAttachment ? _attachmentPath : null;

    // Pastikan bytes lampiran selalu terisi sebelum kirim ke DB.
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
          leaveType: 'Sakit/Izin',
          startDate: _date.toString().split(' ')[0],
          endDate: endDate.toString().split(' ')[0],
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
      CustomSnackbar.success(context, 'Laporan izin/sakit berhasil disimpan!');
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.error(context, 'Gagal menyimpan ke database');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B4A2E), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporkan Izin / Sakit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Isi data dengan benar, tidak dapat diubah',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      'Tanggal Izin / Sakit',
                      Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 7),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _date = picked;
                            _errorDate = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _errorDate != null
                                ? AppTheme.errorColor
                                : const Color(0xFFE2E8F0),
                          ),
                          color: _date != null
                              ? AppTheme.primaryColor.withValues(alpha: 0.05)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _fmt(_date),
                                style: TextStyle(
                                  color: _date != null
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontWeight: _date != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_errorDate != null) _errorText(_errorDate!),
                    const SizedBox(height: 16),

                    _label('Durasi', Icons.schedule_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['1 Hari', '2 Hari', '3 Hari', 'Lainnya'].map((
                        dur,
                      ) {
                        final selected = _duration == dur;
                        return GestureDetector(
                          onTap: () => setState(() => _duration = dur),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: selected
                                  ? AppTheme.primaryColor
                                  : Colors.white,
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              dur,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _label('Alasan / Keterangan', Icons.notes_rounded),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      onChanged: (_) => setState(() => _errorReason = null),
                      decoration: InputDecoration(
                        hintText:
                            'Jelaskan alasan izin atau kondisi sakit Anda',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _errorReason != null
                                ? AppTheme.errorColor
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _errorReason != null
                                ? AppTheme.errorColor
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    if (_errorReason != null) _errorText(_errorReason!),
                    const SizedBox(height: 16),

                    _label(
                      'Lampiran Dokter (Opsional)',
                      Icons.attach_file_rounded,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _attachOption('none', Icons.close_rounded, 'Tanpa'),
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
                              final saved = await _copyToAppDir(photo.path);
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
                              final saved = await _copyToAppDir(photo.path);
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
                            final result = await FilePicker.pickFiles(
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
                            if (result.isNotEmpty &&
                                result.first.path != null) {
                              final saved = await _copyToAppDir(
                                result.first.path!,
                              );
                              setState(() {
                                _attachmentType = 'file';
                                _attachmentPath = saved;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_attachmentPath != null &&
                        _attachmentPath!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _attachmentPath!.split('/').last,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
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
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data tidak dapat dihapus atau diedit setelah dikirim.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
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
                              'Kirim',
                              style: TextStyle(
                                fontSize: 15,
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
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 4),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w500,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : Colors.white,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
