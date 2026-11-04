# Rendezvous Hub (web CS, React)

Rendezvous Hub adalah konsol customer service OLT untuk CS, Super Admin, dan Kepatuhan, sekaligus satu-satunya web CS. React 19 + TypeScript, dibangun Vite menjadi SPA statis dan disajikan nginx non-root. Backend: Supabase (`cs_api`, GoTrue, Realtime, Storage) dan Edge Function `cs-admin`.

Web CS tidak mengambil data bisnis dari OLT. Profil, order, transaksi dana, dan perangkat nasabah tetap milik aplikasi nasabah, jadi panel info nasabah hanya menampilkan identitas nasabah dari data tiket, riwayat tiket (`customer_history`), dan catatan internal (`notes`).

Rencana dan keputusan: [docs/PROMPT-CS-CONSOLE-REACT.md](../../docs/PROMPT-CS-CONSOLE-REACT.md), [docs/cs-console-audit.md](../../docs/cs-console-audit.md), paritas dengan console Flutter: [docs/cs-console-parity.md](../../docs/cs-console-parity.md). Tampilan: [docs/PROMPT-CS-UI-POLISH.md](../../docs/PROMPT-CS-UI-POLISH.md) dan [docs/cs-ui-audit.md](../../docs/cs-ui-audit.md).

## Peran

| Peran                          | Di web CS                                                                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| CS (`cs_agent`)                | Status kerja dan batas tiket aktif, ambil tiket, balas nasabah, catatan internal, tunggu nasabah, lepas, transfer, selesaikan        |
| Super Admin (`cs_super_admin`) | Memantau tanpa menangani tiket, dashboard, laporan, dan pengaturan                                                                   |
| Kepatuhan (`compliance`)       | Ringkasan, register kasus pengaduan dan penipuan, jejak audit, dan kebijakan (lihat [kepatuhan.md](../../docs/cs-chat/kepatuhan.md)) |

Super Admin menggantikan peran supervisor dan admin CS yang lama. Super Admin bekerja dalam mode pantau: top bar menampilkan "Mode pantau" sebagai ganti status kerja dan jumlah tiket aktif. Super Admin membaca semua tiket hanya-baca (tab Semua aktif dan Terbuka), membaca dan menambah catatan internal, mengubah prioritas tiket aktif, dan lewat "Pindahkan ke…" membagikan tiket terbuka atau memindahkan tiket aktif ke CS. Super Admin tidak mengambil, membalas, melepas, mentransfer, menunggu nasabah, atau menyelesaikan tiket, dan tidak pernah menerima tiket. Pengaturan berisi akun CS (tambah, ubah, nonaktifkan, reset password), topik, quick reply, jam layanan dan libur, pesan otomatis, penugasan dan alert, **Integrasi OLT** (API key notifEngine/bot resmi: izin, akun resmi bot, IP/CIDR, batas per menit, nonaktif sementara, cabut dengan alasan, statistik per key dan per hari, panduan curl; key hanya ditampilkan sekali dan tidak disimpan di cache), serta **Fitur & versi** (kill switch fitur sosial dengan alasan dan ketik konfirmasi, feature flag, versi minimum aplikasi per platform). Menu **Analitik** berisi DAU/WAU/MAU, stickiness, kohort retensi mingguan, konten, saham terpopuler, event aplikasi, dan ketukan order dari fitur sosial. Akun yang juga berperan CS tetap bekerja sebagai CS dan mendapat semua menu Super Admin.

Kepatuhan tidak menangani tiket dan tidak punya status kerja; login dan keluar tidak mengubah status. Akun yang hanya berperan Kepatuhan langsung masuk ke Ringkasan. Menu:

