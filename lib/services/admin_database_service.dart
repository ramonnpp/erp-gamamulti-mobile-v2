import 'dart:async';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'database_service.dart';

/// Service khusus Admin — semua metode memanggil [_ensureAdmin] di baris pertama.
/// Menggunakan koneksi dan sesi [_currentUser] yang sama dari [DatabaseService].
class AdminDatabaseService {
  // ---------- Guard ----------

  void _ensureAdmin() {
    final currentUser = DatabaseService().getCurrentUser();
    if (currentUser == null || currentUser['role']?.toString().toLowerCase() != 'admin') {
      throw Exception('Akses ditolak: hanya admin yang dapat mengakses layanan ini.');
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
          VALUES (@adminId, @action, @targetTable, @targetId, @details)
        '''),
        parameters: {
          'adminId': adminId,
          'action': action,
          'targetTable': targetTable,
          'targetId': targetId,
          'details': details?.toString(),
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
        Sql.named('SELECT user_id, date, type, timestamp FROM attendance WHERE id = @id'),
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
        Sql.named('SELECT user_id, leave_type FROM leave_requests WHERE id = @id'),
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
            SELECT id, user_id, log_content, activity_date, created_at
            FROM activity_logs
            WHERE user_id = @userId
            ORDER BY created_at DESC
          '''),
          parameters: {'userId': userId},
        );
      } else {
        result = await conn.execute(
          Sql.named('''
            SELECT id, user_id, log_content, activity_date, created_at
            FROM activity_logs
            ORDER BY created_at DESC
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
        Sql.named('SELECT user_id, log_content FROM activity_logs WHERE id = @id'),
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
        Sql.named('SELECT COUNT(DISTINCT user_id) FROM attendance WHERE date = CURRENT_DATE'),
      );
      final leaveRes = await conn.execute(
        Sql.named('SELECT COUNT(*) FROM sick_leaves WHERE CURRENT_DATE BETWEEN start_date AND end_date'),
      );
      final logRes = await conn.execute(
        Sql.named('SELECT COUNT(DISTINCT user_id) FROM activity_logs WHERE activity_date = CURRENT_DATE'),
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

  // ---------- Announcements ----------

  /// Ambil semua pengumuman.
  Future<List<Map<String, dynamic>>> getAllAnnouncements() async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final result = await conn.execute(
        Sql.named('''
          SELECT id, title, content, category, published_at, expired_at, created_by, created_at
          FROM announcements
          ORDER BY created_at DESC
        '''),
      );
      return result
          .map((row) => {
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'category': row[3],
                'published_at': row[4]?.toString(),
                'expired_at': row[5]?.toString(),
                'created_by': row[6],
                'created_at': row[7]?.toString() ?? '',
              })
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
          SELECT id, title, content, category, published_at, expired_at, created_by, created_at
          FROM announcements
          WHERE (published_at IS NULL OR published_at <= CURRENT_TIMESTAMP)
            AND (expired_at IS NULL OR expired_at > CURRENT_TIMESTAMP)
          ORDER BY created_at DESC
        '''),
      );
      return result
          .map((row) => {
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'category': row[3],
                'published_at': row[4]?.toString(),
                'expired_at': row[5]?.toString(),
                'created_by': row[6],
                'created_at': row[7]?.toString() ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('Error ambil announcements aktif: $e');
      return [];
    }
  }

  /// Buat pengumuman baru.
  Future<bool> createAnnouncement({
    required int createdBy,
    required String title,
    required String content,
    String? category,
    DateTime? publishedAt,
    DateTime? expiredAt,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      await conn.execute(
        Sql.named('''
          INSERT INTO announcements
            (title, content, category, published_at, expired_at, created_by, created_at)
          VALUES
            (@title, @content, @category, @publishedAt, @expiredAt, @createdBy, CURRENT_TIMESTAMP)
        '''),
        parameters: {
          'title': title,
          'content': content,
          'category': category,
          'publishedAt': publishedAt?.toUtc(),
          'expiredAt': expiredAt?.toUtc(),
          'createdBy': createdBy,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error buat announcement: $e');
      return false;
    }
  }

  /// Update pengumuman.
  Future<bool> updateAnnouncement({
    required int announcementId,
    required int updatedBy,
    String? title,
    String? content,
    String? category,
    DateTime? publishedAt,
    DateTime? expiredAt,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      await conn.execute(
        Sql.named('''
          UPDATE announcements
          SET title         = COALESCE(@title, title),
              content       = COALESCE(@content, content),
              category      = COALESCE(@category, category),
              published_at  = COALESCE(@publishedAt, published_at),
              expired_at    = COALESCE(@expiredAt, expired_at),
              updated_at    = CURRENT_TIMESTAMP
          WHERE id = @id
        '''),
        parameters: {
          'id': announcementId,
          'title': title,
          'content': content,
          'category': category,
          'publishedAt': publishedAt?.toUtc(),
          'expiredAt': expiredAt?.toUtc(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error update announcement: $e');
      return false;
    }
  }

  /// Hapus pengumuman.
  Future<bool> deleteAnnouncement({
    required int announcementId,
    required int deletedByUserId,
  }) async {
    _ensureAdmin();
    try {
      final conn = await DatabaseService().connect();
      final beforeResult = await conn.execute(
        Sql.named('SELECT title FROM announcements WHERE id = @id'),
        parameters: {'id': announcementId},
      );
      final beforeTitle = beforeResult.isNotEmpty ? beforeResult.first[0] : null;

      await conn.execute(
        Sql.named('DELETE FROM announcements WHERE id = @id'),
        parameters: {'id': announcementId},
      );
      await _logAudit(
        deletedByUserId,
        'DELETE_ANNOUNCEMENT',
        'announcements',
        announcementId,
        {'title': beforeTitle},
      );
      return true;
    } catch (e) {
      debugPrint('Error hapus announcement: $e');
      return false;
    }
  }
}
