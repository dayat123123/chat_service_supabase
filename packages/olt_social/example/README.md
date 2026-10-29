# olt_social_example

App contoh yang meniru cara OLT memasang `olt_social`:
1. Login "OLT" tiruan: pilih user seed, lalu token mock dipakai.
2. `OltSocial.initialize` dijalankan.
3. Halaman utama menyesuaikan lebar layar:
   - **Windows**: NavigationRail, dengan stream dan detail post berdampingan.
   - **Android**: NavigationBar di bawah.

Menu yang tersedia: Stream, Saham, Chat, Notifikasi, dan Profil. Ada juga tombol untuk mengganti tema terang/gelap dan bahasa ID/EN.

## Menjalankan

Siapkan backend dari root repo:

```bash
make up && make seed            # Windows: .\make.ps1 up; .\make.ps1 seed
```

Ambil `ANON_KEY` dari `docker/.env`, lalu jalankan app.

**Windows:**

```bash
cd packages/olt_social/example
flutter run -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
```

**Android emulator** (otomatis memakai `http://10.0.2.2:8000`):

```bash
flutter run -d emulator-5554 --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
```

**HP fisik di LAN:**
1. Set `KONG_HTTP_BIND=0.0.0.0` di `docker/.env`, lalu jalankan `make up`.
2. Jalankan app dengan URL server:

   ```bash
   flutter run --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY> --dart-define=OLT_SOCIAL_URL=http://<IP-PC>:8000
   ```

Build debug Android mengizinkan HTTP (`android/app/src/debug/AndroidManifest.xml`), sedangkan build release wajib HTTPS.

## E2E test (Windows)

```bash
flutter test integration_test -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
# atau dari root: make e2e-windows / .\make.ps1 e2e-windows
```