- **Ringkasan**: pengaduan aktif, jatuh tempo ≤ 1 hari kerja, lewat tenggat, ketepatan waktu 30 hari, penipuan aktif, kasus selesai yang belum ditinjau, serta sinyal keamanan (laporan CS palsu dan CS yang mencoba meminta PIN/OTP/password). Banner muncul bila ada kebijakan yang belum dikonfirmasi.
- **Kasus**: register pengaduan dan penipuan dengan filter jenis, keadaan, periode, dan pencarian, plus ekspor CSV. Panel detail berisi transkrip (pesan + catatan internal), riwayat kejadian, tinjauan (Sesuai / Perlu tindak lanjut / Pelanggaran, append-only), perpanjangan tenggat sekali sebelum lewat (nasabah langsung diberi tahu), dan unduh transkrip `.txt` yang sidik SHA-256-nya dicatat di audit log. Membuka detail kasus tercatat sebagai akses data nasabah.
- **Jejak Audit**: audit log append-only dengan filter periode, aksi, dan pencarian, halaman bertahap, ekspor CSV (maksimal 5.000 baris).
- **Kebijakan**: konfirmasi atau ubah tenggat pengaduan, perpanjangan tenggat, dan retensi chat, beserta riwayat perubahan.
- **Kata terlarang**: daftar kata atau frasa yang disensor atau diblokir di post, komentar, polling, dan chat aplikasi nasabah. Cari, saring per aksi, tambah, ubah aksi, hapus, unduh Excel, dan import Excel (`.xlsx` atau `.csv`, kolom A kata, kolom B sensor/blokir, maksimal 1.000 baris) dengan pratinjau baris baru, aksi berubah, duplikat, dan tidak valid. Template berisi sheet petunjuk. Maksimal 2.000 kata; semua perubahan tercatat di Jejak Audit.
- **Kebijakan konten**: aksi dan cakupan per kategori, masa akun baru, domain diblokir (domain/kata kunci) dan domain tepercaya, frasa promosi dan istilah pengecualian, ambang moderasi gambar (tahan ≤ blokir), pengaturan anti-manipulasi saham, dan uji teks terhadap aturan yang berlaku (lihat [docs/content-safety.md](../../docs/content-safety.md)).

Menu **Akun Nasabah** (data nasabah online dari csAdmin lewat `nasabah-gateway`, letaknya sebelum Pengaturan) khusus akun berperan CS: Super Admin memberi izin per akun CS di Pengaturan → Akun CS. Ringkasan di atas tab menampilkan jumlah Online ID dan pengajuan yang menunggu. Tab yang tampil mengikuti izin: Online ID (cari, lihat, rekening tertaut, ajukan buat/ubah/hapus, reset password/PIN, ubah status cepat dengan alasan, penanda data belum lengkap), Approval (setujui/tolak pengajuan CS lain; pengajuan sendiri hanya dengan izin approve sendiri), dan Pembukaan rekening (kirim email satu per satu atau beberapa sekaligus). Lihat [docs/nasabah/README.md](../../docs/nasabah/README.md).

Menu **Komunitas** mengikuti izin komunitas per staf. Moderasi berisi antrean Laporan, Konten ditahan, Gambar ditahan (gambar buram sampai dibuka, loloskan atau hapus dengan alasan), Indikasi manipulasi (bukti, tinjau atau tolak dengan catatan), dan Banding (peninjau harus berbeda dari pemberi keputusan awal). Panel pengguna menampilkan riwayat edit konten dan aksi toleransi nol (CSAM) dengan dua tahap konfirmasi. Tab Room saham mengatur slow mode dan pesan yang disematkan.

## Login dan password

- Login cukup email + password, tanpa TOTP. Web CS hanya bisa diakses dari IP yang diizinkan (LAN kantor atau VPN). Faktor TOTP lama yang masih terdaftar di akun diabaikan.
- Akun dengan password sementara (akun baru atau setelah reset) wajib mengganti password sebelum masuk ruang kerja.
- Super Admin mereset password lupa lewat Pengaturan → Akun CS → "Reset password". Setelah konfirmasi, Edge Function `cs-admin` (`POST /functions/v1/cs-admin/agents/{id}/reset-password`) membuat password sementara baru yang hanya ditampilkan sekali dengan tombol salin, dan password lama langsung tidak berlaku. Tombol ini tidak ada untuk akun nonaktif (aktifkan dulu) dan untuk akun sendiri.

## Menjalankan

Prasyarat: stack dev dengan OLT dummy dan akun staf dev.

```bash
make up DUMMY_OLT=1          # Windows: .\make.ps1 up -DummyOlt
make cs-staff                # akun Nadia, Bima, Laras (CS), Sinta dan Adi (Super Admin), Kirana (Kepatuhan)
make cs-console-react        # container nginx -> http://localhost:8085
```

