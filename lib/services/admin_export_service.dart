import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_service.dart';
import '../widgets/custom_snackbar.dart';

/// Export service khusus Admin — terpisah dari [ExportService] agar bisa
/// menerapkan [_ensureAdmin] di setiap metode.
class AdminExportService {
  // ---------- Guard ----------

  void _ensureAdmin() {
    final currentUser = DatabaseService().getCurrentUser();
    if (currentUser == null || currentUser['role']?.toString().toLowerCase() != 'admin') {
      throw Exception('Akses ditolak: hanya admin yang dapat mengakses export ini.');
    }
  }

  // ---------- Helper statics (mirip ExportService) ----------

  static String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    return '"$s"';
  }

  static String _s(Map<String, dynamic> r, String key) =>
      r[key]?.toString() ?? '';

  static Uint8List _csvBytes(StringBuffer sb) {
    return Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(sb.toString()),
    ]);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}${_two(n.month)}${_two(n.day)}_'
        '${_two(n.hour)}${_two(n.minute)}${_two(n.second)}';
  }

  static Future<void> _saveToDownloads(
    BuildContext context, {
    required Uint8List bytes,
    required String baseName,
    required String ext,
  }) async {
    try {
      final name = '${baseName}_${_stamp()}.$ext';
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(data: bytes, fileName: name),
      );
      if (!context.mounted) return;
      if (savedPath == null) {
        CustomSnackbar.error(context, 'Penyimpanan dibatalkan');
        return;
      }
      CustomSnackbar.success(context, 'Tersimpan: $name');
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal export: $e');
      }
    }
  }

  static Future<void> _exportCsv(
    BuildContext context, {
    required String title,
    required String userName,
    required List<String> headers,
    required List<List<String>> rows,
    required String baseName,
  }) async {
    final sb = StringBuffer();
    sb.writeln('$title - $userName');
    sb.writeln(headers.join(','));
    for (final r in rows) {
      sb.writeln(r.map(_csvEscape).join(','));
    }
    await _saveToDownloads(
      context,
      bytes: _csvBytes(sb),
      baseName: baseName,
      ext: 'csv',
    );
  }

  static Future<void> _exportPdf(
    BuildContext context, {
    required String title,
    required String userName,
    required List<String> headers,
    required List<List<String>> rows,
    required String baseName,
  }) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Admin: $userName'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _saveToDownloads(
        context,
        bytes: bytes,
        baseName: baseName,
        ext: 'pdf',
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuat PDF: $e');
      }
    }
  }

  static bool _empty(BuildContext context, List data) {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return true;
    }
    return false;
  }

  // ------------------------------ Presensi Semua Karyawan ------------------------------

  static const _allAttHeaders = [
    'Nama Karyawan',
    'Jabatan',
    'Tanggal',
    'Hari',
    'Check In',
    'Check Out',
    'Durasi',
    'Status',
  ];

  static List<List<String>> _allAttRows(List<Map<String, dynamic>> d) => d
      .map(
        (r) => [
          _s(r, 'user_name'),
          _s(r, 'user_role'),
          _s(r, 'date'),
          _s(r, 'day'),
          _s(r, 'checkIn'),
          _s(r, 'checkOut'),
          _s(r, 'duration'),
          _s(r, 'status'),
        ],
      )
      .toList();

  /// Export PDF rekap presensi semua karyawan.
  Future<void> exportAllAttendancePdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Rekap Presensi Semua Karyawan',
      userName: userName,
      headers: _allAttHeaders,
      rows: _allAttRows(data),
      baseName: 'rekap_presensi_semua_karyawan',
    );
  }

  /// Export CSV rekap presensi semua karyawan.
  Future<void> exportAllAttendanceCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Rekap Presensi Semua Karyawan',
      userName: userName,
      headers: _allAttHeaders,
      rows: _allAttRows(data),
      baseName: 'rekap_presensi_semua_karyawan',
    );
  }

  // ----------------------------- Izin / Sakit / Cuti Semua Karyawan -----------------------------

  static const _allLeavesHeaders = [
    'Nama Karyawan',
    'Jabatan',
    'Jenis',
    'Mulai',
    'Selesai',
    'Alasan',
    'Status',
  ];

  static List<List<String>> _allLeavesRows(
    List<Map<String, dynamic>> d,
    String Function(Map<String, dynamic>) statusOf,
  ) => d
      .map(
        (r) => [
          _s(r, 'user_name'),
          _s(r, 'user_role'),
          _s(r, 'leave_type'),
          _s(r, 'start_date'),
          _s(r, 'end_date'),
          _s(r, 'reason'),
          statusOf(r),
        ],
      )
      .toList();

  /// Export PDF rekap izin/sakit/cuti semua karyawan.
  Future<void> exportAllLeavesPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Rekap Izin/Sakit/Cuti Semua Karyawan',
      userName: userName,
      headers: _allLeavesHeaders,
      rows: _allLeavesRows(data, statusOf),
      baseName: 'rekap_izin_semua_karyawan',
    );
  }

  /// Export CSV rekap izin/sakit/cuti semua karyawan.
  Future<void> exportAllLeavesCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Rekap Izin/Sakit/Cuti Semua Karyawan',
      userName: userName,
      headers: _allLeavesHeaders,
      rows: _allLeavesRows(data, statusOf),
      baseName: 'rekap_izin_semua_karyawan',
    );
  }

  // --------------------------- Log Aktivitas Semua Karyawan ---------------------------

  static const _allLogHeaders = [
    'Nama Karyawan',
    'Jabatan',
    'Tanggal',
    'Log',
    'Dibuat Pada',
  ];

  static List<List<String>> _allLogRows(List<Map<String, dynamic>> d) => d
      .map(
        (r) => [
          _s(r, 'user_name'),
          _s(r, 'user_role'),
          _s(r, 'activity_date'),
          _s(r, 'log'),
          _s(r, 'created_at'),
        ],
      )
      .toList();

  /// Export PDF rekap log aktivitas semua karyawan.
  Future<void> exportAllActivityLogsPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Rekap Log Aktivitas Semua Karyawan',
      userName: userName,
      headers: _allLogHeaders,
      rows: _allLogRows(data),
      baseName: 'rekap_log_aktivitas_semua_karyawan',
    );
  }

  /// Export CSV rekap log aktivitas semua karyawan.
  Future<void> exportAllActivityLogsCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    _ensureAdmin();
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Rekap Log Aktivitas Semua Karyawan',
      userName: userName,
      headers: _allLogHeaders,
      rows: _allLogRows(data),
      baseName: 'rekap_log_aktivitas_semua_karyawan',
    );
  }
}
