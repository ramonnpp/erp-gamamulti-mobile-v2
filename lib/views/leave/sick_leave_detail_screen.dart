import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/database_service.dart';

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

  // Nama file lampiran (dari DB, fallback ke path lokal)
  String get _attachmentName {
    final fromDb = leave['attachment_name']?.toString();
    if (fromDb != null && fromDb.isNotEmpty) return fromDb;
    final p = leave['attachment_path']?.toString();
    if (p != null && p.isNotEmpty) return _fileName(p);
    return 'Lampiran';
  }

  String? get _attachmentMime {
    final m = leave['attachment_mime']?.toString();
    return (m != null && m.isNotEmpty) ? m : null;
  }

  List<int>? get _attachmentBytes {
    final data = leave['attachment_data'];
    if (data != null && data is List) return List<int>.from(data);
    return null;
  }

  int get _attachmentSize {
    final b = _attachmentBytes;
    if (b == null) return 0;
    return b.length;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Ekstensi: MIME dulu, lalu nama file, lalu path lokal
  String get _resolvedExt {
    final mime = _attachmentMime;
    if (mime != null) {
      if (mime == 'application/pdf') return 'pdf';
      if (mime.startsWith('image/')) return mime.split('/').last;
      if (mime == 'application/msword') return 'doc';
      if (mime ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
        return 'docx';
      }
    }
    final e = _ext(_attachmentName);
    if (e.isNotEmpty) return e;
    final p = _ext(leave['attachment_path']?.toString() ?? '');
    if (p.isNotEmpty) return p;
    return 'bin';
  }

  bool get _isImage =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(_resolvedExt);
  bool get _isPdf => _resolvedExt == 'pdf';
  bool get _hasAttachmentData =>
      leave['has_attachment'] == true &&
          (leave['attachment_path'] != null &&
              leave['attachment_path'].toString().isNotEmpty) ||
      (leave['attachment_data'] != null &&
          leave['attachment_data'] is List &&
          (leave['attachment_data'] as List).isNotEmpty);

  IconData get _fileIcon {
    if (_isImage) return Icons.image_outlined;
    if (_isPdf) return Icons.picture_as_pdf_outlined;
    final e = _resolvedExt;
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
    final leaveId = leave['id'] as int?;
    final attachmentData = leave['attachment_data'];

    String? filePath = path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      if (leaveId != null) {
        // Coba ambil dari DB (bytes)
        final fetchedPath = await DatabaseService().getAttachmentFile(
          leaveId: leaveId,
          suggestedName: 'lampiran_$leaveId.pdf',
        );
        if (fetchedPath != null) {
          filePath = fetchedPath;
        }
      }
    }

    if (filePath == null || !await File(filePath).exists()) {
      // Jika tidak ada file di storage, coba render bytes langsung di UI (untuk gambar)
      if (attachmentData != null &&
          attachmentData is List &&
          attachmentData.isNotEmpty) {
        // Bytes tersedia, simpan ke temporary file untuk dibagikan/ditampilkan
        final bytes = Uint8List.fromList(List<int>.from(attachmentData));
        final tmp = await getTemporaryDirectory();
        String ext = _ext(leave['attachment_path']?.toString() ?? '');
        if (ext.isEmpty) {
          // Coba tebak dari MIME type jika ada
          final mime = leave['attachment_mime']?.toString();
          if (mime != null) {
            if (mime == 'application/pdf') {
              ext = 'pdf';
            } else if (mime.startsWith('image/')) {
              ext = mime.split('/').last;
            } else if (mime == 'application/msword') {
              ext = 'doc';
            } else if (mime ==
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
              ext = 'docx';
            } else {
              ext = 'bin';
            }
          } else {
            ext = 'bin';
          }
        }
        filePath = '${tmp.path}/lampiran_$leaveId.$ext';
        final f = File(filePath);
        await f.writeAsBytes(bytes);
      } else {
        if (context.mounted) {
          CustomSnackbar.error(context, 'File tidak ditemukan');
        }
        return;
      }
    }

    if (!await File(filePath).exists()) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'File tidak ditemukan');
      }
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)], text: _fileName(filePath)),
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuka file: $e');
      }
    }
  }

  void _showFullscreenImage(BuildContext context) async {
    final path = leave['attachment_path']?.toString();
    final leaveId = leave['id'] as int?;
    final attachmentData = leave['attachment_data'];

    String? filePath = path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      if (leaveId != null) {
        // Coba ambil dari DB (bytes)
        final fetchedPath = await DatabaseService().getAttachmentFile(
          leaveId: leaveId,
          suggestedName: 'lampiran_$leaveId.jpg',
        );
        if (fetchedPath != null) {
          filePath = fetchedPath;
        }
      }
    }

    // Jika tidak ada file di storage, coba render bytes langsung di UI (untuk gambar)
    if (filePath == null &&
        attachmentData != null &&
        attachmentData is List &&
        attachmentData.isNotEmpty) {
      // Bytes tersedia, simpan ke temporary file untuk ditampilkan
      final bytes = Uint8List.fromList(List<int>.from(attachmentData));
      final tmp = await getTemporaryDirectory();
      String ext = _ext(leave['attachment_path']?.toString() ?? '');
      if (ext.isEmpty) {
        // Coba tebak dari MIME type jika ada
        final mime = leave['attachment_mime']?.toString();
        if (mime != null) {
          if (mime == 'application/pdf') {
            ext = 'pdf';
          } else if (mime.startsWith('image/')) {
            ext = mime.split('/').last;
          } else if (mime == 'application/msword') {
            ext = 'doc';
          } else if (mime ==
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
            ext = 'docx';
          } else {
            ext = 'bin';
          }
        } else {
          ext = 'bin';
        }
      }
      filePath = '${tmp.path}/lampiran_$leaveId.$ext';
      final f = File(filePath);
      await f.writeAsBytes(bytes);
    }

    if (filePath == null || !await File(filePath).exists()) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gambar tidak ditemukan');
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(File(filePath!), fit: BoxFit.contain),
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
    final hasAttachment = _hasAttachmentData;
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
                            if (_isImage) ...[
                              GestureDetector(
                                onTap: () => _showFullscreenImage(context),
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: fileExists
                                      ? Image.file(
                                          File(path),
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : (_attachmentBytes != null
                                            ? Image.memory(
                                                Uint8List.fromList(
                                                  _attachmentBytes!,
                                                ),
                                                height: 220,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                height: 140,
                                                color: const Color(0xFFF1F5F9),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.image_outlined,
                                                    size: 48,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                              )),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                borderRadius: BorderRadius.circular(16),
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
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _fileIcon,
                                      color: _fileColor,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _attachmentName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _fileColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _resolvedExt.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _fileColor,
                                                ),
                                              ),
                                            ),
                                            if (_attachmentSize > 0)
                                              Text(
                                                _formatSize(_attachmentSize),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            const Text(
                                              '•',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              _attachmentBytes != null
                                                  ? 'Tersimpan di Cloud/DB'
                                                  : (fileExists
                                                        ? 'Tersimpan di Perangkat'
                                                        : 'File tidak lokal'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
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
                                onPressed: () => _openFile(context),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _isPdf
                                      ? 'Buka Dokumen PDF'
                                      : (_isImage
                                            ? 'Buka / Bagikan Gambar'
                                            : 'Buka / Bagikan Lampiran'),
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
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tidak ada lampiran surat dokter untuk pengajuan ini.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
