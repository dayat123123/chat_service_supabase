# Paritas Web CS Flutter → React

Checklist migrasi [PROMPT-CS-CONSOLE-REACT.md](PROMPT-CS-CONSOLE-REACT.md). Sumber fitur Flutter: [cs-console-audit.md](cs-console-audit.md). Aplikasi baru: [`apps/cs-console-react`](../apps/cs-console-react/README.md).

Status: ✅ setara atau lebih baik · ⏳ menunggu backend (B1–B4 di audit, tidak dikerjakan karena keputusan "frontend saja").

Kolom **Tes**: `unit` = Vitest (`src/**/*.test.ts[x]`), `E2E` = Playwright (`e2e/*.spec.ts`) terhadap stack dev asli, `manual` = diperiksa di browser saat pengembangan.

## Masuk dan sesi

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Email + password GoTrue | `features/auth/components/login-page.tsx` | ✅ | E2E `auth` (password salah ditolak) |
| Verifikasi TOTP | `second-factor.tsx` → `TotpPage` | ✅ | E2E `auth` (kode salah ditolak) |
| Pendaftaran TOTP dengan QR + kunci manual | `second-factor.tsx` → `EnrollPage` | ✅ | manual |
| Ganti password sementara | `second-factor.tsx` → `PasswordPage` | ✅ | manual |
| Logout manual | `app/top-bar.tsx` → menu Akun | ✅ | E2E `auth` |
| Logout idle 30 menit + peringatan 60 detik | `features/auth/components/idle-guard.tsx` (aktivitas dibagi antar tab) | ✅ | manual |
| Keluar otomatis bila akun dicabut | `features/auth/hooks.ts`, `presence/hooks.ts` (`agent_required` → keluar) | ✅ | manual |
| Kode pemulihan 2FA | Petunjuk "hubungi admin CS" di halaman TOTP | ⏳ B1 | – |
| Cache, draf, data tampil, dan pesan tertunda dibersihkan saat keluar | `app/app.tsx`, `app/workspace.tsx` | ✅ | manual |

## Status CS

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Online / Sibuk / Istirahat / Offline + alasan | `features/presence/components/status-menu.tsx` | ✅ | E2E (semua skenario mengubah ke Online) |
| Default Offline setelah login | `features/auth/hooks.ts` | ✅ | E2E `auth` |
| Heartbeat 20 detik | `presence/hooks.ts` → `useHeartbeat` (hanya tab pemimpin) | ✅ | manual |
| Tiket aktif `n/batas` | `status-menu.tsx` → `ActiveCount` | ✅ | visual |
| Indikator koneksi realtime | `ConnectionIndicator` (Terhubung / Menyambung ulang / Offline) | ✅ | E2E `reconnect` |
| Tab ditutup (B4) | Offline lewat `fetch keepalive` hanya bila tab terakhir dan tidak ada tiket aktif; reload < 60 detik mengembalikan status sebelumnya | ✅ | manual |

B4: memanggil `agent_set_status('offline')` saat tab ditutup akan mengirim "CS sedang tidak aktif" ke nasabah. Supaya reload tidak mengganggu nasabah, React hanya menjadikan Offline bila ini tab terakhir dan CS tidak memegang tiket aktif. Solusi penuh (jeda sebelum pesan "tidak aktif") butuh perubahan backend.

## Daftar tiket

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Tab Terbuka, Tiket saya, Selesai hari ini, Semua aktif (supervisor) + jumlah | `features/tickets/components/ticket-column.tsx` | ✅ | E2E `supervisor`, `ticket-actions` |
| Filter topik, prioritas, tanda | `ticket-column.tsx`, `tickets/logic.ts` | ✅ | unit `logic.test` |
| Cari nomor, nama, kode nasabah, isi pesan | `search_tickets` + palet Ctrl+K | ✅ | manual |
| Urut prioritas lalu lama menunggu, badge SLA | `tickets/logic.ts`, `components/badges.tsx` | ✅ | unit `logic.test` |
| Transfer masuk (terima/tolak) dan keluar (batalkan) | `transfer-inbox.tsx` | ✅ | E2E `ticket-actions` (terima) |
| Tanda "dikembalikan ke antrean" | `ticket-card.tsx` | ✅ | visual |
| 1000 tiket tetap mulus | TanStack Virtual | ✅ | E2E `perf` |