Email dan password akun dev ada di `scripts/cs-demo/runtime/staff.json` (tidak di-commit).

Pengembangan dengan hot reload (Node ≥ 24.12):

```bash
cd apps/cs-console-react
npm ci
npm run dev                  # http://localhost:5175, API http://localhost:8000
```

`/env.js` di server dev dibuat dari `docker/secrets/anon_key` (atau env `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_ENV`).

## Skrip npm

| Skrip                              | Isi                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `dev` / `build` / `preview`        | Vite (dev 5175, preview 4175)                                                   |
| `typecheck`                        | `tsc` aplikasi + konfigurasi/E2E                                                |
| `lint` / `format` / `format:check` | ESLint (type-checked, 0 warning) dan Prettier                                   |
| `lint:tokens`                      | Tolak warna hex, kelas warna Tailwind mentah, radius > 12px, bayangan non-token |
| `test`                             | Vitest + Testing Library + MSW                                                  |
| `e2e`                              | Playwright terhadap stack dev (`E2E_BASE_URL`, default `http://localhost:8085`) |
| `size:check`                       | Bundle awal ≤ 300 KB gzip                                                       |
| `license:check`                    | Tolak GPL/AGPL/LGPL/SSPL; runtime wajib permisif                                |
| `gen:types`                        | Tipe `cs_api` dari pg-meta (dev) ke `src/types/database.ts`                     |
| `ci`                               | Semua di atas kecuali E2E                                                       |

`make test-cs-console` menjalankan `npm run ci` di container Node; `make e2e-cs-console` menjalankan E2E.

## Konfigurasi runtime

Image yang sama untuk semua lingkungan. Saat container start, `docker/15-cs-console.envsh` menulis `/env.js` dan CSP dari:

| Env                                               | Isi                                                                                                        |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `SUPABASE_URL`                                    | Origin API untuk browser, tanpa path (dev `http://localhost:8000`, produksi `https://<CS_CONSOLE_DOMAIN>`) |
| `SUPABASE_ANON_KEY` atau `SUPABASE_ANON_KEY_FILE` | Hanya anon key. Kunci service role tidak pernah ada di browser                                             |
| `APP_ENV`                                         | `production` (default), `staging`, `development`. Halaman uji `/__perf` mati di produksi                   |

## Tampilan

- Semua warna, tipografi, radius, bayangan, gerak, dan kepadatan adalah token di `src/styles/globals.css` (`:root`/`.light` terang, `.dark` gelap netral tanpa rona biru). Palet bawaan Tailwind dimatikan (`--color-*: initial`), jadi kelas seperti `bg-blue-500` tidak menghasilkan CSS, dan `npm run lint:tokens` menolaknya di CI.
- Tema default terang. Pilihan Terang/Gelap/Ikuti sistem ada di menu avatar dan diterapkan sebelum render pertama oleh `public/theme.js`.
- Status memakai titik/garis berwarna (`bg-signal-*`); teks status memakai varian yang lolos WCAG AA (`text-success`, `text-warning`, `text-danger`, `text-info`).
- Halaman acuan `/dev/ui` (hanya `APP_ENV=development`, tanpa login) menampilkan token dan semua komponen utama dalam kedua tema.

## Struktur

```
src/
  app/          shell, router (TanStack Router), workspace (dimuat setelah login), top bar
  features/     auth, presence, tickets, conversation, customer, command, supervisor, reports, settings, notifications, perf
                (masing-masing api.ts, hooks.ts, types.ts, components/)
  lib/          supabase, realtime (manajer channel), tabs (BroadcastChannel), time (WIB), preferences, errors
  components/   ui/ (shadcn/Radix), badges, states (empty/error/skeleton/error boundary)
  i18n/         id (default) dan en; teks fitur besar (platform, policy, moderation) dimuat lazy bersama rutenya
```

## Keamanan

