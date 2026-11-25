import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../widgets/custom_snackbar.dart';

/// Halaman detail pengumuman (dibuka dari kartu pengumuman di Home).
/// Desain & animasi mengikuti Home: header hijau melengkung + kartu yang
/// muncul berurutan (fade + slide) + efek tekan pada elemen yang bisa diketuk.
class AnnounceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> announcement;

  const AnnounceDetailScreen({super.key, required this.announcement});

  /// Transisi halaman: fade + geser naik halus (dipakai Navigator.push).
  static Route<void> route(Map<String, dynamic> announcement) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          AnnounceDetailScreen(announcement: announcement),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AnnounceDetailScreen> createState() => _AnnounceDetailScreenState();
}

class _AnnounceDetailScreenState extends State<AnnounceDetailScreen> {
  Map<String, dynamic>? _attachment; // cache hasil fetch {name, mime, bytes}
  bool _loadingAttachment = false;
  bool _attachmentFailed = false;
  bool _copied = false;
  Timer? _copiedTimer;

  Map<String, dynamic> get _a => widget.announcement;
  String get _title => _a['title']?.toString() ?? 'Pengumuman';
  String get _content => _a['content']?.toString() ?? '';
  String get _category => _a['category']?.toString() ?? 'Umum';
  String? get _attachName {
    final n = _a['attachment_name']?.toString();
    return (n == null || n.isEmpty) ? null : n;
  }

  String get _attachMime => _a['attachment_mime']?.toString() ?? '';
  bool get _hasAttachment => _attachName != null;
  bool get _isImage => _attachMime.startsWith('image/');

  @override
  void initState() {
    super.initState();
    // Gambar langsung ditampilkan sebagai pratinjau.
    if (_hasAttachment && _isImage) _fetchAttachment();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------
  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final d = DateTime.tryParse(str.replaceFirst(' ', 'T'));
    if (d == null) return null;
    // Jam di database adalah WIB apa adanya: buang penanda UTC/Z.
    return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }

  String _fmt(dynamic raw) {
    final d = _parseDateTime(raw);
    if (d == null) return '-';
    return DateFormat('EEEE, dd MMMM yyyy • HH:mm', 'id_ID').format(d);
  }

