import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Connection? _connection;
  Map<String, dynamic>? _currentUser; // store logged‑in user

  // Konfigurasi koneksi PostgreSQL ERP
  // Sesuaikan host, port, database name, username, dan password dengan server Anda.
  final String _host =
      '10.0.2.2'; // Gunakan 10.0.2.2 untuk Android Emulator ke localhost, atau IP server.
  final int _port = 5432;
  final String _databaseName = 'gama_multi_erp';
  final String _username = 'postgres';
  final String _password = 'ramonganteng';

  Future<Connection> connect() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    try {
      final endpoint = Endpoint(
        host: _host,
        port: _port,
        database: _databaseName,
        username: _username,
        password: _password,
      );

      _connection = await Connection.open(
        endpoint,
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
      debugPrint('Berhasil terhubung ke PostgreSQL ERP Database.');
      return _connection!;
    } catch (e) {
      debugPrint('Gagal terhubung ke Database: $e');
      // Jika DB tidak bisa terhubung, gunakan mock data agar UI tetap berjalan
      _currentUser = {
        'id': 1,
        'name': 'Ahmad Fauzi, S.Kom',
        'email': 'ahmad.fauzi@gamamulti.co.id',
        'role': 'Employee',
        'phone': '',
        'profile_image': null,
      };
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  // Contoh query fetch data pengguna / autentikasi
  Future<Map<String, dynamic>?> authenticateUser(
    String email,
    String password,
  ) async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          'SELECT id, name, email, role, phone, profile_image FROM users WHERE email = @email AND password = @password',
        ),
        parameters: {'email': email, 'password': password},
      );

      if (result.isNotEmpty) {
        final row = result.first;
        _currentUser = {
          'id': row[0],
          'name': row[1],
          'email': row[2],
          'role': row[3],
          'phone': row[4]?.toString() ?? '',
          'profile_image': row[5]?.toString(),
        };
        return _currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('Error autentikasi database: $e');
      // Fallback ke mock user jika DB tidak responsif
      _currentUser = {
        'id': 1,
        'name': 'Ahmad Fauzi, S.Kom',
        'email': 'ahmad.fauzi@gamamulti.co.id',
        'role': 'Employee',
        'phone': '',
        'profile_image': null,
      };
      return _currentUser;
    }
  }

  Map<String, dynamic>? getCurrentUser() => _currentUser;

  // Simpan session user ke SharedPreferences
  Future<void> saveUserSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user['id']);
    await prefs.setString('user_name', user['name']);
    await prefs.setString('user_email', user['email']);
    await prefs.setString('user_role', user['role']);
    await prefs.setString('user_phone', user['phone']?.toString() ?? '');
    if (user['profile_image'] != null) {
      await prefs.setString(
        'user_profile_image',
        user['profile_image'].toString(),
      );
    }
  }

  // Load session user dari SharedPreferences
  Future<Map<String, dynamic>?> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return null;

    _currentUser = {
      'id': userId,
      'name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'role': prefs.getString('user_role') ?? '',
      'phone': prefs.getString('user_phone') ?? '',
      'profile_image': prefs.getString('user_profile_image'),
    };
    return _currentUser;
  }

  // Hapus session user (logout)
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_phone');
    await prefs.remove('user_profile_image');
    _currentUser = null;
  }

  // Register user baru
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'Employee',
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          'INSERT INTO users (name, email, password, phone, role) VALUES (@name, @email, @password, @phone, @role)',
        ),
        parameters: {
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': role,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error registrasi user: $e');
      return false;
    }
  }

  Future<bool> updateUser({
    required int userId,
    required String name,
    required String phone,
    String? role,
    String? profileImage,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          'UPDATE users SET name = @name, phone = @phone, role = @role, profile_image = @profileImage WHERE id = @userId',
        ),
        parameters: {
          'name': name,
          'phone': phone,
          'role': role ?? _currentUser?['role'] ?? 'Employee',
          'profileImage': profileImage,
          'userId': userId,
        },
      );
      if (_currentUser != null && _currentUser!['id'] == userId) {
        _currentUser!['name'] = name;
        _currentUser!['phone'] = phone;
        if (role != null) _currentUser!['role'] = role;
        if (profileImage != null) _currentUser!['profile_image'] = profileImage;
      }
      await saveUserSession(_currentUser ?? {});
      return true;
    } catch (e) {
      debugPrint('Error update user: $e');
      return false;
    }
  }

  Future<bool> changePassword({
    required int userId,
    required String newPassword,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          'UPDATE users SET password = @newPassword WHERE id = @userId',
        ),
        parameters: {'newPassword': newPassword, 'userId': userId},
      );
      return true;
    } catch (e) {
      debugPrint('Error change password: $e');
      return false;
    }
  }

  // Simpan presensi
  Future<bool> recordAttendance({
    required int userId,
    required String type,
    required String time,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          'INSERT INTO attendance (user_id, type, timestamp, date) VALUES (@userId, @type, @timestamp, CURRENT_DATE)',
        ),
        parameters: {'userId': userId, 'type': type, 'timestamp': time},
      );
      return true;
    } catch (e) {
      debugPrint('Error menyimpan presensi: $e');
      return false;
    }
  }

  // Ambil status presensi hari ini dari DB
  Future<Map<String, dynamic>> getTodayAttendance(int userId) async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          'SELECT type, timestamp FROM attendance WHERE user_id = @userId AND date = CURRENT_DATE ORDER BY timestamp',
        ),
        parameters: {'userId': userId},
      );

      String checkIn = '--:--';
      String checkOut = '--:--';

      for (final row in result) {
        if (row[0] == 'CheckIn') {
          checkIn = row[1].toString();
        }
        if (row[0] == 'CheckOut') {
          checkOut = row[1].toString();
        }
      }

      return {'checkIn': checkIn, 'checkOut': checkOut};
    } catch (e) {
      debugPrint('Error ambil presensi: $e');
      return {'checkIn': '--:--', 'checkOut': '--:--'};
    }
  }

  // Ambil riwayat presensi bulan tertentu
  Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required int userId,
    int? month,
    int? year,
  }) async {
    final now = DateTime.now();
    final queryMonth = month ?? now.month;
    final queryYear = year ?? now.year;
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named('''SELECT date, type, timestamp FROM attendance 
             WHERE user_id = @userId 
             AND EXTRACT(MONTH FROM date) = @month 
             AND EXTRACT(YEAR FROM date) = @year 
             ORDER BY date DESC, timestamp ASC'''),
        parameters: {'userId': userId, 'month': queryMonth, 'year': queryYear},
      );

      List<Map<String, dynamic>> history = [];
      for (final row in result) {
        history.add({
          'date': row[0].toString(),
          'type': row[1],
          'timestamp': row[2].toString(),
        });
      }
      return history;
    } catch (e) {
      debugPrint('Error ambil history presensi: $e');
      // Mock data fallback untuk development/testing
      return [
        {'date': '2026-11-05', 'type': 'CheckIn', 'timestamp': '08:05:00'},
        {'date': '2026-11-05', 'type': 'CheckOut', 'timestamp': '17:30:00'},
        {'date': '2026-11-04', 'type': 'CheckIn', 'timestamp': '08:10:00'},
        {'date': '2026-11-04', 'type': 'CheckOut', 'timestamp': '17:25:00'},
        {'date': '2026-11-03', 'type': 'CheckIn', 'timestamp': '08:00:00'},
        {'date': '2026-11-03', 'type': 'CheckOut', 'timestamp': '17:35:00'},
      ];
    }
  }

  // Ambil data cuti
  Future<List<Map<String, dynamic>>> getLeaves({required int userId}) async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          '''SELECT id, leave_type, start_date, end_date, reason, created_at
             FROM leave_requests WHERE user_id = @userId ORDER BY start_date DESC''',
        ),
        parameters: {'userId': userId},
      );

      List<Map<String, dynamic>> leaves = [];
      for (final row in result) {
        leaves.add({
          'id': row[0],
          'leave_type': row[1],
          'start_date': _formatDate(row[2]),
          'end_date': _formatDate(row[3]),
          'reason': row[4],
          'created_at': row[5] != null ? _formatDate(row[5]) : null,
        });
      }
      return leaves;
    } catch (e) {
      debugPrint('Error ambil data cuti: $e');
      return [];
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final dateStr = value.toString();
    // Extract date part only (yyyy-MM-dd)
    final dateOnly = dateStr.split(' ')[0].split('T')[0];
    return dateOnly;
  }

  // Ambil data izin/sakit
  Future<List<Map<String, dynamic>>> getSickLeaves({
    required int userId,
  }) async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          '''SELECT id, leave_type, start_date, end_date, reason, attachment_path, has_attachment, created_at
             FROM sick_leaves WHERE user_id = @userId ORDER BY start_date DESC''',
        ),
        parameters: {'userId': userId},
      );

      List<Map<String, dynamic>> leaves = [];
      for (final row in result) {
        leaves.add({
          'id': row[0],
          'leave_type': row[1],
          'start_date': _formatDate(row[2]),
          'end_date': _formatDate(row[3]),
          'reason': row[4],
          'attachment_path': row[5],
          'has_attachment': row[6] ?? false,
          'created_at': row[7] != null ? _formatDate(row[7]) : null,
        });
      }
      return leaves;
    } catch (e) {
      debugPrint('Error ambil data izin/sakit: $e');
      return [];
    }
  }

  // Info hari ini: siapa yang izin/sakit & cuti hari ini (semua karyawan)
  Future<Map<String, dynamic>> getTodayLeaveInfo() async {
    try {
      final conn = await connect();
      final sickResult = await conn.execute(
        Sql.named('''SELECT u.name, s.leave_type, s.reason FROM sick_leaves s
             JOIN users u ON u.id = s.user_id
             WHERE CURRENT_DATE BETWEEN s.start_date AND s.end_date
             ORDER BY u.name'''),
      );
      final leaveResult = await conn.execute(
        Sql.named('''SELECT u.name, l.leave_type, l.reason FROM leave_requests l
             JOIN users u ON u.id = l.user_id
             WHERE CURRENT_DATE BETWEEN l.start_date AND l.end_date
             ORDER BY u.name'''),
      );
      List<Map<String, dynamic>> sick = [];
      for (final row in sickResult) {
        sick.add({'name': row[0], 'type': row[1], 'reason': row[2]});
      }
      List<Map<String, dynamic>> leave = [];
      for (final row in leaveResult) {
        leave.add({'name': row[0], 'type': row[1], 'reason': row[2]});
      }
      return {'sick': sick, 'leave': leave};
    } catch (e) {
      debugPrint('Error ambil info izin/cuti hari ini: $e');
      return {
        'sick': <Map<String, dynamic>>[],
        'leave': <Map<String, dynamic>>[],
      };
    }
  }

  // Ambil pengumuman aktif
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named('''SELECT id, title, content, created_at FROM announcements
             WHERE is_active = TRUE ORDER BY created_at DESC LIMIT 5'''),
      );
      List<Map<String, dynamic>> list = [];
      for (final row in result) {
        list.add({
          'id': row[0],
          'title': row[1],
          'content': row[2],
          'created_at': row[3] != null ? _formatDate(row[3]) : null,
        });
      }
      return list;
    } catch (e) {
      debugPrint('Error ambil pengumuman: $e');
      return [];
    }
  }

  // Simpan permohonan cuti
  Future<bool> submitLeaveRequest({
    required int userId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          '''INSERT INTO leave_requests (user_id, leave_type, start_date, end_date, reason)
             VALUES (@userId, @leaveType, @startDate, @endDate, @reason)''',
        ),
        parameters: {
          'userId': userId,
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error simpan cuti: $e');
      return false;
    }
  }

  // Simpan permohonan izin/sakit
  Future<bool> submitSickLeaveRequest({
    required int userId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          '''INSERT INTO sick_leaves (user_id, leave_type, start_date, end_date, reason)
             VALUES (@userId, @leaveType, @startDate, @endDate, @reason)''',
        ),
        parameters: {
          'userId': userId,
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error simpan izin/sakit: $e');
      return false;
    }
  }

  // Simpan permohonan izin/sakit dengan lampiran
  Future<bool> submitSickLeaveRequestWithAttachment({
    required int userId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? attachmentPath,
  }) async {
    try {
      final conn = await connect();
      final hasAttachment = attachmentPath != null && attachmentPath.isNotEmpty;
      await conn.execute(
        Sql.named(
          '''INSERT INTO sick_leaves (user_id, leave_type, start_date, end_date, reason, attachment_path, has_attachment)
             VALUES (@userId, @leaveType, @startDate, @endDate, @reason, @attachmentPath, @hasAttachment)''',
        ),
        parameters: {
          'userId': userId,
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
          'attachmentPath': attachmentPath,
          'hasAttachment': hasAttachment,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error simpan izin/sakit dengan lampiran: $e');
      return false;
    }
  }
}
