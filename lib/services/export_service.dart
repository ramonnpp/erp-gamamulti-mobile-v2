import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_snackbar.dart';

class ExportService {
  static String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    return '"$s"';
  }

  static Future<void> _saveToDownloads(
    BuildContext context,
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        if (context.mounted) {
          CustomSnackbar.error(context, 'Folder Download tidak tersedia');
        }
        return;
      }
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      CustomSnackbar.success(context, 'Tersimpan: ${file.path}');
      // Buka via share sheet agar user pilih app (hindari freeze open_filex)
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: filename),
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal export: $e');
      }
    }
  }

  static Future<void> exportAttendanceCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    final sb = StringBuffer();
    sb.writeln('History Presensi - $userName');
    sb.writeln('Tanggal,Hari,Check In,Check Out,Durasi,Status');
    for (final r in data) {
      sb.writeln(
        [
          _csvEscape(r['date']?.toString() ?? ''),
          _csvEscape(r['day']?.toString() ?? ''),
          _csvEscape(r['checkIn']?.toString() ?? ''),
          _csvEscape(r['checkOut']?.toString() ?? ''),
          _csvEscape(r['duration']?.toString() ?? ''),
          _csvEscape(r['status']?.toString() ?? ''),
        ].join(','),
      );
    }
    await _saveToDownloads(
      context,
      Uint8List.fromList(utf8.encode(sb.toString())),
      'history_presensi.csv',
      'text/csv',
    );
  }

  static Future<void> exportAttendancePdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'History Presensi',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Karyawan: $userName'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Tanggal',
                  'Hari',
                  'Check In',
                  'Check Out',
                  'Durasi',
                  'Status',
                ],
                data: data
                    .map(
                      (r) => [
                        r['date']?.toString() ?? '',
                        r['day']?.toString() ?? '',
                        r['checkIn']?.toString() ?? '',
                        r['checkOut']?.toString() ?? '',
                        r['duration']?.toString() ?? '',
                        r['status']?.toString() ?? '',
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _saveToDownloads(
        context,
        bytes,
        'history_presensi.pdf',
        'application/pdf',
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuat PDF: $e');
      }
    }
  }

  static Future<void> exportSickCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    final sb = StringBuffer();
    sb.writeln('Riwayat Izin/Sakit - $userName');
    sb.writeln('Jenis,Mulai,Selesai,Alasan,Lampiran');
    for (final r in data) {
      sb.writeln(
        [
          _csvEscape(r['leave_type']?.toString() ?? ''),
          _csvEscape(r['start_date']?.toString() ?? ''),
          _csvEscape(r['end_date']?.toString() ?? ''),
          _csvEscape(r['reason']?.toString() ?? ''),
          _csvEscape(r['has_attachment'] == true ? 'Ada' : 'Tidak'),
        ].join(','),
      );
    }
    await _saveToDownloads(
      context,
      Uint8List.fromList(utf8.encode(sb.toString())),
      'riwayat_izin_sakit.csv',
      'text/csv',
    );
  }

  static Future<void> exportSickPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Riwayat Izin / Sakit',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Karyawan: $userName'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Jenis',
                  'Mulai',
                  'Selesai',
                  'Alasan',
                  'Lampiran',
                ],
                data: data
                    .map(
                      (r) => [
                        r['leave_type']?.toString() ?? '',
                        r['start_date']?.toString() ?? '',
                        r['end_date']?.toString() ?? '',
                        r['reason']?.toString() ?? '',
                        r['has_attachment'] == true ? 'Ada' : 'Tidak',
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _saveToDownloads(
        context,
        bytes,
        'riwayat_izin_sakit.pdf',
        'application/pdf',
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuat PDF: $e');
      }
    }
  }

  static Future<void> exportLeaveCsv(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    final sb = StringBuffer();
    sb.writeln('Riwayat Cuti - $userName');
    sb.writeln('Jenis,Mulai,Selesai,Alasan,Status');
    for (final r in data) {
      sb.writeln(
        [
          _csvEscape(r['leave_type']?.toString() ?? ''),
          _csvEscape(r['start_date']?.toString() ?? ''),
          _csvEscape(r['end_date']?.toString() ?? ''),
          _csvEscape(r['reason']?.toString() ?? ''),
          _csvEscape(statusOf(r)),
        ].join(','),
      );
    }
    await _saveToDownloads(
      context,
      Uint8List.fromList(utf8.encode(sb.toString())),
      'riwayat_cuti.csv',
      'text/csv',
    );
  }

  static Future<void> exportLeavePdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String userName,
    String Function(Map<String, dynamic>) statusOf,
  ) async {
    if (data.isEmpty) {
      CustomSnackbar.error(context, 'Tidak ada data untuk di-export');
      return;
    }
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Riwayat Cuti',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Karyawan: $userName'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Jenis',
                  'Mulai',
                  'Selesai',
                  'Alasan',
                  'Status',
                ],
                data: data
                    .map(
                      (r) => [
                        r['leave_type']?.toString() ?? '',
                        r['start_date']?.toString() ?? '',
                        r['end_date']?.toString() ?? '',
                        r['reason']?.toString() ?? '',
                        statusOf(r),
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _saveToDownloads(
        context,
        bytes,
        'riwayat_cuti.pdf',
        'application/pdf',
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(context, 'Gagal membuat PDF: $e');
      }
    }
  }
}
