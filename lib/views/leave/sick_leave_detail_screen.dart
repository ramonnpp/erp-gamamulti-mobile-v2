import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/database_service.dart';

class SickLeaveDetailScreen extends StatefulWidget {
  final Map<String, dynamic> leave;
  const SickLeaveDetailScreen({super.key, required this.leave});

  @override
  State<SickLeaveDetailScreen> createState() => _SickLeaveDetailScreenState();
}

class _SickLeaveDetailScreenState extends State<SickLeaveDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ), // Durasi diperlambat sedikit agar animasi lebih terasa
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(
          begin: const Offset(
            0,
            0.15,
          ), // Jarak geser diperbesar agar efek transisinya nyata
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
      final s = DateTime.parse(
        widget.leave['start_date'].toString().split(' ')[0],
      );
      final e = DateTime.parse(
        widget.leave['end_date'].toString().split(' ')[0],
      );
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  String _statusOf(Map<String, dynamic> leave) {
    final now = DateTime.now();
    try {
      final s = DateTime.parse(leave['start_date'].toString().split(' ')[0]);
      final e = DateTime.parse(leave['end_date'].toString().split(' ')[0]);
      if (now.isBefore(s)) return 'Akan Datang';
      if (now.isAfter(e)) return 'Selesai';
      return 'Sedang Berlangsung';
    } catch (_) {
      return 'Selesai';
    }
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
  String _ext(String path) =>
      path.contains('.') ? path.split('.').last.toLowerCase() : '';

  String get _attachmentName {
    final fromDb = widget.leave['attachment_name']?.toString();
    if (fromDb != null && fromDb.isNotEmpty) return fromDb;
    final p = widget.leave['attachment_path']?.toString();
    if (p != null && p.isNotEmpty) return _fileName(p);
    return 'Lampiran';
  }

  String? get _attachmentMime {
    final m = widget.leave['attachment_mime']?.toString();
    return (m != null && m.isNotEmpty) ? m : null;
  }

  List<int>? get _attachmentBytes {
    final data = widget.leave['attachment_data'];
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
    final p = _ext(widget.leave['attachment_path']?.toString() ?? '');
    if (p.isNotEmpty) return p;
    return 'bin';
  }

  bool get _isImage =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(_resolvedExt);
  bool get _isPdf => _resolvedExt == 'pdf';
  bool get _hasAttachmentData =>
      widget.leave['has_attachment'] == true &&
          (widget.leave['attachment_path'] != null &&
              widget.leave['attachment_path'].toString().isNotEmpty) ||
      (widget.leave['attachment_data'] != null &&
          widget.leave['attachment_data'] is List &&
          (widget.leave['attachment_data'] as List).isNotEmpty);

  IconData get _fileIcon {
    if (_isImage) return Icons.image_rounded;
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    final e = _resolvedExt;
    if (e == 'doc' || e == 'docx') return Icons.description_rounded;
    return Icons.attach_file_rounded;
  }

  Color get _fileColor {
    if (_isImage) return const Color(0xFF10B981);
    if (_isPdf) return const Color(0xFFEF4444);
    return AppTheme.primaryColor;
  }

  Future<void> _openFile(BuildContext context) async {
    final path = widget.leave['attachment_path']?.toString();
    final leaveId = widget.leave['id'] as int?;
    final attachmentData = widget.leave['attachment_data'];

    String? filePath = path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      if (leaveId != null) {
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
      if (attachmentData != null &&
          attachmentData is List &&
          attachmentData.isNotEmpty) {
        final bytes = Uint8List.fromList(List<int>.from(attachmentData));
        final tmp = await getTemporaryDirectory();
        String ext = _ext(widget.leave['attachment_path']?.toString() ?? '');
        if (ext.isEmpty) {
          final mime = widget.leave['attachment_mime']?.toString();
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
    final path = widget.leave['attachment_path']?.toString();
    final leaveId = widget.leave['id'] as int?;
    final attachmentData = widget.leave['attachment_data'];

    String? filePath = path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      if (leaveId != null) {
        final fetchedPath = await DatabaseService().getAttachmentFile(
          leaveId: leaveId,
          suggestedName: 'lampiran_$leaveId.jpg',
        );
        if (fetchedPath != null) {
          filePath = fetchedPath;
        }
      }
    }

    if (filePath == null &&
        attachmentData != null &&
        attachmentData is List &&
        attachmentData.isNotEmpty) {
      final bytes = Uint8List.fromList(List<int>.from(attachmentData));
      final tmp = await getTemporaryDirectory();
      String ext = _ext(widget.leave['attachment_path']?.toString() ?? '');
      if (ext.isEmpty) {
        final mime = widget.leave['attachment_mime']?.toString();
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
    final path = widget.leave['attachment_path']?.toString() ?? '';
    final fileExists = hasAttachment && File(path).existsSync();
    final days = _durationDays();
    final status = _statusOf(widget.leave);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HEADER HIJAU TUA MELENGKUNG DENGAN ANIMASI SKALA
              SliverToBoxAdapter(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.95, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 12,
                      20,
                      28,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF064E3B),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Color(0xFF064E3B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.leave['leave_type']?.toString() ??
                              'Sakit / Izin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Total Durasi: $days Hari Kerja',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // KONTEN UTAMA DENGAN EFEK STAGGERED
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // WAKTU PELAKSANAAN
                    const Text(
                      'WAKTU PELAKSANAAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _timeCardRow(
                            Icons.medical_services_rounded,
                            'Mulai Izin / Sakit',
                            _formatDateId(
                              widget.leave['start_date']?.toString(),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _timeCardRow(
                            Icons.event_available_rounded,
                            'Selesai Izin / Sakit',
                            _formatDateId(widget.leave['end_date']?.toString()),
                          ),
                          if (widget.leave['created_at'] != null) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 16, bottom: 4),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Diajukan Pada',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatDateId(
                                    widget.leave['created_at']?.toString(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CATATAN / ALASAN
                    const Text(
                      'CATATAN / ALASAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        (widget.leave['reason']?.toString().isNotEmpty ?? false)
                            ? widget.leave['reason'].toString()
                            : 'Tidak ada catatan alasan yang dilampirkan.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LAMPIRAN SURAT DOKTER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LAMPIRAN SURAT DOKTER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (hasAttachment)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Ada Lampiran',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: fileExists
                                          ? Image.file(
                                              File(path),
                                              height: 200,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : (_attachmentBytes != null
                                                ? Image.memory(
                                                    Uint8List.fromList(
                                                      _attachmentBytes!,
                                                    ),
                                                    height: 200,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    height: 120,
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.image_outlined,
                                                        size: 40,
                                                        color: Color(
                                                          0xFF94A3B8,
                                                        ),
                                                      ),
                                                    ),
                                                  )),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Center(
                                    child: Text(
                                      'Ketuk gambar untuk memperbesar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _fileColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                              _attachmentName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  _resolvedExt.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _fileColor,
                                                  ),
                                                ),
                                                if (_attachmentSize > 0) ...[
                                                  const Text(
                                                    ' • ',
                                                    style: TextStyle(
                                                      color: Color(0xFF94A3B8),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatSize(
                                                      _attachmentSize,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                                      backgroundColor: const Color(0xFF064E3B),
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
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tidak ada lampiran surat dokter untuk pengajuan ini.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
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
        ),
      ),
    );
  }

  Widget _timeCardRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF064E3B), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
