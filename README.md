Gama Multi ERP Mobile (erp-gamamulti-mobile-v2)

Aplikasi mobile Enterprise Resource Planning (ERP) berbasis Flutter untuk manajemen operasional internal perusahaan Gama Multi Usaha Mandiri (GMUM), mencakup presensi kehadiran, pengajuan cuti dan izin sakit, pencatatan log aktivitas harian, pengumuman internal, serta panel manajemen administrator yang terhubung langsung ke database PostgreSQL (Supabase).

Unduh & Instalasi Aplikasi (Android)

Link Alternatif: Klik di sini untuk mengunduh file .apk

Langkah Instalasi di Perangkat Android

Klik tombol Download APK atau tautan alternatif di atas untuk mengunduh file installer (app-release.apk).

Buka file .apk yang telah diunduh melalui File Manager atau notifikasi browser di HP Android Anda.

Jika muncul peringatan keamanan, pilih Setelan (Settings) lalu aktifkan izin Izinkan dari sumber ini (Install from Unknown Sources).

Tekan Instal dan tunggu hingga aplikasi siap digunakan.

Arsitektur Sistem

Aplikasi ini terhubung langsung dari klien Flutter ke database PostgreSQL yang di-hosting di Supabase melalui Supavisor Session Pooler dengan koneksi terenkripsi SSL (SslMode.require).

flowchart LR
    subgraph Mobile ["Aplikasi Flutter (Android / iOS)"]
        UI["UI Views & Widgets"]
        Auth["Autentikasi & Role Check"]
        UserSvc["database_service.dart"]
        AdminSvc["admin_database_service.dart"]
        Env[".env (flutter_dotenv)"]
    end

    subgraph Cloud ["Supabase Cloud"]
        Pooler["Supavisor Session Pooler\n(Port 5432 • IPv4 • SSL Required)"]
        PG[("PostgreSQL Database\n(Skema public + RLS)")]
    end

    UI --> Auth
    Auth -->|Role: User| UserSvc
    Auth -->|Role: Admin| AdminSvc
    Env -.->|Kredensial DB| UserSvc
    Env -.->|Kredensial DB| AdminSvc
    UserSvc ==>|Direct SQL Query| Pooler
    AdminSvc ==>|Direct SQL Query| Pooler
    Pooler ==> PG


Fitur Utama

Modul Karyawan (User)

Autentikasi & Profil: Login dan registrasi akun berbasis email dengan enkripsi password (bcrypt), serta manajemen profil pengguna.

Presensi / Absensi: Pencatatan kehadiran harian dan riwayat absensi lengkap.

Manajemen Cuti & Izin Sakit: Pengajuan cuti tahunan dan izin sakit melalui formulir terintegrasi, lengkap dengan rincian status dan riwayat pengajuan.

Log Aktivitas Harian: Pencatatan, penambahan, dan pemantauan laporan aktivitas kerja harian.

Pengumuman Internal: Papan informasi dan detail pengumuman perusahaan.

Ekspor Data: Fitur ekspor laporan data pribadi.

Modul Administrator (Admin)

Dashboard Admin: Ringkasan dan navigasi terpusat untuk pengelolaan seluruh data operasional.

Manajemen Pengguna: Pengelolaan data akun karyawan dan hak akses peran (Admin / User).

Monitoring Absensi & Cuti: Peninjauan dan persetujuan data kehadiran serta pengajuan cuti/izin karyawan.

Monitoring Log Aktivitas: Pemantauan laporan aktivitas kerja seluruh karyawan.

Manajemen Pengumuman: Pembuatan dan pengelolaan pengumuman perusahaan.

Ekspor Laporan Admin: Fitur ekspor rekapitulasi data operasional untuk kebutuhan administrasi.

Teknologi & Arsitektur

Framework Mobile: Flutter (Dart) — mendukung Android, iOS, Web, dan Desktop.

Database: PostgreSQL (Hosted via Supabase).

Koneksi Database: Koneksi PostgreSQL langsung melalui Session Pooler (SslMode.require) yang dikelola pada database_service.dart dan admin_database_service.dart.

Manajemen Konfigurasi: flutter_dotenv untuk pengelolaan variabel lingkungan (.env).

Prasyarat Instalasi (Pengembangan)

Pastikan perangkat pengembangan Anda telah terinstal:

Flutter SDK (versi stabil terbaru)

Dart SDK (termasuk dalam Flutter SDK)

Android Studio / VS Code dengan ekstensi Flutter & Dart

Akun dan proyek aktif di Supabase

Cara Menjalankan Proyek (Mode Developer)

1. Clone Repositori

git clone https://github.com/ramonnpp/erp-gamamulti-mobile-v2.git
cd erp-gamamulti-mobile-v2


2. Instal Dependensi

flutter pub get


3. Konfigurasi Database & Environment (.env)

Buat file .env pada direktori utama (root) proyek (file ini sudah diabaikan oleh .gitignore agar kredensial tetap aman), lalu isi dengan kredensial Session Pooler dari dashboard Supabase Anda:

DB_HOST=aws-0-ap-southeast-1.pooler.supabase.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres.[project-ref]
DB_PASSWORD=password_database_supabase_anda


(Sesuaikan nama variabel di atas dengan kunci yang digunakan di file .env / database_service.dart proyek Anda).

4. Persiapan Skema Database (Jika Setup Baru)

Jika Anda menyiapkan proyek Supabase baru dari awal:

Aktifkan ekstensi pgcrypto melalui Database > Extensions di dashboard Supabase.

Jalankan skrip skema SQL (DATABASE_SCHEMA.sql / ADMIN_DDL.sql) pada SQL Editor Supabase.

Aktifkan Row Level Security (RLS) pada tabel-tabel di skema public untuk menjaga keamanan API publik.

5. Jalankan & Build Aplikasi

Menjalankan di emulator / perangkat debug:

flutter run


Membuat file APK rilis (app-release.apk):

flutter build apk --release


Struktur Direktori Utama

lib/
├── announcements/         # Layar detail pengumuman
├── services/              # Layanan koneksi PostgreSQL (User & Admin) dan ekspor data
├── theme/                 # Konfigurasi tema dan gaya tampilan aplikasi
├── views/
│   ├── activity_log/      # Tampilan daftar, detail, dan form log aktivitas
│   ├── admin/             # Seluruh layar pengelolaan khusus Admin
│   ├── attendance/        # Layar absensi dan riwayat kehadiran
│   ├── auth/              # Layar login, registrasi, dan penanganan gagal koneksi
│   ├── home/              # Beranda utama karyawan
│   ├── leave/             # Pengajuan dan riwayat cuti serta izin sakit
│   ├── navigation/        # Navigasi utama aplikasi
│   ├── profile/           # Halaman profil pengguna
│   └── splash/            # Layar pembuka (Splash Screen)
└── widgets/               # Komponen UI reusable (snackbar, tombol ekspor, dll.)


Catatan Keamanan

Jangan pernah meng-commit file .env ke repositori Git publik maupun privat.

Pastikan Row Level Security (RLS) selalu aktif pada tabel-tabel di Supabase agar akses melalui kunci publik REST API tetap terkunci.

Ganti placeholder GANTI_DENGAN_LINK_APK_KAMU_DI_SINI pada bagian unduhan dengan tautan file .apk resmi milik internal perusahaan sebelum membagikan repositori.