## Ambil tiket

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Ambil atomik di server, tombol loading | `useClaimTicket` | ✅ | E2E `claim-race` |
| Pesan "sudah diambil oleh …" + kartu hilang beranimasi | `useTicketRealtime` | ✅ | E2E `claim-race`, `read-only` |
| Pratinjau hanya-baca + tombol Ambil | `conversation-pane.tsx` → `ReadOnlyBar` | ✅ | E2E `read-only` |
| Tiket yang sedang dipratinjau diambil CS lain | Toast lalu pratinjau ditutup (backend mencabut akses baca CS non-pemilik) | ✅ | E2E `read-only` |

## Percakapan

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Riwayat room, muat pesan lama saat gulir ke atas | `message-list.tsx` (virtual, posisi dipertahankan) | ✅ | E2E `perf` (5000 pesan) |
| Pemisah hari (WIB) dan pengelompokan 5 menit | `conversation/rows.ts` | ✅ | unit `rows.test` |
| Pesan sistem ringkas, pemisah tiket | `message-bubble.tsx` → `SystemMessage` | ✅ | visual |
| Badge CS Resmi | `message-bubble.tsx` | ✅ | visual |
| Gambar + lightbox dengan watermark CS | `attachment-image.tsx` (signed URL 120 detik) | ✅ | E2E `chat` (unggah), manual (lightbox) |
| Kartu order/transaksi + detail dari OLT | `card-detail-dialog.tsx` | ✅ | manual |
| Tautan bantuan, konfirmasi domain di luar situs bantuan | `message-bubble.tsx` → `SafeLink` (`rel="noopener noreferrer"`) | ✅ | manual |
| Indikator mengetik, nasabah sedang membuka chat | `useRoom` (broadcast + presence) | ✅ | manual |
| Tanda terkirim / dibaca | `message-bubble.tsx` + receipt `room:<id>` | ✅ | E2E `chat` |
| Balas dengan kutipan | `MessageBubble` → `Composer` | ✅ | manual |
| Pesan baru realtime tanpa duplikat | `useRoom` + `cache.ts` (dedupe per id) | ✅ | unit `cache.test`, E2E `chat` |
| Catch-up setelah koneksi putus / channel baru tersambung | `useRoom` (`onMessagesJoined`, resync, event `ticket_message`) | ✅ | E2E `reconnect`, `visual` |
| Kirim optimistis, gagal → kirim ulang | `useSendMessage` (`client_id`) | ✅ | E2E `reconnect` |
| Teks pesan selalu plain text | React escape, tanpa `dangerouslySetInnerHTML` | ✅ | review |

## Composer

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Balas / Catatan internal (kuning, tidak terlihat nasabah) | `composer.tsx` | ✅ | unit `composer.test` |
| Enter kirim, Shift+Enter baris baru, Ctrl+Enter | `composer.tsx`, `use-hotkeys.ts` | ✅ | unit `composer.test` |
| `/` balasan cepat + cari + variabel `{nama}`, `{nomor_tiket}`, `{nama_cs}` | `quick-replies.ts` | ✅ | unit `composer.test`, `quick-replies.test` |
| Lampiran: pilih, tempel, seret; pratinjau; maks 4 × 5 MB | `composer.tsx` | ✅ | E2E `chat` (pilih), manual (tempel/seret) |
| Kartu order/transaksi, tautan bantuan, pilihan cepat | `special-dialogs.tsx` | ✅ | manual |
| Jumlah karakter (maks 4000) | `composer.tsx` | ✅ | unit `composer.test` |
| Draf per tiket per mode | `useDraft` (langsung tersimpan) | ✅ | unit `composer.test` |
| Blok permintaan OTP/PIN/password sebelum kirim | `conversation/secret.ts` (port `cs.requests_secret`) | ✅ | unit `secret.test`, `composer.test` |

## Aksi tiket

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Tunggu nasabah | `conversation-header.tsx` | ✅ | manual |
| Lepas (alasan) | `action-dialogs.tsx` | ✅ | E2E `ticket-actions` |
| Transfer (CS online + catatan) | `action-dialogs.tsx` | ✅ | E2E `ticket-actions` |
| Selesaikan (hasil + ringkasan) | `action-dialogs.tsx` | ✅ | E2E `ticket-actions` |
| Ubah prioritas | `conversation-header.tsx` | ✅ | manual |
| Supervisor: Gabung | `conversation-pane.tsx` (anggota room dimuat ulang) | ✅ | E2E `supervisor` |
| Supervisor: Pindahkan (alasan) | `action-dialogs.tsx` | ✅ | E2E `supervisor` |
| Konfirmasi untuk aksi berisiko | Dialog di semua aksi di atas | ✅ | E2E |

