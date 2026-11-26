import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'database_service.dart';

/// Service khusus Admin — semua metode memanggil [_ensureAdmin] di baris pertama.
/// Menggunakan koneksi dan sesi [_currentUser] yang sama dari [DatabaseService].
class AdminDatabaseService {
  /// Batas ukuran lampiran pengumuman (harus sama dengan CHECK di database).
  static const int maxAttachmentBytes = 5 * 1024 * 1024;

  // ---------- Guard ----------

  void _ensureAdmin() {
    final currentUser = DatabaseService().getCurrentUser();
    if (currentUser == null ||
        currentUser['role']?.toString().toLowerCase() != 'admin') {
      throw Exception(
        'Akses ditolak: hanya admin yang dapat mengakses layanan ini.',
      );
    }
  }

  // ---------- helper: catat audit log ----------

  Future<void> _logAudit(
    int adminId,
    String action,
    String targetTable,
    int targetId,
    Map<String, dynamic>? details,
  ) async {
    try {
      final conn = await DatabaseService().connect();
      await conn.execute(
        Sql.named('''
          INSERT INTO admin_audit_logs (admin_id, action, target_table, target_id, details)
          VALUES (@adminId, @action, @targetTable, @targetId, CAST(CAST(@details AS TEXT) AS JSONB))
        '''),
        parameters: {
          'adminId': adminId,
          'action': action,
          'targetTable': targetTable,
          'targetId': targetId,
          'details': details == null
              ? null
              : jsonEncode(details, toEncodable: (o) => o.toString()),
        },
      );
    } catch (e) {
      debugPrint('Gagal mencatat audit log: $e');
    }
  }

  // ---------- Karyawan (dropdown filter) ----------

