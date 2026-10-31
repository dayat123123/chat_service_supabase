# Web CS (React)

Konsol customer service OLT untuk CS, supervisor, dan admin CS. React 19 + TypeScript, dibangun Vite menjadi SPA statis dan disajikan nginx non-root. Backend tidak berubah: Supabase (`cs_api`, GoTrue TOTP, Realtime, Storage), `customer-adapter` (`/cs/v1`), dan Edge Function `cs-admin`.

Rencana dan keputusan: [docs/PROMPT-CS-CONSOLE-REACT.md](../../docs/PROMPT-CS-CONSOLE-REACT.md), [docs/cs-console-audit.md](../../docs/cs-console-audit.md), paritas dengan console Flutter: [docs/cs-console-parity.md](../../docs/cs-console-parity.md). Tampilan: [docs/PROMPT-CS-UI-POLISH.md](../../docs/PROMPT-CS-UI-POLISH.md) dan [docs/cs-ui-audit.md](../../docs/cs-ui-audit.md).

## Menjalankan

Prasyarat: stack dev dengan OLT dummy dan akun staf dev.

```bash
make up DUMMY_OLT=1          # Windows: .\make.ps1 up -DummyOlt
make cs-staff                # akun Nadia, Bima, Laras (CS), Sinta (supervisor), Adi (admin)
make cs-console-react        # container nginx -> http://localhost:8085
make cs-totp                 # kode TOTP saat ini untuk akun dev
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
  i18n/         id (default) dan en
```

## Keamanan

- Header nginx: CSP ketat (`script-src 'self'`, `connect-src` hanya origin API), HSTS, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy`, COOP/CORP, `X-Robots-Tag: noindex`. Hanya GET/HEAD.
- Container non-root (uid 101), filesystem read-only + tmpfs, `cap_drop: ALL`, batas CPU/memori/pids, healthcheck `/healthz`.
- Sesi GoTrue per tab (`sessionStorage`), logout otomatis setelah 30 menit tidak aktif, cache/draf/data yang ditampilkan dibersihkan saat keluar.
- Isi pesan selalu plain text; tautan `rel="noopener noreferrer"` dan konfirmasi bila di luar situs bantuan; lampiran lewat signed URL 120 detik dengan watermark nama CS.
- Log produksi tanpa token dan tanpa isi pesan. Zod berjalan `jitless` sehingga tidak ada `eval`.

## Tes

- Unit: logika (quick reply, aturan data rahasia, cache pesan, pengelompokan baris, filter tiket, parser realtime, CSV, rentang laporan, jam layanan) dan komponen (composer, tampilkan data tersamar), klien adapter dengan MSW.
- E2E (`e2e/`): login + TOTP, rebutan klaim dua CS, chat + lampiran + tanda dibaca, lepas/transfer/selesai, non-pemilik hanya-baca, putus-sambung tanpa duplikat, supervisor gabung + pindahkan, tangkapan layar terang/gelap termasuk `/dev/ui` (`e2e-artifacts/screens`), uji kinerja 1000 tiket + 5000 pesan.
- Kualitas tampilan: kontras WCAG AA dengan axe (`@axe-core/playwright`) di kedua tema, serta tata letak 1366×768, 1920×1080, dan 2560×1440 tanpa scroll horizontal atau teks terpotong (`e2e/a11y.spec.ts`, `e2e/layout.spec.ts`, dan langkah percakapan di `e2e/visual.spec.ts`).
- Backend membatasi 5 tiket per jam per nasabah. Setiap skenario memakai nasabah OLT dummy yang berbeda, jadi suite penuh bisa dijalankan 5 kali per jam.
- Uji kinerja menjalankan Chrome tanpa batas vsync agar fps mencerminkan kerja per frame (target ≥ 60 fps, p95 ≤ 16,7 ms).

CI: [.github/workflows/cs-console-react.yml](../../.github/workflows/cs-console-react.yml) (verifikasi, image + Trivy, E2E dengan stack dev).

## Produksi

```bash
# docker/.env: CS_CONSOLE_DOMAIN=cs.domain-anda, VPN_SOURCE_RANGES=10.8.0.0/24
make up PROFILE=single CS=1      # Windows: .\make.ps1 up -Profile single -Cs
```

Web CS dan API agen berada di satu domain (tanpa CORS) yang hanya menerima IP VPN (`docker/compose.cs.yml`, `docker/volumes/traefik/cs.yml`). Profil cluster memakai image `${REGISTRY}/olt-social/cs-console:0.1.0`. Lihat [docs/PRODUCTION.md](../../docs/PRODUCTION.md).

## Catatan

- React Compiler tidak dipakai, jadi aturan lint `react-hooks/incompatible-library` dimatikan.
- Lisensi: semua dependensi runtime permisif. `lightningcss` (MPL-2.0) hanya alat build Tailwind dan tidak ikut ke bundle. Font Inter memakai OFL-1.1.
- Console Flutter (`apps/cs-console`) tetap ada sampai cutover M5 disetujui.
