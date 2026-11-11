# Panduan Install — Driver Turnip A735 untuk Suyu / Eden

Dokumen ini menjelaskan **dua jalur** mendapatkan driver `.so` (kompilasi sendiri), lalu **cara memasangnya** di Suyu dan Eden pada perangkat Android Snapdragon 8s Gen 3 / Adreno 735.

---

## Bagian 1 — Mendapatkan file `.so` (pilih salah satu jalur)

### Jalur A — Build via GitHub Actions (paling mudah, tanpa install apa pun di komputer Anda)

1. **Fork repo ini** ke akun GitHub Anda.
   - Buka halaman repo → tombol **Fork** di kanan atas.
2. **Aktifkan Actions**:
   - Di repo fork Anda, klik tab **Actions**.
   - Jika ada banner "Workflows aren't being run", klik **I understand my workflows, go ahead and enable them**.
3. **Jalankan workflow build**:
   - Di sidebar kiri, pilih **build-a735-package**.
   - Klik **Run workflow** → biarkan `mesa_version` = `26.3.0` → **Run workflow**.
   - Build berjalan sekitar 25–40 menit (Ubuntu runner GitHub gratis).
4. **Unduh artefak**:
   - Setelah workflow selesai (centang hijau), buka run tersebut → scroll ke bawah ke **Artifacts**.
   - Unduh `mesa-turnip-a735-suyu-eden-26.3.0.zip` (ukuran ~12–18 MB).
   - **Ini sudah lengkap** untuk Suyu/Eden — berisi `libvulkan_freedreno.so` + `meta.json`. Langsung ke **Bagian 2**.

### Jalur B — Build lokal di Ubuntu / WSL / Termux

1. **Siapkan toolchain** (Ubuntu 22.04+ atau Debian 12):

   ```bash
   sudo apt-get update
   sudo apt-get install -y \
       build-essential wget git python3-pip ccache \
       meson ninja-build flex bison \
       python3-mako python-is-python3 \
       glslang-tools patchelf pkg-config zip
   ```

2. **Install Android NDK r26 atau lebih baru**:
   - Unduh dari https://developer.android.com/ndk/downloads
   - Ekstrak, lalu set env:
     ```bash
     export ANDROID_NDK_HOME=/opt/android-ndk-r26c
     ```
   - Atau via Android Studio: **SDK Manager → SDK Tools → NDK (Side by side)**, lokasi default `~/Android/Sdk/ndk/<versi>`. Script akan auto-detect ini.

3. **Jalankan build**:
   ```bash
   cd /path/ke/mesa-turnip-a735-suyu-eden-26.3.0
   chmod +x build_a735.sh package_driver.sh
   ./build_a735.sh
   ```

   - Build pertama: unduh Mesa 26.3.0 (~250 MB) + kompilasi 20–40 menit.
   - Build ulang dengan cache: ~5 menit.

4. **Hasil ada di `out/`**:
   - `out/libvulkan_freedreno.so` — driver mentah
   - `out/mesa-turnip-a735-suyu-eden-26.3.0.zip` — package siap install di Suyu/Eden

### Jalur C — Pakai prebuilt dari komunitas (cepat, tapi bukan dari repo ini)

Jika Anda hanya butuh driver yang berjalan dan tidak ingin build sendiri:

- **StevenMXZ/Adreno-Tools-Drivers**: https://github.com/StevenMXZ/Adreno-Tools-Drivers/releases (build otomatis per 2 minggu, format adrenotools)
- **Mesa Turnip oleh CARTOON Maya / Adrenotools Hub**: driver pack yang sudah diuji komunitas untuk SD 8s Gen 3
- **Catatan**: driver prebuilt dari pihak ketiga mungkin tidak persis sama versinya dengan build repo ini. Untuk konsistensi penuh dengan patch A735 di repo ini, gunakan Jalur A atau B.

---

## Bagian 2 — Memasang driver di emulator

### 2A. Suyu

Suyu menyimpan driver kustom di direktori internal aplikasi dan mengekspos UI untuk memilihnya.

1. **Salin zip ke penyimpanan yang dapat diakses Suyu**:
   - zip: `mesa-turnip-a735-suyu-eden-26.3.0.zip`
   - Lokasi yang aman: `Download/` internal atau SD card eksternal.

