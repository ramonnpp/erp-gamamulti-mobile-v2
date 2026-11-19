import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Connection? _connection;
  Map<String, dynamic>? _currentUser; // store logged‑in user

  /// Naik setiap kali foto profil berubah (upload baru, atau hasil sinkron
  /// dari database). Home & Profile mendengarkan ini agar langsung update.
  final ValueNotifier<int> profileImageVersion = ValueNotifier<int>(0);

  /// Konversi hasil kolom bytea ke Uint8List (aman untuk berbagai tipe).
  Uint8List? _toBytes(dynamic v) {
    if (v == null) return null;
    if (v is Uint8List) return v.isEmpty ? null : v;
    if (v is List<int>) return v.isEmpty ? null : Uint8List.fromList(v);
    if (v is List) {
      return v.isEmpty ? null : Uint8List.fromList(List<int>.from(v));
    }
    return null;
  }

  bool _sameBytes(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Konfigurasi koneksi PostgreSQL ERP
  // Sesuaikan host, port, database name, username, dan password dengan server Anda.
  // final String _host = '10.0.2.2';
  final String _host = '192.168.100.43';
  // final String _host = '10.10.10';
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
          'SELECT id, name, email, role, phone, profile_image, profile_image_data FROM users WHERE email = @email AND password = @password',
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
          'profile_image_data': _toBytes(row[6]),
        };
        profileImageVersion.value++;
        return _currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('Error autentikasi database: $e');
      rethrow;
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
      'profile_image_data': null,
    };
    // Foto profil tidak disimpan di SharedPreferences, jadi ambil dari DB.
    unawaited(refreshCurrentUser());
    return _currentUser;
  }

  /// Ambil data terbaru user yang sedang login langsung dari database
  /// (nama, role, telepon, dan foto profil). Dipanggil saat Home/Profile
  /// dibuka, saat app kembali dari background, dan saat pull-to-refresh,
  /// sehingga semua device selalu menampilkan foto yang sama.
  Future<void> refreshCurrentUser() async {
    final id = _currentUser?['id'];
    if (id is! int) return;
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          'SELECT name, role, phone, profile_image_data FROM users WHERE id = @id',
        ),
        parameters: {'id': id},
      );
      if (result.isEmpty || _currentUser == null) return;
      final row = result.first;
      final newBytes = _toBytes(row[3]);
      final oldBytes = _currentUser!['profile_image_data'] as Uint8List?;
      final imageChanged = !_sameBytes(oldBytes, newBytes);

      _currentUser!['name'] = row[0]?.toString() ?? _currentUser!['name'];
      _currentUser!['role'] = row[1]?.toString() ?? _currentUser!['role'];
      _currentUser!['phone'] = row[2]?.toString() ?? '';
      _currentUser!['profile_image_data'] = newBytes;

      if (imageChanged) profileImageVersion.value++;
    } catch (e) {
      // Offline / gagal: tetap pakai data yang ada di memori.
      debugPrint('Gagal sinkron data user: $e');
    }
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
    profileImageVersion.value++;
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
    Uint8List? profileImageBytes, // isi hanya jika user memilih foto baru
    bool removeProfileImage = false, // true untuk menghapus foto
  }) async {
    try {
      final conn = await connect();
      final effectiveRole = role ?? _currentUser?['role'] ?? 'Employee';

      if (profileImageBytes != null) {
        await conn.execute(
          Sql.named(
            'UPDATE users SET name = @name, phone = @phone, role = @role, profile_image_data = @profileImageData WHERE id = @userId',
          ),
          parameters: {
            'name': name,
            'phone': phone,
            'role': effectiveRole,
            'profileImageData': profileImageBytes,
            'userId': userId,
          },
        );
      } else if (removeProfileImage) {
        await conn.execute(
          Sql.named(
            'UPDATE users SET name = @name, phone = @phone, role = @role, profile_image_data = NULL WHERE id = @userId',
          ),
          parameters: {
            'name': name,
            'phone': phone,
            'role': effectiveRole,
            'userId': userId,
          },
        );
      } else {
        // Foto TIDAK disentuh, supaya tidak terhapus dari database.
        await conn.execute(
          Sql.named(
            'UPDATE users SET name = @name, phone = @phone, role = @role WHERE id = @userId',
          ),
          parameters: {
            'name': name,
            'phone': phone,
            'role': effectiveRole,
            'userId': userId,
          },
        );
      }

      if (_currentUser != null && _currentUser!['id'] == userId) {
        _currentUser!['name'] = name;
        _currentUser!['phone'] = phone;
        _currentUser!['role'] = effectiveRole;
        if (profileImageBytes != null) {
          _currentUser!['profile_image_data'] = profileImageBytes;
          profileImageVersion.value++;
        } else if (removeProfileImage) {
          _currentUser!['profile_image_data'] = null;
          profileImageVersion.value++;
        }
        await saveUserSession(_currentUser!);
      }
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

  // Ambil daftar shift dari database
  Future<List<Map<String, dynamic>>> getShifts() async {
    try {
      final conn = await connect();
      final result = await conn.execute(
        Sql.named(
          'SELECT id, name, start_time, end_time FROM shifts ORDER BY id',
        ),
      );
      List<Map<String, dynamic>> shifts = [];
      for (final row in result) {
        shifts.add({
          'id': row[0],
          'name': row[1],
          'start_time': row[2].toString(),
          'end_time': row[3].toString(),
        });
      }
      return shifts;
    } catch (e) {
      debugPrint('Error ambil shift: $e');
      // Fallback data jika tabel belum dibuat
      return [
        {
          'id': 1,
          'name': 'Shift 1',
          'start_time': '07:30:00',
          'end_time': '16:00:00',
        },
        {
          'id': 2,
          'name': 'Shift 2',
          'start_time': '08:00:00',
          'end_time': '16:30:00',
        },
        {
          'id': 3,
          'name': 'Shift 3',
          'start_time': '08:30:00',
          'end_time': '16:00:00',
        },
      ];
    }
  }

  // Simpan presensi dengan shift dan status keterlambatan
  Future<bool> recordAttendance({
    required int userId,
    required String type,
    required String time,
    int? shiftId,
    String? status,
  }) async {
    try {
      final conn = await connect();
      await conn.execute(
        Sql.named(
          'INSERT INTO attendance (user_id, type, timestamp, date, shift_id, status) VALUES (@userId, @type, @timestamp, CURRENT_DATE, @shiftId, @status)',
        ),
        parameters: {
          'userId': userId,
          'type': type,
          'timestamp': time,
          'shiftId': shiftId ?? -1,
          'status': status ?? 'Tepat Waktu',
        },
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
          'SELECT type, timestamp, shift_id, status FROM attendance WHERE user_id = @userId AND date = CURRENT_DATE ORDER BY timestamp',
        ),
        parameters: {'userId': userId},
      );

      String checkIn = '--:--';
      String checkOut = '--:--';
      int shiftId = -1;
      String? selectedStatus;

      for (final row in result) {
        if (row[0] == 'CheckIn') {
          checkIn = row[1].toString();
          shiftId = row[2] as int;
          selectedStatus = row[3]?.toString();
        }
        if (row[0] == 'CheckOut') {
          checkOut = row[1].toString();
        }
      }

      return {
        'checkIn': checkIn,
        'checkOut': checkOut,
        'shiftId': shiftId,
        'status': selectedStatus ?? 'Tepat Waktu',
      };
    } catch (e) {
      debugPrint('Error ambil presensi: $e');
      return {
        'checkIn': '--:--',
        'checkOut': '--:--',
        'shiftId': -1,
        'status': 'Tepat Waktu',
      };
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
        Sql.named(
          '''SELECT a.date, a.type, a.timestamp, a.shift_id, a.status, s.name as shift_name, s.start_time, s.end_time FROM attendance a
             LEFT JOIN shifts s ON a.shift_id = s.id
             WHERE a.user_id = @userId
             AND EXTRACT(MONTH FROM a.date) = @month
             AND EXTRACT(YEAR FROM a.date) = @year
             ORDER BY a.date DESC, a.timestamp ASC''',
        ),
        parameters: {'userId': userId, 'month': queryMonth, 'year': queryYear},
      );

      List<Map<String, dynamic>> history = [];
      for (final row in result) {
        history.add({
          'date': row[0].toString(),
          'type': row[1],
          'timestamp': row[2].toString(),
          'shift_id': row[3],
          'status': row[4]?.toString(),
          'shift_name': row[5]?.toString(),
          'shift_start': row[6]?.toString(),
          'shift_end': row[7]?.toString(),
        });
      }
      return history;
    } catch (e) {
      debugPrint('Error ambil history presensi: $e');
      // Mock data fallback untuk development/testing
      return [
        {
          'date': '2026-11-05',
          'type': 'CheckIn',
          'timestamp': '08:05:00',
          'shift_id': 2,
          'status': 'Tepat Waktu',
          'shift_name': 'Shift 2',
          'shift_start': '08:00:00',
          'shift_end': '16:30:00',
        },
        {
          'date': '2026-11-05',
          'type': 'CheckOut',
          'timestamp': '17:30:00',
          'shift_id': 2,
          'status': 'Tepat Waktu',
          'shift_name': 'Shift 2',
          'shift_start': '08:00:00',
          'shift_end': '16:30:00',
        },
        {
          'date': '2026-11-04',
          'type': 'CheckIn',
          'timestamp': '08:10:00',
          'shift_id': 2,
          'status': 'Terlambat',
          'shift_name': 'Shift 2',
          'shift_start': '08:00:00',
          'shift_end': '16:30:00',
        },
        {
          'date': '2026-11-04',
          'type': 'CheckOut',
          'timestamp': '17:25:00',
          'shift_id': 2,
          'status': 'Terlambat',
          'shift_name': 'Shift 2',
          'shift_start': '08:00:00',
          'shift_end': '16:30:00',
        },
        {
          'date': '2026-11-03',
          'type': 'CheckIn',
          'timestamp': '08:00:00',
          'shift_id': 3,
          'status': 'Tepat Waktu',
          'shift_name': 'Shift 3',
          'shift_start': '08:30:00',
          'shift_end': '16:00:00',
        },
        {
          'date': '2026-11-03',
          'type': 'CheckOut',
          'timestamp': '17:35:00',
          'shift_id': 3,
          'status': 'Tepat Waktu',
          'shift_name': 'Shift 3',
          'shift_start': '08:30:00',
          'shift_end': '16:00:00',
        },
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
          '''SELECT id, leave_type, start_date, end_date, reason, attachment_path, attachment_name, attachment_mime, attachment_data, has_attachment, created_at
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
          'attachment_name': row[6],
          'attachment_mime': row[7],
          'attachment_data': row[8],
          'has_attachment': row[9] ?? false,
          'created_at': row[10] != null ? _formatDate(row[10]) : null,
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
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMime,
  }) async {
    try {
      final conn = await connect();
      final hasAttachment =
          (attachmentBytes != null && attachmentBytes.isNotEmpty) ||
          (attachmentPath != null && attachmentPath.isNotEmpty);
      await conn.execute(
        Sql.named(
          '''INSERT INTO sick_leaves (user_id, leave_type, start_date, end_date, reason, attachment_path, attachment_name, attachment_mime, attachment_data, has_attachment)
             VALUES (@userId, @leaveType, @startDate, @endDate, @reason, @attachmentPath, @attachmentName, @attachmentMime, @attachmentData, @hasAttachment)''',
        ),
        parameters: {
          'userId': userId,
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
          'attachmentPath': attachmentPath,
          'attachmentName': attachmentName,
          'attachmentMime': attachmentMime,
          'attachmentData': attachmentBytes,
          'hasAttachment': hasAttachment,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error simpan izin/sakit dengan lampiran: $e');
      return false;
    }
  }

  // Ambil data lampiran dari DB (based on leave id) dan tulis ke file temporary
  Future<String?> getAttachmentFile({
    required int leaveId,
    required String suggestedName,
  }) async {
    try {
      final conn = await connect();
      final res = await conn.execute(
        Sql.named(
          'SELECT attachment_data, attachment_mime FROM sick_leaves WHERE id = @id AND attachment_data IS NOT NULL',
        ),
        parameters: {'id': leaveId},
      );
      if (res.isEmpty) return null;
      final data = res.first[0];
      if (data == null) return null;
      // data may be Uint8List or List<int>
      final bytes = Uint8List.fromList(List<int>.from(data as List));
      final tmp = await getTemporaryDirectory();
      // Determine extension from MIME if possible, else fallback to suggestedName's extension
      String ext = '';
      final mime = res.first[1] as String?;
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
        }
      }
      if (ext.isEmpty) {
        // fallback to extension from suggestedName
        final idx = suggestedName.lastIndexOf('.');
        if (idx != -1 && idx < suggestedName.length - 1) {
          ext = suggestedName.substring(idx + 1).toLowerCase();
        } else {
          ext = 'bin';
        }
      }
      final f = File('${tmp.path}/lampiran_$leaveId.$ext');
      await f.writeAsBytes(bytes);
      return f.path;
    } catch (e) {
      debugPrint('Error ambil lampiran: $e');
      return null;
    }
  }
}