  /// Ambil daftar semua user untuk dropdown filter admin.
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('SELECT id, name, role FROM users ORDER BY name'),
      );
      return result
          .map((row) => {'id': row[0], 'name': row[1], 'role': row[2]})
          .toList();
    } catch (e) {
      debugPrint('Error ambil daftar karyawan: $e');
      return [];
    }
  }

  // ---------- Presensi ----------

  /// Ambil semua riwayat presensi (bisa difilter per user_id).
  Future<List<Map<String, dynamic>>> getAllAttendance({int? userId}) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      late final Result result;
      if (userId != null) {
        result = await conn.execute(
          Sql.named('''
            SELECT a.id, u.name, u.role, a.date, a.type, a.timestamp,
                   COALESCE(s.name, 'N/A') AS shift_name, a.status, a.shift_id, a.user_id
            FROM attendance a
            JOIN users u ON u.id = a.user_id
            LEFT JOIN shifts s ON s.id = a.shift_id
            WHERE a.user_id = @userId
            ORDER BY a.date DESC, a.timestamp ASC
          '''),
          parameters: {'userId': userId},
        );
      } else {
        result = await conn.execute(
          Sql.named('''
            SELECT a.id, u.name, u.role, a.date, a.type, a.timestamp,
                   COALESCE(s.name, 'N/A') AS shift_name, a.status, a.shift_id, a.user_id
            FROM attendance a
            JOIN users u ON u.id = a.user_id
            LEFT JOIN shifts s ON s.id = a.shift_id
            ORDER BY a.date DESC, a.timestamp ASC
          '''),
        );
      }
      final rows = <Map<String, String>>[];
      for (final row in result) {
        rows.add({
          'id': row[0]?.toString() ?? '',
          'user_name': row[1]?.toString() ?? '',
          'user_role': row[2]?.toString() ?? '',
          'date': row[3]?.toString() ?? '',
          'type': row[4]?.toString() ?? '',
          'timestamp': row[5]?.toString() ?? '',
          'shift_name': row[6]?.toString() ?? '',
          'status': row[7]?.toString() ?? '',
          'shift_id': row[8]?.toString() ?? '',
          'user_id': row[9]?.toString() ?? '',
        });
      }
      return rows;
    } catch (e) {
      debugPrint('Error ambil semua presensi: $e');
      return [];
    }
  }

  /// Ubah jam masuk/keluar dan shift pada record attendance + catat audit log.
  Future<bool> updateEmployeeAttendance({
    required int attendanceId,
    required String time,
    required int shiftId,
    required int updatedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      await conn.execute(
        Sql.named('''
          UPDATE attendance
          SET timestamp = @time, shift_id = @shiftId
          WHERE id = @attendanceId
        '''),
        parameters: {
          'time': time,
          'shiftId': shiftId,
          'attendanceId': attendanceId,
        },
      );
      await _logAudit(
        updatedByUserId,
        'UPDATE_ATTENDANCE',
        'attendance',
        attendanceId,
        {'time': time, 'shift_id': shiftId},
      );
      return true;
    } catch (e) {
      debugPrint('Error update presensi karyawan: $e');
      return false;
    }
  }

  /// Hapus record attendance + catat audit log.
  Future<bool> deleteEmployeeAttendance({
    required int attendanceId,
    required int deletedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      // Ambil data sebelum dihapus untuk audit
      final beforeResult = await conn.execute(
        Sql.named(
          'SELECT user_id, date, type, timestamp FROM attendance WHERE id = @id',
        ),
        parameters: {'id': attendanceId},
      );
      final before = beforeResult.isNotEmpty ? beforeResult.first : <dynamic>[];

      await conn.execute(
        Sql.named('DELETE FROM attendance WHERE id = @id'),
        parameters: {'id': attendanceId},
      );
      await _logAudit(
        deletedByUserId,
        'DELETE_ATTENDANCE',
        'attendance',
        attendanceId,
        {'user_id': before[0], 'date': before[1], 'type': before[2]},
      );
      return true;
    } catch (e) {
      debugPrint('Error hapus presensi karyawan: $e');
      return false;
    }
  }

  // ---------- Leave Requests ----------

  /// Ambil semua permintaan cuti (bisa difilter per user_id).
  Future<List<Map<String, dynamic>>> getAllLeaveRequests({int? userId}) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      late final Result result;
      if (userId != null) {
        result = await conn.execute(
          Sql.named('''
            SELECT l.id, u.name, u.role, l.leave_type, l.start_date, l.end_date, l.reason, l.created_at
            FROM leave_requests l
            JOIN users u ON u.id = l.user_id
            WHERE l.user_id = @userId
            ORDER BY l.start_date DESC
          '''),
          parameters: {'userId': userId},
        );
      } else {
        result = await conn.execute(
          Sql.named('''
            SELECT l.id, u.name, u.role, l.leave_type, l.start_date, l.end_date, l.reason, l.created_at
            FROM leave_requests l
            JOIN users u ON u.id = l.user_id
            ORDER BY l.start_date DESC
          '''),
        );
      }
      final rows = <Map<String, String>>[];
      for (final row in result) {
        rows.add({
          'id': row[0]?.toString() ?? '',
          'user_name': row[1]?.toString() ?? '',
          'user_role': row[2]?.toString() ?? '',
          'leave_type': row[3]?.toString() ?? '',
          'start_date': row[4]?.toString() ?? '',
          'end_date': row[5]?.toString() ?? '',
          'reason': row[6]?.toString() ?? '',
          'created_at': row[7]?.toString() ?? '',
        });
      }
      return rows;
    } catch (e) {
      debugPrint('Error ambil semua leave requests: $e');
      return [];
    }
  }

  /// Hapus request cuti + catat audit log.
  Future<bool> deleteLeaveRequest({
    required int requestId,
    required int deletedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final beforeResult = await conn.execute(
        Sql.named(
          'SELECT user_id, leave_type FROM leave_requests WHERE id = @id',
        ),
        parameters: {'id': requestId},
      );
      final before = beforeResult.isNotEmpty ? beforeResult.first : <dynamic>[];

      await conn.execute(
        Sql.named('DELETE FROM leave_requests WHERE id = @id'),
        parameters: {'id': requestId},
      );
      await _logAudit(
        deletedByUserId,
        'DELETE_LEAVE_REQUEST',
        'leave_requests',
        requestId,
        {'user_id': before[0], 'leave_type': before[1]},
      );
      return true;
    } catch (e) {
      debugPrint('Error hapus leave request: $e');
      return false;
    }
  }

  // ---------- Activity Logs ----------

  /// Ambil semua activity logs (bisa difilter per user_id).
  Future<List<Map<String, dynamic>>> getAllActivityLogs({int? userId}) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      late final Result result;
      if (userId != null) {
        result = await conn.execute(
          Sql.named('''
            SELECT a.id, a.user_id, a.log_content, a.activity_date, a.created_at,
                   u.name AS user_name, u.role AS user_role
            FROM activity_logs a
            JOIN users u ON u.id = a.user_id
            WHERE a.user_id = @userId
            ORDER BY a.created_at DESC
          '''),
          parameters: {'userId': userId},
        );
      } else {
        result = await conn.execute(
          Sql.named('''
            SELECT a.id, a.user_id, a.log_content, a.activity_date, a.created_at,
                   u.name AS user_name, u.role AS user_role
            FROM activity_logs a
            JOIN users u ON u.id = a.user_id
            ORDER BY a.created_at DESC
          '''),
        );
      }
      final rows = <Map<String, String>>[];
      for (final row in result) {
        rows.add({
          'id': row[0]?.toString() ?? '',
          'user_id': row[1]?.toString() ?? '',
          'log': row[2]?.toString() ?? '',
          'activity_date': row[3]?.toString() ?? '',
          'created_at': row[4]?.toString() ?? '',
          'user_name': row[5]?.toString() ?? 'Karyawan',
          'user_role': row[6]?.toString() ?? 'Staff',
        });
      }
      return rows;
    } catch (e) {
      debugPrint('Error ambil semua activity logs: $e');
      return [];
    }
  }

  /// Hapus activity log + catat audit log.
  Future<bool> deleteEmployeeActivityLog({
    required int logId,
    required int deletedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final beforeResult = await conn.execute(
        Sql.named(
          'SELECT user_id, log_content FROM activity_logs WHERE id = @id',
        ),
        parameters: {'id': logId},
      );
      final before = beforeResult.isNotEmpty ? beforeResult.first : <dynamic>[];

      await conn.execute(
        Sql.named('DELETE FROM activity_logs WHERE id = @id'),
        parameters: {'id': logId},
      );
      await _logAudit(
        deletedByUserId,
        'DELETE_ACTIVITY_LOG',
        'activity_logs',
        logId,
        {'user_id': before[0], 'log': before[1]},
      );
      return true;
    } catch (e) {
      debugPrint('Error hapus activity log: $e');
      return false;
    }
  }

  // ---------- Summary Dashboard Admin ----------

  /// Ringkasan presensi, izin, dan aktivitas hari ini.
  Future<Map<String, int>> getTodayDashboardSummary() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();

      final attRes = await conn.execute(
        Sql.named(
          'SELECT COUNT(DISTINCT user_id) FROM attendance WHERE date = CURRENT_DATE',
        ),
      );
      final leaveRes = await conn.execute(
        Sql.named(
          'SELECT COUNT(*) FROM sick_leaves WHERE CURRENT_DATE BETWEEN start_date AND end_date',
        ),
      );
      final logRes = await conn.execute(
        Sql.named(
          'SELECT COUNT(DISTINCT user_id) FROM activity_logs WHERE activity_date = CURRENT_DATE',
        ),
      );

      return {
        'attendance': (attRes.isNotEmpty ? attRes.first[0] as int : 0),
        'leaves': (leaveRes.isNotEmpty ? leaveRes.first[0] as int : 0),
        'activity': (logRes.isNotEmpty ? logRes.first[0] as int : 0),
      };
    } catch (e) {
      debugPrint('Error ambil summary dashboard: $e');
      return {'attendance': 0, 'leaves': 0, 'activity': 0};
    }
  }

  // ---------- Grafik & aktivitas admin (Home Admin) ----------

  /// Jumlah karyawan yang check-in per hari selama 7 hari terakhir (termasuk hari ini),
  /// lengkap dengan jumlah yang terlambat. Hari tanpa data tetap muncul dengan nilai 0.
  Future<List<Map<String, dynamic>>> getAttendanceLast7Days() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          SELECT CAST(d AS DATE) AS day,
                 COUNT(DISTINCT a.user_id) AS hadir,
                 COUNT(DISTINCT a.user_id) FILTER (WHERE a.status ILIKE '%terlambat%') AS terlambat
          FROM generate_series(CURRENT_DATE - 6, CURRENT_DATE, INTERVAL '1 day') AS d
          LEFT JOIN attendance a
                 ON a.date = CAST(d AS DATE) AND a.type = 'CheckIn'
          GROUP BY d
          ORDER BY d
        '''),
      );
      return result
          .map(
            (row) => <String, dynamic>{
              'date': row[0]?.toString(),
              'present': (row[1] as num?)?.toInt() ?? 0,
              'late': (row[2] as num?)?.toInt() ?? 0,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error ambil grafik presensi 7 hari: $e');
      return [];
    }
  }

  /// Aktivitas admin terbaru dari admin_audit_logs.
  /// 'age_seconds' dihitung di database supaya tidak terpengaruh zona waktu.
  Future<List<Map<String, dynamic>>> getRecentAuditLogs({int limit = 5}) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          SELECT l.id, l.action, l.target_table, l.target_id, l.details,
                 l.created_at, u.name,
                 CAST(EXTRACT(EPOCH FROM (NOW() - l.created_at)) AS BIGINT) AS age_seconds
          FROM admin_audit_logs l
          LEFT JOIN users u ON u.id = l.admin_id
          ORDER BY l.created_at DESC, l.id DESC
          LIMIT @limit
        '''),
        parameters: {'limit': limit},
      );
      return result.map((row) {
        dynamic details = row[4];
        if (details is String) {
          try {
            details = jsonDecode(details);
          } catch (_) {
            details = null;
          }
        }
        return <String, dynamic>{
          'id': row[0],
          'action': row[1]?.toString() ?? '',
          'target_table': row[2]?.toString() ?? '',
          'target_id': row[3],
          'details': details is Map ? Map<String, dynamic>.from(details) : null,
          'created_at': row[5]?.toString(),
          'admin_name': row[6]?.toString() ?? 'Admin',
          'age_seconds': (row[7] as num?)?.toInt(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error ambil audit log terbaru: $e');
      return [];
    }
  }

  // ---------- Announcements ----------

  /// Ambil semua pengumuman.
  Future<List<Map<String, dynamic>>> getAllAnnouncements() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          SELECT id, title, content, category, published_at, expired_at, created_by, created_at,
                 attachment_name, attachment_mime
          FROM announcements
          ORDER BY created_at DESC
        '''),
      );
      return result
          .map(
            (row) => {
              'id': row[0],
              'title': row[1],
              'content': row[2],
              'category': row[3],
              'published_at': row[4]?.toString(),
              'expired_at': row[5]?.toString(),
              'created_by': row[6],
              'created_at': row[7]?.toString() ?? '',
              'attachment_name': row[8],
              'attachment_mime': row[9],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error ambil semua announcements: $e');
      return [];
    }
  }

  /// Ambil pengumuman aktif (publised_at <= now <= expired_at atau expired_at kosong).
  Future<List<Map<String, dynamic>>> getActiveAnnouncements() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          SELECT id, title, content, category, published_at, expired_at, created_by, created_at,
                 attachment_name, attachment_mime
          FROM announcements
          WHERE (published_at IS NULL OR published_at <= (NOW() AT TIME ZONE 'Asia/Jakarta'))
            AND (expired_at IS NULL OR expired_at > (NOW() AT TIME ZONE 'Asia/Jakarta'))
          ORDER BY created_at DESC
        '''),
      );
      return result
          .map(
            (row) => {
              'id': row[0],
              'title': row[1],
              'content': row[2],
              'category': row[3],
              'published_at': row[4]?.toString(),
              'expired_at': row[5]?.toString(),
              'created_by': row[6],
              'created_at': row[7]?.toString() ?? '',
              'attachment_name': row[8],
              'attachment_mime': row[9],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error ambil announcements aktif: $e');
      return [];
    }
  }

  /// Format jam apa adanya (waktu lokal/WIB) tanpa konversi UTC.
  String? _wallClock(DateTime? d) {
    if (d == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  /// Buat pengumuman baru (lampiran opsional) + catat audit log.
  Future<bool> createAnnouncement({
    required int createdBy,
    required String title,
    required String content,
    String? category,
    DateTime? publishedAt,
    DateTime? expiredAt,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMime,
  }) async {
    _ensureAdmin();
    try {
      final bytes = (attachmentBytes != null && attachmentBytes.isNotEmpty)
          ? attachmentBytes
          : null;
      if (bytes != null && bytes.length > maxAttachmentBytes) {
        debugPrint('Lampiran melebihi batas ${maxAttachmentBytes ~/ 1024} KB');
        return false;
      }

      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          INSERT INTO announcements
            (title, content, category, published_at, expired_at, created_by, created_at,
             attachment_name, attachment_mime, attachment_data)
          VALUES
            (@title, @content, @category, CAST(@publishedAt AS timestamp), CAST(@expiredAt AS timestamp),
             @createdBy, CURRENT_TIMESTAMP,
             @attName, @attMime, @attData)
          RETURNING id
        '''),
        parameters: {
          'title': title,
          'content': content,
          'category': category,
          'publishedAt': _wallClock(publishedAt),
          'expiredAt': _wallClock(expiredAt),
          'createdBy': createdBy,
          'attName': bytes != null ? attachmentName : null,
          'attMime': bytes != null ? attachmentMime : null,
          'attData': bytes != null ? TypedValue(Type.byteArray, bytes) : null,
        },
      );

      final newId = result.first[0] as int;
      await _logAudit(createdBy, 'CREATE_ANNOUNCEMENT', 'announcements', newId, {
        'title': title,
        'category': category,
        if (bytes != null) 'attachment_name': attachmentName,
        if (bytes != null) 'attachment_size': bytes.length,
      });
      return true;
    } catch (e) {
      debugPrint('Error buat announcement: $e');
      return false;
    }
  }

  /// Update pengumuman + catat audit log.
  ///
  /// Lampiran: [attachmentBytes] diisi = ganti lampiran,
  /// [removeAttachment] = true = hapus lampiran, selain itu lampiran tidak berubah.
  Future<bool> updateAnnouncement({
    required int announcementId,
    required int updatedBy,
    String? title,
    String? content,
    String? category,
    DateTime? publishedAt,
    DateTime? expiredAt,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMime,
    bool removeAttachment = false,
  }) async {
    _ensureAdmin();
    try {
      final bytes = (attachmentBytes != null && attachmentBytes.isNotEmpty)
          ? attachmentBytes
          : null;
      if (bytes != null && bytes.length > maxAttachmentBytes) {
        debugPrint('Lampiran melebihi batas ${maxAttachmentBytes ~/ 1024} KB');
        return false;
      }

      final params = <String, dynamic>{
        'id': announcementId,
        'title': title,
        'content': content,
        'category': category,
        'publishedAt': _wallClock(publishedAt),
        'expiredAt': _wallClock(expiredAt),
      };

      String attachmentSql = '';
      String attachmentAction = 'unchanged';
      if (bytes != null) {
        attachmentSql = ''',
              attachment_name = @attName,
              attachment_mime = @attMime,
              attachment_data = @attData''';
        params['attName'] = attachmentName;
        params['attMime'] = attachmentMime;
        params['attData'] = TypedValue(Type.byteArray, bytes);
        attachmentAction = 'replaced';
      } else if (removeAttachment) {
        attachmentSql = ''',
              attachment_name = NULL,
              attachment_mime = NULL,
              attachment_data = NULL''';
        attachmentAction = 'removed';
      }

      final conn = await DatabaseService().connect();
      await conn.execute(
        Sql.named('''
          UPDATE announcements
          SET title         = COALESCE(@title, title),
              content       = COALESCE(@content, content),
              category      = COALESCE(@category, category),
              published_at  = COALESCE(CAST(@publishedAt AS timestamp), published_at),
              expired_at    = COALESCE(CAST(@expiredAt AS timestamp), expired_at),
              updated_at    = CURRENT_TIMESTAMP$attachmentSql
          WHERE id = @id
        '''),
        parameters: params,
      );

      await _logAudit(updatedBy, 'UPDATE_ANNOUNCEMENT', 'announcements', announcementId, {
        'title': title,
        'category': category,
        'attachment': attachmentAction,
        if (bytes != null) 'attachment_name': attachmentName,
        if (bytes != null) 'attachment_size': bytes.length,
      });
      return true;
    } catch (e) {
      debugPrint('Error update announcement: $e');
      return false;
    }
  }

  /// Ambil isi lampiran satu pengumuman (dipanggil hanya saat lampiran dibuka).
  /// Admin: semua pengumuman. User biasa: hanya pengumuman yang sedang aktif.
  /// Mengembalikan {'name', 'mime', 'bytes'} atau null.
  Future<Map<String, dynamic>?> getAnnouncementAttachment(
    int announcementId,
  ) async {
    final user = DatabaseService().getCurrentUser();
    if (user == null) {
      throw Exception('Akses ditolak: silakan login terlebih dahulu.');
    }
    final isAdmin = user['role']?.toString().toLowerCase() == 'admin';
    try {
      final conn = await DatabaseService().connect();
      final activeOnly = isAdmin
          ? ''
          : "AND (published_at IS NULL OR published_at <= (NOW() AT TIME ZONE 'Asia/Jakarta')) "
                "AND (expired_at IS NULL OR expired_at > (NOW() AT TIME ZONE 'Asia/Jakarta'))";
      final result = await conn.execute(
        Sql.named('''
          SELECT attachment_name, attachment_mime, attachment_data
          FROM announcements
          WHERE id = @id AND attachment_data IS NOT NULL $activeOnly
        '''),
        parameters: {'id': announcementId},
      );
      if (result.isEmpty) return null;
      final row = result.first;
      return {'name': row[0], 'mime': row[1], 'bytes': row[2]};
    } catch (e) {
      debugPrint('Error ambil lampiran announcement: $e');
      return null;
    }
  }

  /// Hapus pengumuman (beserta lampirannya) + catat audit log.
  Future<bool> deleteAnnouncement({
    required int announcementId,
    required int deletedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final beforeResult = await conn.execute(
        Sql.named(
          'SELECT title, attachment_name FROM announcements WHERE id = @id',
        ),
        parameters: {'id': announcementId},
      );
      final beforeTitle = beforeResult.isNotEmpty
          ? beforeResult.first[0]
          : null;
      final beforeAttachment = beforeResult.isNotEmpty
          ? beforeResult.first[1]
          : null;

      await conn.execute(
        Sql.named('DELETE FROM announcements WHERE id = @id'),
        parameters: {'id': announcementId},
      );
      await _logAudit(
        deletedByUserId,
        'DELETE_ANNOUNCEMENT',
        'announcements',
        announcementId,
        {'title': beforeTitle, 'attachment_name': beforeAttachment},
      );
      return true;
    } catch (e) {
      debugPrint('Error hapus announcement: $e');
      return false;
    }
  }
}
