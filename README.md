# Shortqut

Action ring ringan untuk macOS, terinspirasi dari action ring Logitech. Ketuk trackpad dengan 4 jari, dan lingkaran aksi muncul tepat di posisi kursor. Pilih aksi dengan menggerakkan kursor lalu klik.

Dibuat dengan SwiftUI dan AppKit agar tampilannya terasa native di macOS, termasuk dukungan dark mode dan material sistem.

## Fitur

- **Aktivasi dengan 4 jari:** ketuk trackpad dengan 4 jari untuk membuka atau menutup ring di posisi kursor.
- **Aktivasi dengan Command:** tekan Command dua kali dengan cepat untuk membuka atau menutup ring.
- **Aplikasi pilihan sendiri:** tambahkan aplikasi ke ring lewat menu **Pengaturan…**. Ikon asli aplikasi ditampilkan di ring.
- **Aksi native yang bisa diatur:** pilih dari Screenshot (⇧⌘4), Mission Control, Kunci Layar (⌃⌘Q), Rekam Layar (⇧⌘5), dan Putar/Jeda, atau tambahkan Shortcut dari aplikasi Shortcuts lewat **Jalankan Shortcut…**. Default awal hanya Screenshot.
- **Batas ring:** total aksi native dan aplikasi maksimal 12 item.
- **Tanpa Dock:** Shortqut hanya berada di menu bar.
- **Tutup dengan mudah:** klik di luar ring atau di area tengah untuk menutup tanpa menjalankan aksi.

## Persyaratan

- macOS 14 (Sonoma) atau lebih baru
- Trackpad
- Xcode Command Line Tools (untuk build dari source)

## Instalasi

### Dari DMG

1. Buka `Shortqut-<versi>.dmg`.
2. Seret **Shortqut** ke folder **Applications**.
3. Buka Shortqut dari Applications.

Jika macOS memblokir app karena belum dinotarisasi, klik kanan Shortqut → **Open**, atau jalankan:

```bash
xattr -dr com.apple.quarantine /Applications/Shortqut.app
```

### Build dari source

```bash
git clone https://github.com/<username>/shortqut.git
cd shortqut
./scripts/make-app.sh        # membuat build/Shortqut.app
open build/Shortqut.app
```

Untuk membuat DMG:

```bash
./scripts/make-dmg.sh        # membuat build/Shortqut-<versi>.dmg
```

## Pengaturan izin

Shortqut membutuhkan izin **Aksesibilitas** agar aksi keyboard (misalnya Screenshot) bisa dikirim.

1. Buka menu bar Shortqut → **Berikan Izin Aksesibilitas…**
2. Aktifkan Shortqut di **System Settings → Privacy & Security → Accessibility**.

Jika double-press Command tidak berfungsi, aktifkan juga Shortqut di **Privacy & Security → Input Monitoring**.

## Cara menggunakan

| Aksi | Cara |
| --- | --- |
| Membuka ring | Ketuk trackpad dengan 4 jari, atau tekan Command dua kali |
| Memilih aksi | Gerakkan kursor ke slice, lalu klik |
| Menutup tanpa aksi | Klik di luar ring atau di tengah |
| Membuka Pengaturan | Menu bar → **Pengaturan…** (⌘,) |

Di Pengaturan, Anda bisa menambahkan aplikasi lewat **Tambah Aplikasi…** dan menghapusnya dengan tombol −. Finder dan Terminal dipasang secara default.

## Struktur proyek

```
Sources/Shortqut/
├── ShortqutApp.swift            # Entry point, menu bar, dan AppDelegate
├── TrackpadGestureMonitor.swift # Deteksi ketukan 4 jari (MultitouchSupport)
├── CommandDoubleTapMonitor.swift# Deteksi double-press Command
├── RingPanelController.swift    # Panel transparan dan posisi di kursor
├── RingView.swift               # Geometri dan tampilan ring
├── RingAppStore.swift           # Daftar aplikasi pilihan (maks. 11)
├── ShortcutItem.swift           # Model aksi dan eksekusi aksi
├── SettingsView.swift           # Jendela Pengaturan
└── Permissions.swift            # Izin Aksesibilitas
scripts/
├── make-app.sh                  # Build release dan bundle .app
├── make-dmg.sh                  # Membuat DMG (opsional sign dan notarisasi)
├── make-icon.swift              # Menggambar ikon 1024×1024
└── make-icon.sh                 # Membuat AppIcon.icns
```

## Kustomisasi

- **Batas item ring:** ubah `RingLimits.maxItems` di [NativeShortcutStore.swift](Sources/Shortqut/NativeShortcutStore.swift).
- **Aksi native:** tambah atau ubah kasus `NativeShortcut` di [NativeShortcutStore.swift](Sources/Shortqut/NativeShortcutStore.swift).
- **Ukuran ring:** ubah `canvas`, `inner`, dan `outer` di [RingView.swift](Sources/Shortqut/RingView.swift), serta `size` di `RingController` dalam [RingPanelController.swift](Sources/Shortqut/RingPanelController.swift).
- **Celah antar slice:** ubah `gapPoints` di [RingView.swift](Sources/Shortqut/RingView.swift).
- **Sensitivitas ketukan:** ubah `maxTapDuration`, `maxDrift`, dan `cooldown` di [TrackpadGestureMonitor.swift](Sources/Shortqut/TrackpadGestureMonitor.swift).
- **Jeda double-press Command:** ubah `maxInterval` di [CommandDoubleTapMonitor.swift](Sources/Shortqut/CommandDoubleTapMonitor.swift).
- **Ikon:** jalankan `./scripts/make-icon.sh` setelah mengubah [make-icon.swift](scripts/make-icon.swift).

## Catatan teknis

- Deteksi ketukan trackpad memakai framework privat **MultitouchSupport** yang dimuat dengan `dlopen`. Ini bukan API publik Apple, jadi bisa berubah di versi macOS berikutnya.
- Karena memakai API privat, Shortqut **tidak bisa dikirim ke Mac App Store**. Distribusi dilakukan lewat DMG.
- Aksi keyboard dikirim lewat `CGEvent` dan membutuhkan izin Aksesibilitas.

## Lisensi

Belum ditentukan.
