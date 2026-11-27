# Gama Multi ERP Mobile v2

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Database-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

Aplikasi mobile Enterprise Resource Planning (ERP) internal berbasis **Flutter** untuk manajemen operasional karyawan dan administrator **Gama Multi Usaha Mandiri (GMUM)**, terintegrasi langsung dengan database **PostgreSQL (Supabase)**.

---

## Unduh & Instalasi Aplikasi (Android)

[![Download APK](https://img.shields.io/badge/Download-APK_Android_v2.0-3DDC84?style=for-the-badge&logo=android&logoColor=white)](GANTI_DENGAN_LINK_APK_KAMU_DI_SINI)

> **Link Alternatif:** [Klik di sini untuk mengunduh file .apk](GANTI_DENGAN_LINK_APK_KAMU_DI_SINI)

### Cara Instalasi di Perangkat Android:

1. Unduh file **`app-release.apk`** melalui tombol atau link di atas.
2. Buka file `.apk` yang telah diunduh melalui _File Manager_ atau notifikasi browser.
3. Jika muncul peringatan keamanan, aktifkan izin **"Install from Unknown Sources"** (_Izinkan dari sumber ini_).
4. Ketuk **Install** dan tunggu proses selesai.

---

## Arsitektur Sistem

Aplikasi ini menghubungkan lapisan layanan database Flutter (`database_service.dart` & `admin_database_service.dart`) langsung ke instance PostgreSQL **Supabase** melalui **Supavisor Session Pooler** dengan koneksi terenkripsi SSL.

```mermaid
flowchart LR
    subgraph MobileApp ["📱 Flutter Mobile App (erp-gamamulti-mobile-v2)"]
        UI_User["👤 User Screens\n(Absensi, Cuti, Log, Pengumuman)"]
        UI_Admin["🛡️ Admin Screens\n(Manajemen User, Approval, Rekap)"]
        SVC_User["database_service.dart"]
        SVC_Admin["admin_database_service.dart"]
        ENV[".env\n(flutter_dotenv)"]
    end

    subgraph SupabaseCloud ["☁️ Supabase Cloud"]
        Pooler["Supavisor Session Pooler\n(Port 5432 • IPv4 • SSL Required)"]
        DB[("PostgreSQL Database\n(Users, Attendance, Leaves, Logs)")]
    end

    UI_User --> SVC_User
    UI_Admin --> SVC_Admin
    ENV -.->|Load Credentials| SVC_User
    ENV -.->|Load Credentials| SVC_Admin
    SVC_User -->|TCP + SSL| Pooler
    SVC_Admin -->|TCP + SSL| Pooler
    Pooler --> DB
```
