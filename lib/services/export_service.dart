import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/custom_snackbar.dart';

class ExportService {
  static String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    return '"$s"';
  }

  static String _s(Map<String, dynamic> r, String key) =>
      r[key]?.toString() ?? '';

  /// CSV dengan BOM UTF-8 supaya Excel membaca karakter dengan benar.
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

  /// Simpan lewat dialog "Simpan sebagai" Android (pilih folder, mis. Download).
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
            pw.Text('Karyawan: $userName'),
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

  // ------------------------------ Presensi ------------------------------

  static const _attHeaders = [
    'Tanggal',
    'Hari',
    'Check In',
    'Check Out',
    'Durasi',
    'Status',
  ];

  static List<List<String>> _attRows(List<Map<String, dynamic>> d) => d
      .map(
        (r) => [
          _s(r, 'date'),
          _s(r, 'day'),
          _s(r, 'checkIn'),
          _s(r, 'checkOut'),
          _s(r, 'duration'),
          _s(r, 'status'),
        ],
      )
      .toList();

  static Future<void> exportAttendanceCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'History Presensi',
      userName: userName,
      headers: _attHeaders,
      rows: _attRows(data),
      baseName: 'history_presensi',
    );
  }

  static Future<void> exportAttendancePdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'History Presensi',
      userName: userName,
      headers: _attHeaders,
      rows: _attRows(data),
      baseName: 'history_presensi',
    );
  }

  // ----------------------------- Izin / Sakit ----------------------------

  static const _sickHeaders = [
    'Jenis',
    'Mulai',
    'Selesai',
    'Alasan',
    'Lampiran',
  ];

  static List<List<String>> _sickRows(List<Map<String, dynamic>> d) => d
      .map(
        (r) => [
          _s(r, 'leave_type'),
          _s(r, 'start_date'),
          _s(r, 'end_date'),
          _s(r, 'reason'),
          r['has_attachment'] == true ? 'Ada' : 'Tidak',
        ],
      )
      .toList();

  static Future<void> exportSickCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Riwayat Izin/Sakit',
      userName: userName,
      headers: _sickHeaders,
      rows: _sickRows(data),
      baseName: 'riwayat_izin_sakit',
    );
  }

  static Future<void> exportSickPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Riwayat Izin / Sakit',
      userName: userName,
      headers: _sickHeaders,
      rows: _sickRows(data),
      baseName: 'riwayat_izin_sakit',
    );
  }

  // -------------------------------- Cuti ---------------------------------

  static const _leaveHeaders = [
    'Jenis',
    'Mulai',
    'Selesai',
    'Alasan',
    'Status',
  ];

  static List<List<String>> _leaveRows(
    List<Map<String, dynamic>> d,
    String Function(Map<String, dynamic>) statusOf,
  ) => d
      .map(
        (r) => [
          _s(r, 'leave_type'),
          _s(r, 'start_date'),
          _s(r, 'end_date'),
          _s(r, 'reason'),
          statusOf(r),
        ],
      )
      .toList();

  static Future<void> exportLeaveCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Riwayat Cuti',
      userName: userName,
      headers: _leaveHeaders,
      rows: _leaveRows(data, statusOf),
      baseName: 'riwayat_cuti',
    );
  }

  static Future<void> exportLeavePdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Riwayat Cuti',
      userName: userName,
      headers: _leaveHeaders,
      rows: _leaveRows(data, statusOf),
      baseName: 'riwayat_cuti',
    );
  }

  // --------------------------- Log Aktivitas -----------------------------

  static const _logHeaders = ['Tanggal', 'Log', 'Dibuat Pada'];

  static List<List<String>> _logRows(List<Map<String, dynamic>> d) => d
      .map((r) => [_s(r, 'activity_date'), _s(r, 'log'), _s(r, 'created_at')])
      .toList();

  static Future<void> exportActivityLogsCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportCsv(
      context,
      title: 'Log Aktivitas',
      userName: userName,
      headers: _logHeaders,
      rows: _logRows(data),
      baseName: 'log_aktivitas',
    );
  }

  static Future<void> exportActivityLogsPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (_empty(context, data)) return;
    await _exportPdf(
      context,
      title: 'Log Aktivitas',
      userName: userName,
      headers: _logHeaders,
      rows: _logRows(data),
      baseName: 'log_aktivitas',
    );
  }
}
