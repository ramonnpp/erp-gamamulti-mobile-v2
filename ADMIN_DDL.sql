-- ============================================
-- TABEL ANNOUNCEMENTS (tambah kolom baru)
-- ============================================

-- Tambah kolom category jika belum ada
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS category VARCHAR(100);

-- Tambah kolom published_at jika belum ada
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS published_at TIMESTAMP;

-- Tambah kolom expired_at jika belum ada
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS expired_at TIMESTAMP;

-- ============================================
-- TABEL ADMIN_AUDIT_LOGS
-- ============================================

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id SERIAL PRIMARY KEY,
    admin_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,        -- 'UPDATE_ATTENDANCE', 'DELETE_ATTENDANCE', 'DELETE_LEAVE_REQUEST', 'DELETE_ACTIVITY_LOG', dst
    target_table VARCHAR(100) NOT NULL, -- 'attendance', 'leave_requests', 'activity_logs'
    target_id INT NOT NULL,
    details JSONB,                       -- catatan tambahan dalam format JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id) REFERENCES users (id) ON DELETE SET NULL
);

-- Index untuk performa query audit log per admin
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_id ON admin_audit_logs (admin_id);

-- Index untuk performa query audit log per target
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target ON admin_audit_logs (target_table, target_id);