  Color get _categoryColor {
    switch (_category) {
      case 'Urgent':
        return const Color(0xFFDC2626);
      case 'Penting':
        return const Color(0xFFEA580C);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _fileIcon {
    if (_isImage) return Icons.image_outlined;
    if (_attachMime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.description_outlined;
  }

  Uint8List? _toBytes(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(List<int>.from(raw));
    return null;
  }

  // ---------- Lampiran ----------
  Future<Map<String, dynamic>?> _fetchAttachment() async {
    if (_attachment != null) return _attachment;
    if (_loadingAttachment) return null;
    setState(() {
      _loadingAttachment = true;
      _attachmentFailed = false;
    });
    final data = await DatabaseService().getAnnouncementAttachment(
      _a['id'] as int,
    );
    if (!mounted) return null;
    final bytes = _toBytes(data?['bytes']);
    setState(() {
      _loadingAttachment = false;
      if (bytes != null && bytes.isNotEmpty) {
        _attachment = {...data!, 'bytes': bytes};
      } else {
        _attachmentFailed = true;
      }
    });
    return _attachment;
  }

  Future<void> _openAttachment() async {
    if (_loadingAttachment) return;
    final data = await _fetchAttachment();
    if (!mounted) return;
    if (data == null) {
      CustomSnackbar.error(context, 'Lampiran tidak dapat dimuat');
      return;
    }
    final bytes = data['bytes'] as Uint8List;
    final name = (data['name'] ?? _attachName ?? 'lampiran').toString();

    if (_isImage) {
      _showImageViewer(bytes);
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        CustomSnackbar.error(
          context,
          'Tidak ada aplikasi untuk membuka file ini',
        );
      }
    } catch (e) {
      debugPrint('Open attachment failed: $e');
      if (mounted) CustomSnackbar.error(context, 'Gagal membuka lampiran');
    }
  }

  void _showImageViewer(Uint8List bytes) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, a1, a2) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
      transitionBuilder: (ctx, anim, a2, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: '$_title\n\n$_content'));
    CustomSnackbar.success(context, 'Teks pengumuman berhasil disalin');
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  // ---------- UI: komponen ----------
  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon),
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 10,
        20,
        20,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -10),
            child: child,
          ),
        ),
        child: Row(
          children: [
            _headerButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Kembali',
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Detail Pengumuman',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            _headerButton(
              icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
              tooltip: 'Salin teks',
              onTap: _copyText,
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu dengan header abu-abu + garis aksen (sama seperti kartu di Home).
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFDCE3EC))),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
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
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kartu 1: kategori, judul, waktu
  Widget _titleCard() {
    final color = _categoryColor;
    final expired = _a['expired_at'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge kategori "pop" masuk
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(
              scale: v,
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _category,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppTheme.textPrimary,
            ),
          ),
          const Divider(height: 26, color: Color(0xFFE2E8F0)),
          _metaRow(
            Icons.schedule_outlined,
            'Diterbitkan',
            _fmt(_a['published_at'] ?? _a['created_at']),
          ),
          if (_parseDateTime(expired) != null)
            _metaRow(Icons.event_busy_rounded, 'Berlaku s/d', _fmt(expired)),
        ],
      ),
    );
  }

  // Kartu 2: isi pengumuman
  Widget _contentCard() {
    return _sectionCard(
      title: 'Isi Pengumuman',
      child: SelectableText(
        _content.isEmpty ? '-' : _content,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.65,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  // Kartu 3: lampiran
  Widget _attachmentCard() {
    final preview = _attachment != null
        ? _attachment!['bytes'] as Uint8List
        : null;

    final String statusText = _attachmentFailed
        ? 'Gagal memuat • ketuk untuk coba lagi'
        : (_isImage ? 'Ketuk untuk memperbesar' : 'Ketuk untuk membuka');

    return _sectionCard(
      title: 'Lampiran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pratinjau gambar: tinggi menyesuaikan halus + fade
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: (_isImage && preview != null)
                  ? Padding(
                      key: const ValueKey('img'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PressScaleTile(
                        onTap: () => _showImageViewer(preview),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            preview,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  : (_isImage && _loadingAttachment)
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
          _PressScaleTile(
            onTap: _openAttachment,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _fileIcon,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachName!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            statusText,
                            key: ValueKey(statusText),
                            style: TextStyle(
                              fontSize: 11,
                              color: _attachmentFailed
                                  ? AppTheme.errorColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: (_loadingAttachment && !_isImage)
                        ? const SizedBox(
                            key: ValueKey('spin'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.open_in_new_rounded,
                            key: ValueKey('open'),
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Column(
          children: [
            _header(context),
            Expanded(
              child: Container(
                color: const Color(0xFFE4EAF1),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    _AnimatedDashboardBlock(delayMs: 50, child: _titleCard()),
                    const SizedBox(height: 16),
                    _AnimatedDashboardBlock(
                      delayMs: 140,
                      child: _contentCard(),
                    ),
                    if (_hasAttachment) ...[
                      const SizedBox(height: 16),
                      _AnimatedDashboardBlock(
                        delayMs: 230,
                        child: _attachmentCard(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Animasi yang sama persis dengan Home ----------

/// Blok muncul berurutan: fade + slide naik tipis.
class _AnimatedDashboardBlock extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedDashboardBlock({required this.delayMs, required this.child});

  @override
  State<_AnimatedDashboardBlock> createState() =>
      _AnimatedDashboardBlockState();
}

class _AnimatedDashboardBlockState extends State<_AnimatedDashboardBlock> {
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

/// Efek mengecil sedikit saat ditekan.
class _PressScaleTile extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressScaleTile({required this.onTap, required this.child});

  @override
  State<_PressScaleTile> createState() => _PressScaleTileState();
}

class _PressScaleTileState extends State<_PressScaleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