2. **Buka Suyu** → menu tiga garis (kiri atas) → **Settings** → **Graphics**.

3. **Scroll ke bawah ke bagian "Custom Driver"**:
   - Klik **Install custom driver…**
   - File picker akan terbuka. Arahkan ke zip tadi.
   - Klik **Select** / **OK**.

4. **Pilih driver**:
   - Setelah install, dropdown **Driver** akan menampilkan `Mesa Turnip A735 (Suyu/Eden) — 26.3.0-a735`.
   - Pilih driver tersebut. Restart game.

5. **Verifikasi driver aktif**:
   - Game berjalan → menu tiga garis → **Graphics Info**.
   - Baris **Driver** harus menampilkan versi Turnip, **bukan** "Qualcomm driver version 26.x".
   - Anda juga bisa cek dengan `logcat` (via `adb logcat | grep -i tu`), akan muncul baris seperti:
     ```
     tu: Adreno 735 (chip_id=0x43050a) — using a735 device table entry
     ```

### 2B. Eden

Eden (https://git.eden-emu.dev/eden-emu/eden) memiliki mekanisme load driver yang serupa Suyu, plus ada halaman khusus untuk pengaturan Turnip sejak v0.0.3.

1. **Salin zip ke penyimpanan yang dapat diakses Eden**.

2. **Buka Eden** → menu tiga titik (kanan atas) → **Settings** → **Graphics**.

3. **Bagian "Custom Vulkan Driver"**:
   - Klik **Install**.
   - Pilih zip `mesa-turnip-a735-suyu-eden-26.3.0.zip`.
   - Setelah install, dropdown akan menampilkan `Mesa Turnip A735 (Suyu/Eden)`.

4. **Pengaturan tambahan Turnip (Eden 0.0.3+)**:
   - Pada Eden 0.0.3 ada halaman **"Turnip Driver Settings"** yang muncul setelah driver Turnip dipilih.
   - Untuk A735 pada Suyu/Eden, rekomendasi awal:
     - **Aspect ratio**: Default
     - **GPU accuracy**: High
     - **Anisotropic filtering**: 16x
     - **Reactive flushing**: ON (wajib untuk game-game Switch tertentu)
     - **Sync**: Async (latensi rendah) — ganti ke Fifo kalau ada tearing
     - **Shader backend**: GLSL
   - Sesuaikan per-game via **Game properties → Graphics**.

5. **Verifikasi**:
   - Game berjalan → menu in-game → **Graphics Info**.
   - Pastikan `Driver: Mesa Turnip` terlihat.

### 2C. Adrenotools (root) — alternatif untuk semua emulator

Jika device Anda sudah root dan punya [Adrenotools](https://github.com/bylaws/adrenotools) terpasang (via Magisk module atau app Adreno Tools):

1. Salin zip ke `/sdcard/Download/`.
2. Buka app **Adreno Tools**.
3. **Install driver** → pilih zip.
4. Aktifkan driver (toggle).
5. Reboot.
6. Driver Turnip sekarang aktif untuk **semua** app Vulkan, termasuk Suyu/Eden tanpa perlu load custom driver per-app.

Ini lebih boros tapi paling konsisten — semua emulator (termasuk Dolphin, PPSSPP, Citra MMJ) ikut pakai Turnip.

---

## Bagian 3 — Troubleshooting

### Gejala: emulator crash setelah load driver

Kemungkinan:
- **GPU tidak terdeteksi sebagai A735** — beberapa firmware OEM melaporkan chip_id beda. Cek `adb logcat | grep "tu:"`. Jika terlihat "unknown a7xx gpu", lihat catatan di `patches/mesa-adreno-735-suyu-eden-tweaks.patch` dan tambahkan chip_id Anda ke `freedreno_devices.py` sebelum build.
- **Android terlalu lama (di bawah 8.0/API 26)** — patch android_stub butuh API 26 minimum. Update OS atau pakai driver lama (Mesa 23.x).
- **Konflik dengan driver stock di /vendor** — beberapa OEM lock `dlopen` untuk `libvulkan.so`. Pakai Adrenotools (Bagian 2C) untuk override.

### Gejala: game berjalan tapi lambat / stutter

- Aktifkan **Pipeline caching** di Settings → Graphics di Suyu/Eden.
- Di Eden 0.0.3+, set **"Pipeline compile"** ke `Async` (bukan `Synchronous`).
- Jika ada shader compile stutter parah, coba set env (di Eden: Settings → Advanced → Environment Variables):
  ```
  MESA_VK_WSI_PRESENT_MODE=immediate
  TU_DEBUG=gnu_spilling
  ```
  (Hanya gunakan `TU_DEBUG=gnu_spilling` kalau ada glitch — itu memaksa spilling ke sysmem yang lebih lambat tapi kadang stabilkan game tertentu.)

### Gejala: grafik glitch (artifact, flicker, hitam)

- Set **GPU accuracy** ke **High** (bukan Normal).
- Aktifkan **Reactive flushing**.
- Coba dengan `TU_DEBUG=nomultipos` untuk game yang vertex-nya berantakan.
- Lihat daftar game + setting optimal komunitas di r/EmulationOnAndroid atau wiki Eden.

### Gejala: logcat penuh "vkEnumeratePhysicalDevices failed"

Driver tidak dimuat. Cek:
- zip punya `libvulkan_freedreno.so` di root (bukan di subfolder).
- `meta.json` ada dan field `libraryName` cocok dengan nama file.
- `.so` adalah ELF ARM64 (cek di komputer dengan `file libvulkan_freedreno.so` — harus mengatakan `ELF 64-bit LSB shared object, ARM aarch64`).

### Suyu tidak menemukan driver zip

Beberapa versi Suyu hanya menerima `.zip` yang **semua file** ada di root tanpa subfolder. Script `package_driver.sh` sudah memakai `zip -j` (junk paths) supaya flat. Jika Anda zipping manual, pastikan pakai `-j`:

```bash
cd /tmp/packdir
zip -9 -j output.zip libvulkan_freedreno.so meta.json
```

---

## Bagian 4 — Verifikasi cepat sebelum install

Setelah build selesai (lokal atau CI), jalankan di komputer:

```bash
# Cek ELF adalah ARM64
file out/libvulkan_freedreno.so
# Expected: ELF 64-bit LSB shared object, ARM aarch64, ...

# Cek ukuran (driver Turnip release 26.3.0 biasanya 8–15 MB)
du -h out/libvulkan_freedreno.so

# Cek isi zip
unzip -l out/mesa-turnip-a735-suyu-eden-26.3.0.zip
# Expected:
#   libvulkan_freedreno.so
#   meta.json
#   driver_package_metadata.json

# Cek meta.json
unzip -p out/mesa-turnip-a735-suyu-eden-26.3.0.zip meta.json | python3 -m json.tool
```

Jika semua di atas oke, zip siap dipindah ke ponsel dan dipasang via Bagian 2.

---

## Bagian 5 — Setelan grafis yang direkomendasikan untuk SD 8s Gen 3 / A735

Pengaturan awal yang stabil pada game Switch populer (tested di game seperti *Super Mario Odyssey*, *Animal Crossing*, *Pokémon Scarlet/Violet*). Mulai dari sini lalu tweak per-game:

| Pengaturan | Suyu | Eden |
| --- | --- | --- |
| API | Vulkan | Vulkan |
| GPU accuracy | High | High |
| Shader backend | GLSL | GLSL |
| Reactive flushing | ON | ON |
| Pipeline compile | Async | Async |
| Use disk pipeline cache | ON | ON |
| Use asynchronous GPU emulation | ON | ON |
| Aspect ratio | Default (16:9) | Default |
| Anisotropic filtering | 16x | 16x |
| VSync | Async | Async |
| Resolution scale | 1x (1080p) atau 2x untuk game ringan | 1x atau 1.5x |
| Max anisotropy | 16 | 16 |

Untuk game berat (*Tears of the Kingdom*, *Xenoblade 3*):
- Turunkan resolution scale ke 720p (0.75x).
- Set **GPU accuracy** ke **Normal** (lebih cepat, sebagian glitch bisa muncul).
- Matikan **Reactive flushing** jika tidak ada artifact.

Cek komunitas (subreddit r/EmulationOnAndroid, Discord Eden/Suyu) untuk game-specific settings.

---

## Lisensi

MIT — lihat `LICENSE` di root repo. Driver Turnip itu sendiri (libvulkan_freedreno.so) juga MIT sebagai bagian dari Mesa.
