# Mesa Turnip A735 — Driver Vulkan untuk Suyu / Eden (Snapdragon 8s Gen 3)

Repo ini adalah **fork build-script** dari [`nihui/mesa-turnip-android-driver`](https://github.com/nihui/mesa-turnip-android-driver) yang dimodifikasi agar driver Vulkan Turnip yang dihasilkan dapat **langsung dipakai** di emulator Nintendo Switch **Suyu** atau **Eden** pada perangkat Android dengan **SoC Snapdragon 8s Gen 3 (SM8635)** dan **GPU Adreno 735**.

## Apa yang berubah dibanding repo asli?

| Bagian | Repo asli (nihui) | Repo ini |
| --- | --- | --- |
| Output build | `libvulkan_freedreno.so` saja | `libvulkan_freedreno.so` **+ zip installable** untuk Suyu/Eden |
| Manifest | tidak ada | `meta.json` + `driver_package_metadata.json` dibuat otomatis |
| Workflow CI | `edge.yml`, `release.yml` (output `.so` saja) | ditambah `build-a735-package.yml` (output zip siap pakai) |
| Patch A735 | tidak ada | `patches/mesa-adreno-735-suyu-eden-tweaks.patch` (dokumentasi + safety) |
| Build lokal | manual, lewat GitHub Actions saja | `build_a735.sh` bisa jalan di Ubuntu/WSL/Termux |
| Packaging | manual | `package_driver.sh` wrap `.so` → zip Suyu/Eden otomatis |

Patch orisinal (`mesa-implement-android_stub.patch` dan `mesa-android-include-all-vulkan-extension.patch`) **tetap utuh** tanpa perubahan — keduanya sudah bagus untuk Switch emulation karena patch "include all Vulkan extension" memaksa semua ekstensi Turnip aktif di Android, termasuk yang penting untuk Suyu/Eden seperti `VK_EXT_transform_feedback`, `VK_EXT_provoking_vertex`, `VK_EXT_extended_dynamic_state*`, `VK_EXT_graphics_pipeline_library`, dan `VK_KHR_fragment_shading_rate`.

## Mengapa tidak ada `.so` yang sudah dikompilasi di repo ini?

Karena:

1. Driver Turnip berlisensi MIT, **boleh** didistribusikan ulang, tapi kompilasinya butuh Mesa source (~250 MB), Android NDK (~1 GB), dan waktu build 20–40 menit di mesin 8-core.
2. Sebagian besar repo custom-driver Android (termasuk nihui aslinya) hanya menyimpan build script — `.so` di-release sebagai artefak GitHub Actions, bukan di-commit.
3. Hasil akhir harus Anda bangun sendiri (lewat CI atau lokal) supaya yakin tidak ada modifikasi tak terdokumentasi di binary.

Lihat **INSTALL-SUZUY-EDEN.md** untuk dua jalur cepat mendapatkan `.so`:

- **Jalur A — GitHub Actions (paling mudah)**: fork repo ini ke akun GitHub Anda, jalankan workflow `build-a735-package.yml`, unduh artefak zip.
- **Jalur B — Build lokal (Ubuntu/WSL/Termux)**: jalankan `./build_a735.sh` dengan NDK terpasang.

## Struktur repo

```
.
├── README.md                              ← file ini
├── INSTALL-SUZUY-EDEN.md                  ← panduan install step-by-step
├── LICENSE                                ← MIT (orisinal nihui)
├── android-aarch64                        ← cross-file meson (NDK r26+)
├── build_a735.sh                          ← build lokal untuk Linux/WSL/Termux
├── package_driver.sh                      ← packaging .so → zip Suyu/Eden
├── meta.json.template                     ← template manifest Suyu/Eden
├── driver_package_metadata.json.template  ← template manifest Android 14+
├── patches/
│   ├── mesa-implement-android_stub.patch              ← orisinal nihui
│   ├── mesa-android-include-all-vulkan-extension.patch ← orisinal nihui
│   └── mesa-adreno-735-suyu-eden-tweaks.patch          ← baru (A735 safety)
└── .github/
    ├── dependabot.yml
    └── workflows/
        ├── edge.yml                       ← orisinal nihui (mesa HEAD)
        ├── release.yml                    ← orisinal nihui (mesa 26.3.0)
        └── build-a735-package.yml         ← BARU: build + package A735
```

## Konfigurasi build yang dipakai

Persis sama dengan repo asli nihui (sudah optimal untuk Adreno):

```bash
meson setup build-android --cross-file ./android-aarch64 \
    -Dbuildtype=release \
    -Dplatforms=android \
    -Dplatform-sdk-version=26 \
    -Dandroid-stub=true \
    -Dvideo-codecs= \
    -Dgallium-drivers= \
    -Dglx=disabled \
    -Degl=disabled \
    -Dvulkan-drivers=freedreno \
    -Dfreedreno-kmds=kgsl \           # KGSL — wajib untuk Adreno 7xx di Android
    -Db_lto=true -Dallow-broken-lto=true -Dstrip=true
```

`-Dfreedreno-kmds=kgsl` adalah kunci untuk Adreno 735: backend KGSL adalah satu-satunya KMD yang berjalan di Android vendor blob. Jangan diganti ke `msm` atau `virtgpu` — itu hanya untuk ChromeOS / Linux mainline.

## Lisensi

MIT, sama dengan repo asli nihui dan Mesa. Lihat `LICENSE`.

## Credits

- **Mesa / freedromo team** — https://gitlab.freedesktop.org/mesa/mesa
- **nihui** — repo build-script asli https://github.com/nihui/mesa-turnip-android-driver
- **v3kt0r-87** — instruksi build awal https://github.com/v3kt0r-87/Mesa-Turnip-Builder
- **lizhangqu** — dlfcn_compat untuk dlopen system lib di Android
