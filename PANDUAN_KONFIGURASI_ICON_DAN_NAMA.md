# 📱 PANDUAN KONFIGURASI APLIKASI GAMA MULTI ERP

## 1. MENGUBAH ICON APLIKASI

### Langkah 1: Siapkan File Icon

- Buat icon **PNG** ukuran **192x192 pixel** atau lebih besar (gunakan Figma/Photoshop/GIMP).
- Nama file: `app_icon.png`
- Tempat: `assets/icon/app_icon.png`
- **Penting**: Icon harus **square** dan **tidak transparan di background** (full warna/gambar).

### Langkah 2: Konfigurasi sudah di `pubspec.yaml`

```yaml
flutter_launcher_icons:
  image_path: "assets/icon/app_icon.png"
  image_path_ios: "assets/icon/app_icon_ios.png"
  android: true
  ios: true
```

### Langkah 3: Jalankan Perintah Generate Icon

Buka terminal di folder project dan jalankan:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

**Output**: Icon otomatis di-generate untuk semua platform:

- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## 2. MENGUBAH NAMA APLIKASI

### A. ANDROID

**File**: `android/app/src/main/AndroidManifest.xml`

Cari tag `<application>` dan ubah:

```xml
<application
    android:label="Gama Multi ERP"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:requestLegacyExternalStorage="true">
```

✅ Nama aplikasi di home screen Android: **Gama Multi ERP**

---

### B. iOS

**File**: `ios/Runner/Info.plist`

Cari key `CFBundleDisplayName` dan set value:

```xml
<key>CFBundleDisplayName</key>
<string>Gama Multi ERP</string>
```

Jika tidak ada, tambahkan sebelum closing `</dict>`:

```xml
<dict>
  ...
  <key>CFBundleDisplayName</key>
  <string>Gama Multi ERP</string>
</dict>
```

✅ Nama aplikasi di home screen iOS: **Gama Multi ERP**

---

### C. WINDOWS (Optional)

**File**: `windows/runner/Runner.rc`

Cari baris `ProductName` dan ubah:

```
VALUE "ProductName", "Gama Multi ERP\0"
```

---

### D. MACOS (Optional)

**File**: `macos/Runner/Info.plist`

Sama seperti iOS:

```xml
<key>CFBundleDisplayName</key>
<string>Gama Multi ERP</string>
```

---

## 3. TESTING PERUBAHAN

```bash
# Clean build cache
flutter clean

# Rebuild aplikasi
flutter pub get
flutter run
```

Atau untuk specific platform:

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

---

## 4. BUILD UNTUK RELEASE

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

### iOS IPA

```bash
flutter build ios --release
# Output: build/ios/iphoneos/Runner.app
```

---

## 📋 CHECKLIST VERIFIKASI

- [x] File `assets/icon/app_icon.png` sudah di-upload (192x192 PNG)
- [x] Config `pubspec.yaml` sudah di-set
- [x] Jalankan `flutter pub run flutter_launcher_icons`
- [x] Update `AndroidManifest.xml` dengan nama "Gama Multi ERP"
- [x] Update `ios/Runner/Info.plist` dengan nama "Gama Multi ERP"
- [x] Jalankan `flutter clean && flutter pub get`
- [x] Test di emulator/device: `flutter run`

---

## ⚠️ CATATAN PENTING

1. **Icon Android**: Jangan pakai icon dengan transparency penuh. Background harus solid.
2. **Icon iOS**: iOS memerlukan icon terpisah. Jika hanya Android, gunakan `image_path` saja.
3. **Build Cache**: Selalu `flutter clean` sebelum rebuild jika ada perubahan icon.
4. **Testing Device**: Uninstall app lama sebelum testing perubahan nama.
5. **Play Store / App Store**: Jika publish, ikuti guideline platform untuk app name & icon.
