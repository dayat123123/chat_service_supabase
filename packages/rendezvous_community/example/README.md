# rendezvous_community_example

App contoh yang meniru cara OLT memasang `rendezvous_community`:
1. Login "OLT" tiruan, dengan dua cara:
   - pilih user seed (login cepat): bila OLT dummy berjalan, akun ditukar menjadi token sosial bertanda tangan; bila tidak, token mock dipakai (stack default), atau
   - form **"Login OLT dummy"**: username/email + password ke server OLT dummy, lalu token sosial dari OLT dipakai. Cara ini butuh stack `make up DUMMY_OLT=1`, lihat [bagian di bawah](#login-olt-dummy).
2. `RendezvousCommunity.initialize` dijalankan.
3. Halaman utama menyesuaikan lebar layar:
   - **Windows** dan **web** (layar lebar): NavigationRail, dengan stream dan detail post berdampingan.
   - **Android**: NavigationBar di bawah.

Menu yang tersedia: Stream, Saham, Chat, Notifikasi, dan Profil. Ada juga tombol untuk mengganti tema terang/gelap, bahasa ID/EN, dan gaya chat bawaan/kustom.

Fitur 1.3.0 bisa dicoba dari tombol **Jelajah** (ikon kompas): Cari, Trending, Disimpan, Permintaan pesan, Notifikasi (preferensi & jam tenang), Banding saya, dan **Bagikan chart** (membuat gambar chart contoh dengan `dart:ui` lalu membuka `showCommunityComposer(initialStock:, initialImage:)`). Halaman Saham menampilkan `CommunityStockSentiment`, tombol "Bagikan chart", dan tombol "Beli" yang memanggil `trackOrderTap()`. Permintaan pesan muncul di atas daftar Chat bila ada; pengaturan pesan langsung, notifikasi, dan banding ada di Privasi & akun. App memasang `CommunityUpdateListener` yang menampilkan dialog bila server mewajibkan update (`appVersion: '1.3.0'`). Tombol gaya chat (ikon palet) memasang contoh builder dari `lib/custom_chat_style.dart` lewat `CommunityChatBuildersScope`: gelembung pesan, composer, tile daftar chat, dan pemisah hari versi host, dengan logika tetap dari package.

## Menjalankan

Siapkan backend dari root repo:

```bash
make up && make seed            # Windows: .\make.ps1 up; .\make.ps1 seed
```

Ambil `ANON_KEY` dengan `make anon-key` (Windows: `.\make.ps1 anon-key`; tersimpan di `docker/secrets/anon_key`), lalu jalankan app.

**Windows:**

```bash
cd packages/rendezvous_community/example
flutter run -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
```

**Android emulator** (otomatis memakai `http://10.0.2.2:8000`):

```bash
flutter run -d emulator-5554 --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
```

**HP fisik di LAN:**
1. Set `EDGE_HTTP_BIND=0.0.0.0` di `docker/.env`, lalu jalankan `make up`.
2. Jalankan app dengan URL server:

   ```bash
   flutter run --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY> --dart-define=OLT_SOCIAL_URL=http://<IP-PC>:8000
   ```

Build debug Android mengizinkan HTTP (`android/app/src/debug/AndroidManifest.xml`), sedangkan build release wajib HTTPS.

**Web** (paling praktis untuk testing beberapa user sekaligus):

```bash
make web-example                # Windows: .\make.ps1 web-example
```

Perintah ini mem-build app ke `build/web`, lalu menyajikannya lewat container Caddy `olt-web-example` di `http://localhost:8081`. Setelah mengubah kode, jalankan lagi untuk build ulang. Untuk menghentikan: `docker rm -f olt-web-example`.

- `http://localhost:8081/?user=sari_invest` langsung masuk sebagai Sari (token mock). Nilai lain: `budi_santoso`, `andi_trader`, `rina_saham`, `dewi_cuan`, `hidayat` (LoginId csAdmin uji), `hidayat2`, atau id OLT-nya (mis. `1002`).
- Sesi hanya disimpan di memori tab, jadi tiap tab bisa menjadi user berbeda. Chat, indikator mengetik, like, komentar, dan notifikasi realtime bisa dicoba antara tab dengan tab, atau tab dengan app Windows.
- Form "Login OLT dummy" juga berfungsi di web (stack `make up DUMMY_OLT=1`).
- Untuk development dengan hot reload: `flutter run -d chrome --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>`.

## Login OLT dummy

1. Nyalakan stack dengan OLT dummy:

   ```bash
   make up DUMMY_OLT=1 && make seed     # Windows: .\make.ps1 up -DummyOlt; .\make.ps1 seed
   ```

   Dengan ini auth-bridge berjalan dalam mode `jwt` (seperti produksi), dan dummy-olt mendengarkan di `ws://localhost:8090/ws`.
2. Di layar login, isi form "Login OLT dummy". Contoh: `budi_santoso` atau `sari@olt.test`, dengan password `olt12345`.
3. App membuka WebSocket ke OLT dummy dan menerima token sesi `olt_...` beserta **token sosial** (JWT, 10 menit).
4. `tokenProvider` mengembalikan token sosial. Bila sisa umurnya kurang dari 1 menit, app meminta yang baru lewat pesan `social_token` dengan token sesi ([`lib/fake_olt_auth.dart`](lib/fake_olt_auth.dart)). Pola inilah yang perlu ditiru app OLT asli.

**Alamat OLT dummy** diturunkan dari URL sosial dengan port 8090. Misalnya emulator Android memakai `ws://10.0.2.2:8090/ws`. Untuk mengganti alamatnya: `--dart-define=OLT_DUMMY_WS_URL=ws://<host>:8090/ws`.

Tombol user seed tetap berfungsi dalam mode ini: token mock ditukar dulu menjadi token sosial lewat OLT dummy.

## E2E test (Windows)

```bash
flutter test integration_test/app_test.dart -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
# atau dari root: make e2e-windows / .\make.ps1 e2e-windows

# form login OLT dummy (butuh make up DUMMY_OLT=1):
make e2e-windows-dummy          # Windows: .\make.ps1 e2e-windows-dummy
```

Tes klien WebSocket OLT dummy (tanpa UI) ada di `test/dummy_olt_client_test.dart` dan dilewati kecuali `OLT_DUMMY_IT=1`:

```bash
OLT_DUMMY_IT=1 flutter test test/dummy_olt_client_test.dart     # Windows: $env:OLT_DUMMY_IT=1; flutter test ...
```