- Header nginx: CSP ketat (`script-src 'self'`, `connect-src` hanya origin API), HSTS, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy`, COOP/CORP, `X-Robots-Tag: noindex`. Hanya GET/HEAD.
- Container non-root (uid 101), filesystem read-only + tmpfs, `cap_drop: ALL`, batas CPU/memori/pids, healthcheck `/healthz`.
- Login email + password tanpa TOTP, jadi akses dibatasi jaringan (LAN kantor atau VPN). Password sementara wajib diganti saat login pertama dan setelah reset. Sesi GoTrue per tab (`sessionStorage` dengan kunci per tab), jadi login, logout, dan refresh token di satu tab tidak menyentuh akun lain di tab lain. Logout otomatis setelah 30 menit tidak aktif, cache/draf/data yang ditampilkan dibersihkan saat keluar.
- Isi pesan selalu plain text; tautan `rel="noopener noreferrer"` dan konfirmasi bila di luar situs bantuan; lampiran lewat signed URL 120 detik: gambar dengan watermark nama CS, PDF sebagai kartu file yang dibuka di tab baru. Composer menerima gambar (5 MB) dan PDF (10 MB); video, voice note, dan file Office ditolak dengan pesan yang jelas.
- Log produksi tanpa token dan tanpa isi pesan. Zod berjalan `jitless` sehingga tidak ada `eval`.

## Tes

- Unit: logika (quick reply, aturan data rahasia, cache pesan, pengelompokan baris, filter tiket, tab per peran, parser realtime, CSV, rentang laporan, jam layanan) dan komponen (composer, gelembung pesan, panel info nasabah, top bar, daftar tiket, dan percakapan untuk CS dan mode pantau Super Admin, login tanpa TOTP dengan ganti password wajib, reset password akun), klien data nasabah (`customer_history`, `notes`) dengan MSW.
- E2E (`e2e/`): login email + password (password salah ditolak), rebutan klaim dua CS, chat + lampiran + tanda dibaca + panel info nasabah (identitas, riwayat tiket, catatan), lepas/transfer/selesai, non-pemilik hanya-baca, putus-sambung tanpa duplikat, Super Admin mode pantau (hanya-baca), bagikan tiket terbuka + pindahkan, alur Kepatuhan (tinjauan, perpanjang tenggat, unduh transkrip bersidik, jejak audit) dan audit kontras halaman Kepatuhan, tangkapan layar terang/gelap termasuk `/dev/ui` (`e2e-artifacts/screens`), uji kinerja 1000 tiket + 5000 pesan.
- Kualitas tampilan: kontras WCAG AA dengan axe (`@axe-core/playwright`) di kedua tema, serta tata letak 1366×768, 1920×1080, dan 2560×1440 tanpa scroll horizontal atau teks terpotong (`e2e/a11y.spec.ts`, `e2e/layout.spec.ts`, dan langkah percakapan di `e2e/visual.spec.ts`).
- Backend membatasi 5 tiket per jam per nasabah. Setiap skenario memakai nasabah OLT dummy yang berbeda, jadi suite penuh bisa dijalankan 5 kali per jam.
- Uji kinerja menjalankan Chrome tanpa batas vsync agar fps mencerminkan kerja per frame (target ≥ 60 fps, p95 ≤ 16,7 ms).

CI: [.github/workflows/cs-console-react.yml](../../.github/workflows/cs-console-react.yml) (verifikasi, image + Trivy, E2E dengan stack dev).

## Produksi

```bash
# docker/.env: CS_CONSOLE_DOMAIN=cs.domain-anda, VPN_SOURCE_RANGES=192.168.1.0/24 (LAN kantor atau VPN)
make up PROFILE=single CS=1      # Windows: .\make.ps1 up -Profile single -Cs
```

Web CS dan API agen berada di satu domain (tanpa CORS) yang hanya menerima IP di `VPN_SOURCE_RANGES` (`docker/compose.cs.yml`, `docker/volumes/traefik/cs.yml`). Profil cluster memakai image `${REGISTRY}/olt-social/cs-console:0.1.1`. Lihat [docs/PRODUCTION.md](../../docs/PRODUCTION.md).

## Catatan

- React Compiler tidak dipakai, jadi aturan lint `react-hooks/incompatible-library` dimatikan.
- Lisensi: semua dependensi runtime permisif. `lightningcss` (MPL-2.0) hanya alat build Tailwind dan tidak ikut ke bundle. Font Inter memakai OFL-1.1.
- Console Flutter lama (`apps/cs-console`) sudah dihapus.
