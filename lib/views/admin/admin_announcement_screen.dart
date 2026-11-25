import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/admin_database_service.dart';
import '../../widgets/custom_snackbar.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() =>
      _AdminAnnouncementScreenState();
}

enum _AnnStatus { scheduled, active, expired }

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  _AnnStatus? _activeFilter;

  // Stats counters
  int _statTotal = 0;
  int _statScheduled = 0;
  int _statActive = 0;
  int _statExpired = 0;

  static const _categories = ['Umum', 'Penting', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await AdminDatabaseService().getAllAnnouncements();
      if (!mounted) return;
      final enriched = list.map((a) {
        a['_computedStatus'] = _computeStatus(
          a['published_at'],
          a['expired_at'],
        );
        return a;
      }).toList();
      _announcements.clear();
      _announcements.addAll(enriched);
      _refreshStats();
    } catch (e) {
      debugPrint('Error load announcements: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _AnnStatus _computeStatus(dynamic pub, dynamic exp) {
    final now = DateTime.now();
    final published = _parseDateTime(pub);
    final expired = _parseDateTime(exp);

    if (published != null && now.isBefore(published)) {
      return _AnnStatus.scheduled;
    }
    if (expired != null && now.isAfter(expired)) {
      return _AnnStatus.expired;
    }
    return _AnnStatus.active;
  }

  /// Parse nilai tanggal dari database (String / DateTime) lengkap dengan jam.
  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    final str = raw.toString().trim();
    if (str.isEmpty) {
      return null;
    }
    final d = DateTime.tryParse(str.replaceFirst(' ', 'T'));
    if (d == null) {
      return null;
    }
    // Nilai di database adalah jam apa adanya (WIB): buang penanda UTC/Z
    // supaya tidak bergeser 7 jam.
    return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }

  void _refreshStats() {
    _statTotal = _announcements.length;
    _statScheduled = _announcements
        .where((a) => a['_computedStatus'] == _AnnStatus.scheduled)
        .length;
    _statActive = _announcements
        .where((a) => a['_computedStatus'] == _AnnStatus.active)
        .length;
    _statExpired = _announcements
        .where((a) => a['_computedStatus'] == _AnnStatus.expired)
        .length;
  }

  String _formatDateStr(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final d = _parseDateTime(raw);
      if (d == null) return raw;
      return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(d);
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(_AnnStatus s) {
    switch (s) {
      case _AnnStatus.scheduled:
        return const Color(0xFF4338CA);
      case _AnnStatus.active:
        return const Color(0xFF15803D);
      case _AnnStatus.expired:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(_AnnStatus s) {
    switch (s) {
      case _AnnStatus.scheduled:
        return 'Terjadwal';
      case _AnnStatus.active:
        return 'Aktif Beredar';
      case _AnnStatus.expired:
        return 'Berakhir';
    }
  }

  // ========== SHOW ADD DIALOG ==========
  Future<void> _showAddDialog() async {
    await _showAnnouncementForm(null);
  }

  // ========== SHOW EDIT DIALOG ==========
  Future<void> _showEditDialog(Map<String, dynamic> ann) async {
    await _showAnnouncementForm(ann);
  }

  // ========== ANNOUNCEMENT FORM DIALOG ==========
  Future<void> _showAnnouncementForm(Map<String, dynamic>? ann) async {
    final isEdit = ann != null;
    final titleCtrl = TextEditingController(
      text: ann?['title']?.toString() ?? '',
    );
    final contentCtrl = TextEditingController(
      text: ann?['content']?.toString() ?? '',
    );
    final categoryCtrl = TextEditingController(
      text: ann?['category']?.toString() ?? 'Umum',
    );

    final now = DateTime.now();
    final initPub = _parseDateTime(ann?['published_at']) ?? now;
    final initExp =
        _parseDateTime(ann?['expired_at']) ?? now.add(const Duration(days: 7));

    DateTime selPub = initPub;
    DateTime selExp = initExp;
    TimeOfDay timePub = TimeOfDay.fromDateTime(selPub);
    TimeOfDay timeExp = TimeOfDay.fromDateTime(selExp);
    bool loading = false;
    String? formError;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDS) {
            Future<void> pickPublish() async {
              final dp = await showDatePicker(
                context: dialogCtx,
                initialDate: selPub.isBefore(DateTime(2020))
                    ? DateTime(2020)
                    : selPub,
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (dp != null && dialogCtx.mounted) {
                setDS(() => selPub = dp);
                final tp = await showTimePicker(
                  context: dialogCtx,
                  initialTime: timePub,
                );
                if (tp != null && dialogCtx.mounted) {
                  setDS(() {
                    timePub = tp;
                    selPub = DateTime(
                      dp.year,
                      dp.month,
                      dp.day,
                      tp.hour,
                      tp.minute,
                    );
                  });
                }
              }
            }

            Future<void> pickExpiry() async {
              final dp = await showDatePicker(
                context: dialogCtx,
                initialDate: selExp.isBefore(selPub) ? selPub : selExp,
                firstDate: DateTime(selPub.year, selPub.month, selPub.day),
                lastDate: DateTime(2040),
              );
              if (dp != null && dialogCtx.mounted) {
                setDS(() => selExp = dp);
                final tp = await showTimePicker(
                  context: dialogCtx,
                  initialTime: timeExp,
                );
                if (tp != null && dialogCtx.mounted) {
                  setDS(() {
                    timeExp = tp;
                    selExp = DateTime(
                      dp.year,
                      dp.month,
                      dp.day,
                      tp.hour,
                      tp.minute,
                    );
                  });
                }
              }
            }

            Future<void> submit() async {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              final category = categoryCtrl.text.trim();

              if (title.isEmpty || content.isEmpty) {
                setDS(
                  () => formError = 'Judul dan isi pengumuman wajib diisi.',
                );
                return;
              }
              if (selExp.isBefore(selPub)) {
                setDS(
                  () => formError =
                      'Tanggal berakhir harus setelah tanggal mulai beredar.',
                );
                return;
              }
              setDS(() => loading = true);

              final currentAdmin = DatabaseService().getCurrentUser();
              final createdBy = currentAdmin?['id'] as int? ?? 1;

              bool ok;
              if (isEdit) {
                ok = await AdminDatabaseService().updateAnnouncement(
                  announcementId: ann['id'],
                  updatedBy: createdBy,
                  title: title,
                  content: content,
                  category: category.isNotEmpty ? category : null,
                  publishedAt: selPub,
                  expiredAt: selExp,
                );
              } else {
                ok = await AdminDatabaseService().createAnnouncement(
                  createdBy: createdBy,
                  title: title,
                  content: content,
                  category: category.isNotEmpty ? category : null,
                  publishedAt: selPub,
                  expiredAt: selExp,
                );
              }

              if (!dialogCtx.mounted) return;
              setDS(() => loading = false);
              if (ok) {
                Navigator.pop(dialogCtx, true);
                if (mounted) {
                  CustomSnackbar.success(
                    context,
                    isEdit
                        ? 'Pengumuman berhasil diperbarui'
                        : 'Pengumuman baru berhasil ditambahkan',
                  );
                }
              } else {
                setDS(() => formError = 'Gagal menyimpan pengumuman.');
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(dialogCtx).padding.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.add_circle_outline_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit
                                ? 'Edit Pengumuman'
                                : 'Tambah Pengumuman Baru',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
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
                                formError!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: titleCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Judul Pengumuman *',
                        labelStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        hintText: 'Masukkan judul pengumuman',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Isi Pengumuman *',
                        labelStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        hintText: 'Tulis isi pengumuman...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Kategori / Prioritas',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: categoryCtrl.text,
                          isExpanded: true,
                          items: [..._categories]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => categoryCtrl.text = v ?? 'Umum',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Tanggal & Jam Mulai Beredar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: pickPublish,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(selPub)}  ${timePub.format(context)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Tanggal & Jam Berakhir',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: pickExpiry,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_busy_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(selExp)}  ${timeExp.format(context)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            child: const Text('Batal'),
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
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEdit
                                        ? 'Simpan Perubahan'
                                        : 'Tambah Pengumuman',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ========== DELETE CONFIRM ==========
  Future<void> _showDeleteConfirm(Map<String, dynamic> ann) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.errorColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hapus Pengumuman',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus pengumuman "${ann['title']}"?\nTindakan ini akan dicatat ke audit log.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Ya, Hapus',
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

    if (confirmed == true) {
      final currentAdmin = DatabaseService().getCurrentUser();
      final adminId = currentAdmin?['id'] as int? ?? 1;
      final ok = await AdminDatabaseService().deleteAnnouncement(
        announcementId: ann['id'],
        deletedByUserId: adminId,
      );
      if (!mounted) return;
      if (ok) {
        CustomSnackbar.success(context, 'Pengumuman berhasil dihapus');
        _loadData();
      } else {
        CustomSnackbar.error(context, 'Gagal menghapus pengumuman');
      }
    }
  }

  // ========== BUILD CARD ==========
  Widget _buildAnnouncementCard(Map<String, dynamic> ann) {
    final title = ann['title']?.toString() ?? '';
    final content = ann['content']?.toString() ?? '';
    final category = (ann['category'] as String?) ?? 'Umum';
    final status = ann['_computedStatus'] as _AnnStatus;
    final pubDate = _formatDateStr(ann['published_at']);
    final expDate = _formatDateStr(ann['expired_at']);
    final createdDate = _formatDateStr(ann['created_at']);
    final preview = content.length > 60
        ? '${content.substring(0, 60)}...'
        : content;
    final statusColor = _statusColor(status);
    final bgTint = category == 'Penting'
        ? const Color(0xFFFFEDED)
        : category == 'Urgent'
        ? const Color(0xFFFFF7ED)
        : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == _AnnStatus.active)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (status == _AnnStatus.active) const SizedBox(width: 5),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              preview,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _dateChip(Icons.schedule_outlined, 'Mulai', pubDate),
                _dateChip(Icons.event_busy_rounded, 'Berakhir', expDate),
                _dateChip(Icons.access_time, 'Dibuat', createdDate),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(ann),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirm(ann),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text(
                    'Hapus',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ========== STATS ROW ==========
  Widget _statsRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statBadge('Total', '$_statTotal', Colors.white),
          _statBadge('Terjadwal', '$_statScheduled', const Color(0xFF4338CA)),
          _statBadge('Aktif', '$_statActive', const Color(0xFF15803D)),
          _statBadge('Berakhir', '$_statExpired', const Color(0xFF6B7280)),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String count, Color color) {
    return Column(
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
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ========== FILTER CHIPS ==========
  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: _activeFilter == null,
            onSelected: (_) => setState(() => _activeFilter = null),
            selectedColor: AppTheme.primaryColor,
            checkmarkColor: Colors.white,
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _activeFilter == null
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          ...[
            (_AnnStatus.scheduled, 'Terjadwal', _statScheduled),
            (_AnnStatus.active, 'Aktif', _statActive),
            (_AnnStatus.expired, 'Berakhir', _statExpired),
          ].map((t) {
            final (status, label, count) = t;
            final isSelected = _activeFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$label ($count)'),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _activeFilter = isSelected ? null : status),
                selectedColor: _statusColor(status),
                checkmarkColor: Colors.white,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ========== EMPTY STATE ==========
  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'Belum ada pengumuman.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== MAIN BUILD ==========
  @override
  Widget build(BuildContext context) {
    final filtered = _activeFilter != null
        ? _announcements
              .where((a) => a['_computedStatus'] == _activeFilter)
              .toList()
        : _announcements;

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
                'Kelola Pengumuman',
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
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              const SizedBox(height: 8),
              _filterChips(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_announcements.isEmpty)
                _emptyState()
              else if (filtered.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(
                    child: Text(
                      'Tidak ada pengumuman dengan status tersebut.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((ann) => _buildAnnouncementCard(ann)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // Sama dengan tombol di sick_leave_history_screen (bottom: 88).
        padding: const EdgeInsets.only(bottom: 88.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await _showAddDialog();
            if (mounted) _loadData();
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 6,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Tambah Pengumuman',
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