## Info nasabah

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Profil tersamar | `customer-panel.tsx` | ✅ | visual |
| Tampilkan data (alasan, sementara, diaudit) | `revealable-value.tsx`, `reveal-dialog.tsx` | ✅ | unit `revealable-value.test`, `customer/api.test` (MSW) |
| Order, transaksi dana, perangkat & sesi, keamanan (dimuat saat dibuka, skeleton) | `customer-panel.tsx` | ✅ | manual |
| Amankan akun (konfirmasi) | `customer-panel.tsx` | ✅ | manual |
| Riwayat tiket, catatan per tiket/per nasabah | `customer-panel.tsx`, `notes-section.tsx` | ✅ | manual |
| Data OLT hanya untuk pemilik tiket aktif atau supervisor | `customer-panel.tsx` | ✅ | visual |
| "Terakhir aktif" nasabah | Hanya online/tidak (presence) | ⏳ B2 | – |
| Permintaan konfirmasi identitas | Tidak ada di composer | ⏳ B3 | – |

## Supervisor dan admin

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Dashboard: ringkasan, perlu perhatian, status CS | `features/supervisor/components/dashboard-page.tsx` | ✅ | E2E `supervisor`, `visual` |
| Antrean per prioritas (grafik) dan beban CS (meter) | `queue-chart.tsx`, tabel status CS | ✅ | visual |
| Alert tiket terlambat, CS palsu, permintaan data rahasia | `features/notifications/hooks.ts` | ✅ | manual |
| Laporan: preset, rentang ≤ 93 hari, ringkasan, per hari, per CS, topik | `features/reports/components/reports-page.tsx` | ✅ | unit `range.test`, visual |
| Ekspor CSV (BOM, CRLF, netralisasi formula) | `features/reports/csv.ts` | ✅ | unit `csv.test` |
| Akun CS: tambah (`cs-admin`), ubah, nonaktifkan + password sementara sekali tampil | `settings/components/accounts-section.tsx` | ✅ | visual, manual |
| Topik, quick reply, jam layanan & libur, pesan otomatis, penugasan & alert | `settings/components/*-section.tsx` | ✅ | unit `settings/logic.test`, visual |

## Notifikasi

| Fitur Flutter | React | Status | Tes |
|---|---|---|---|
| Suara + notifikasi browser (tiket baru: semua / prioritas tinggi / mati) | `lib/alerts.ts`, menu lonceng | ✅ | manual |
| Hanya satu tab yang berbunyi | `lib/tabs.ts` (pemimpin BroadcastChannel) | ✅ | manual |
| Judul tab `(N) CS Console` | `useDocumentTitle` | ✅ | manual |

## Baru di React

| Fitur | Lokasi | Tes |
|---|---|---|
| 3 kolom bisa diubah ukurannya dan diingat; panel nasabah bisa diciutkan; drawer < 1280 px; daftar/chat bergantian < 900 px | `tickets-page.tsx` | visual |
| Palet perintah Ctrl+K (tiket, aksi, navigasi, status, tampilan) | `command-palette.tsx` | unit `search.test`, visual |
| Pintasan J/K/A/R/N/E/Ctrl+Enter, `?` daftar pintasan | `use-hotkeys.ts`, `shortcuts-dialog.tsx` | manual |
| Tema terang/gelap/sistem, kepadatan Nyaman/Padat, Bahasa ID/EN | `lib/preferences.ts`, `i18n/` | visual |
| Error boundary per kolom/bagian | `components/states.tsx` | manual |
| Bundle awal 255 KB gzip; workspace, grafik, supervisor, admin dimuat setelah login | `app/app.tsx` | `npm run size:check` |

## Hasil verifikasi (30 Okt 2026)

- Unit: 64 tes (13 file) lulus.
- E2E: 13 tes lulus terhadap stack dev + OLT dummy (7 skenario prompt bagian 9, tampilan terang/gelap, uji kinerja).
- Kinerja: 1000 tiket + 5000 pesan digulir bersamaan ~109 fps, p95 frame ~11 ms (Chrome tanpa batas vsync; headless dengan vsync dibatasi ~32 fps oleh lingkungan, aplikasi mencapai batas itu).
- Lighthouse halaman login (mobile & desktop): Performance 100, Accessibility 100, Best Practices 100. SEO tidak ditargetkan (`noindex`, konsol internal).
- Lisensi: 165 paket runtime permisif; satu-satunya MPL-2.0 adalah `lightningcss` (alat build Tailwind, tidak ikut ke bundle).
