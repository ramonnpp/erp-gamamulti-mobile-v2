-- ============================================
-- GAMA MULTI ERP - DATABASE SCHEMA
-- PostgreSQL Scripts untuk Setup Awal
-- ============================================

-- 1. TABEL USERS (Karyawan)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'Employee', -- 'Employee', 'Manager', 'Admin', 'HR'
    department VARCHAR(100),
    phone VARCHAR(20),
    profile_image TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. TABEL ATTENDANCE (Presensi Harian)
CREATE TABLE IF NOT EXISTS attendance (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'CheckIn' atau 'CheckOut'
    timestamp VARCHAR(20) NOT NULL, -- Format: "HH:MM WIB"
    date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- 3. TABEL ANNOUNCEMENTS (Pengumuman Perusahaan)
CREATE TABLE IF NOT EXISTS announcements (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE CASCADE
);

-- 4. TABEL LEAVE_REQUESTS (Permintaan Cuti)
CREATE TABLE IF NOT EXISTS leave_requests (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    leave_type VARCHAR(50) NOT NULL, -- 'Cuti Tahunan', 'Cuti Bersama', 'Cuti Darurat'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- 5. TABEL SICK_LEAVES (Permintaan Izin/Sakit)
CREATE TABLE IF NOT EXISTS sick_leaves (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    leave_type VARCHAR(50) NOT NULL, -- 'Sakit/Izin'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    attachment_path TEXT, -- Path file lampiran surat dokter (legacy/local)
    attachment_name TEXT, -- Nama file lampiran
    attachment_mime TEXT, -- MIME type lampiran
    attachment_data BYTEA, -- Isi file lampiran (disimpan di DB)
    has_attachment BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================
-- INDEX untuk PERFORMA QUERY
-- ============================================

CREATE INDEX idx_attendance_user_date ON attendance (user_id, date);

CREATE INDEX idx_attendance_date ON attendance (date);

CREATE INDEX idx_leave_requests_user ON leave_requests (user_id);

-- CREATE INDEX idx_leave_requests_status ON leave_requests (status); -- kolom status tidak ada
-- CREATE INDEX idx_payroll_user_period ON payroll (user_id, period_month, period_year); -- tabel payroll tidak ada

CREATE INDEX idx_users_email ON users (email);

CREATE INDEX idx_announcements_active ON announcements (is_active);

-- ============================================
-- QUERIES YANG DIGUNAKAN DI APLIKASI FLUTTER
-- ============================================

-- 1. Login User
-- SELECT id, name, email, role FROM users WHERE email = ? AND password = ?

-- 2. Ambil Status Presensi Hari Ini
-- SELECT type, timestamp FROM attendance WHERE user_id = ? AND date = CURRENT_DATE ORDER BY timestamp

-- 3. Simpan Presensi Baru
-- INSERT INTO attendance (user_id, type, timestamp, date) VALUES (?, ?, ?, CURRENT_DATE)

-- 4. Ambil Pengumuman Aktif
-- SELECT id, title, content, created_at FROM announcements WHERE is_active = TRUE ORDER BY created_at DESC LIMIT 10

-- 5. Register User Baru
-- INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, 'Employee')

-- 7. Update Profil User
-- UPDATE users SET name = $1, phone = $2, profile_image = $3 WHERE id = $4

-- ============================================
-- MIGRASI UPDATE TABEL USERS (Jalankan di PostgreSQL)
-- ============================================
-- Tambah kolom profile_image jika belum ada
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image TEXT;

-- Tambah kolom profile_image_data jika belum ada (foto profil di DB)
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_data BYTEA;

-- Tambah kolom phone jika belum ada
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- Tambah kolom department jika belum ada
ALTER TABLE users ADD COLUMN IF NOT EXISTS department VARCHAR(100);

-- Tambah kolom lampiran di sick_leaves jika belum ada
ALTER TABLE sick_leaves
ADD COLUMN IF NOT EXISTS attachment_name TEXT;

ALTER TABLE sick_leaves
ADD COLUMN IF NOT EXISTS attachment_mime TEXT;

ALTER TABLE sick_leaves
ADD COLUMN IF NOT EXISTS attachment_data BYTEA;

-- Flag ada lampiran
ALTER TABLE sick_leaves
ADD COLUMN IF NOT EXISTS has_attachment BOOLEAN DEFAULT FALSE;

-- Update role default
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'Employee';

-- Contoh update data user (ganti nilai sesuai kebutuhan)
-- UPDATE users SET name = 'Nama Baru', phone = '081234567890', profile_image = '/path/to/image.jpg' WHERE id = 1;

-- ============================================
-- CATATAN
-- ============================================
-- 1. Password di contoh ini adalah plain text (TIDAK AMAN untuk production).
--    Untuk production, gunakan bcrypt atau argon2 untuk hashing password.
--
-- 2. Semua FK (Foreign Key) memiliki ON DELETE CASCADE/SET NULL untuk data integrity.
--
-- 3. Created_at & updated_at untuk audit trail setiap perubahan data.
--
-- 4. Index dibuat untuk performa query yang sering diakses (attendance, leave_requests, payroll).
--
-- 5. Untuk production, tambahkan constraints:
--    - CHECK untuk validasi nilai tertentu
--    - UNIQUE untuk field yang tidak boleh duplikat
--    - NOT NULL untuk field wajib diisi