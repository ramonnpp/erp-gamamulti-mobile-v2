import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';

class SickLeaveDetailScreen extends StatelessWidget {
  final Map<String, dynamic> leave;
  const SickLeaveDetailScreen({super.key, required this.leave});

  String _formatDateId(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final d = DateTime.parse(raw.split(' ')[0]);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(d);
    } catch (_) {
      return raw;
    }
  }

  int _durationDays() {
    try {
      final s = DateTime.parse(leave['start_date'].toString().split(' ')[0]);
      final e = DateTime.parse(leave['end_date'].toString().split(' ')[0]);
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
  String _ext(String path) =>
      path.contains('.') ? path.split('.').last.toLowerCase() : '';
  bool get _isImage => [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ].contains(_ext(leave['attachment_path']?.toString() ?? ''));
  bool get _isPdf => _ext(leave['attachment_path']?.toString() ?? '') == 'pdf';

  IconData get _fileIcon {
    if (_isImage) return Icons.image_outlined;
    if (_isPdf) return Icons.picture_as_pdf_outlined;
    final e = _ext(leave['attachment_path']?.toString() ?? '');
    if (e == 'doc' || e == 'docx') return Icons.description_outlined;
    return Icons.attach_file;
  }

  Color get _fileColor {
    if (_isImage) return const Color(0xFF10B981);
    if (_isPdf) return const Color(0xFFEF4444);
    return AppTheme.primaryColor;
  }

  Future<void> _openFile(BuildContext context) async {
    final path = leave['attachment_path']?.toString();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'File tidak ditemukan di perangkat ini');
      }
      return;
    }
    try {
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.error && context.mounted) {
        CustomSnackbar.error(
          context,
          'Tidak dapat membuka file: ${result.message}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuka file: $e');
      }
    }
  }

  void _showFullscreenImage(BuildContext context) {
    final path = leave['attachment_path']?.toString();
    if (path == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachment =
        leave['has_attachment'] == true &&
        leave['attachment_path'] != null &&
        leave['attachment_path'].toString().isNotEmpty;
    final path = leave['attachment_path']?.toString() ?? '';
    final fileExists = hasAttachment && File(path).existsSync();
    final days = _durationDays();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B4A2E), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
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
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leave['leave_type']?.toString() ??
                                        'Izin/Sakit',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$days Hari • ${_formatDateId(leave['start_date']?.toString())}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$days Hari',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _dateCard(),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Alasan',
                  icon: Icons.notes_rounded,
                  child: Text(
                    (leave['reason']?.toString().isNotEmpty ?? false)
                        ? leave['reason'].toString()
                        : 'Tidak ada alasan yang ditulis.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Lampiran Surat Dokter',
                  icon: Icons.attach_file_rounded,
                  trailing: hasAttachment
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Ada Lampiran',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  child: hasAttachment
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isImage && fileExists) ...[
                              GestureDetector(
                                onTap: () => _showFullscreenImage(context),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(path),
                                    height: 240,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.zoom_in_rounded,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ketuk gambar untuk memperbesar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _fileColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _fileIcon,
                                      color: _fileColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fileName(path),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          fileExists
                                              ? 'File tersedia di perangkat'
                                              : 'File tidak ditemukan di perangkat ini',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: fileExists
                                    ? () => _openFile(context)
                                    : null,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _isPdf ? 'Buka PDF' : 'Buka Lampiran',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tidak ada lampiran untuk pengajuan ini.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _dateRow(
            Icons.calendar_today_rounded,
            'Mulai',
            _formatDateId(leave['start_date']?.toString()),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _dateRow(
            Icons.event_rounded,
            'Selesai',
            _formatDateId(leave['end_date']?.toString()),
          ),
          if (leave['created_at'] != null) ...[
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _dateRow(
              Icons.history_rounded,
              'Diajukan',
              _formatDateId(leave['created_at']?.toString()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
