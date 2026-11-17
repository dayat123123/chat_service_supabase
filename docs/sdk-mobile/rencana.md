# Rencana SDK Mobile Native (Android dan iOS)

Status: **diskusi**, belum ada keputusan mulai dan belum ada kode. Ditulis 17 November 2026.

## 1. Tujuan

Klien yang aplikasinya bukan Flutter bisa memakai fitur komunitas lewat library native, dengan UI yang mereka buat sendiri.

| Termasuk | Tidak termasuk |
|---|---|
| SDK **headless** (logika dan data, tanpa UI) untuk Android native dan iOS native | Komponen UI siap pakai (bisa menyusul sebagai proyek terpisah) |
| Perilaku sama dengan library Flutter `rendezvous_community` | Web, React Native, desktop |
| Aplikasi contoh sederhana Android dan iOS sebagai referensi | WebView atau iframe (ditolak) |
| Panduan UI dan checklist kepatuhan untuk tim klien | Berbagi Trade (sedang dijeda) |

Library Flutter tetap dipakai klien Flutter dan menjadi **acuan perilaku**. Rinciannya ada di `rendezvous_community/doc/features.md`.

## 2. Keputusan teknis

| Hal | Pilihan | Alasan |
|---|---|---|
| Bahasa | **Kotlin Multiplatform** (target Android + iOS) | Satu kode logika; hasilnya library native di kedua platform |
| Koneksi server | **supabase-kt** (Postgrest, Realtime, Storage) di atas Ktor | Setara supabase-dart di library Flutter. Bila bermasalah, bisa diganti Ktor langsung tanpa mengubah API publik |
| Cache offline & outbox | **SQLDelight** (SQLite) | Jalan di Android dan iOS, setara Drift di library Flutter |
| JSON | kotlinx.serialization | Standar KMP |
| Async | Coroutines, `Flow` / `StateFlow` | Idiomatis di Android |
| API untuk Swift | **SKIE** | `Flow` jadi `AsyncSequence`, `suspend` jadi `async/await`, sealed class jadi `enum` |
| Android | AAR, minSdk 24, aturan R8 bawaan, *explicit API mode*, validator kompatibilitas biner | Standar library Android |
| iOS | XCFramework lewat Swift Package Manager, minimal iOS 15 | Standar distribusi iOS |
| Distribusi | Repo GitHub privat; Android lewat GitHub Packages (Maven), iOS lewat GitHub Release + `Package.swift` | Sama dengan pola library Flutter (tag rilis) |
| Build iOS | GitHub Actions runner macOS | Komputer pengembang saat ini Windows |

## 3. Arsitektur

### 3.1 Bentuk API publik

```kotlin
val community = RendezvousCommunity.initialize(
    CommunityConfig(
        apiUrl = "https://social-api.klien.co.id",
        anonKey = "...",
        appVersion = "3.4.0",
        platform = CommunityPlatform.Android,
    ),
    host = object : CommunityHost {
        override suspend fun socialToken(): String? = backend.freshSocialToken()
        override fun log(record: CommunityLogRecord) = logger.log(record)
    },
)

community.chat.rooms                       // StateFlow<Paged<RoomPreview>>
community.chat.room(id).messages           // Flow<List<ChatMessage>>
community.chat.room(id).send(text = "Halo")
community.support.home                     // StateFlow<SupportHome>
community.config.state                     // StateFlow<ClientConfig> (kill switch, versi minimum)
community.signOut()
```

```swift
for await list in community.chat.room(id: id).messages { render(list) }
try await community.chat.room(id: id).send(text: "Halo")
```

Aturan API:
- Setiap fitur punya satu pintu: `community.chat`, `.feed`, `.profile`, `.support`, `.help`, `.notifications`, `.moderation`, `.account`, `.legal`, `.push`, `.config`.
- Data dibaca lewat `StateFlow`/`Flow`, aksi lewat fungsi `suspend`.
- Daftar panjang memakai tipe `Paged<T>` yang sama untuk semua fitur (muat lagi, segarkan, status memuat, galat).
- Galat berupa sealed class `CommunityError`, misalnya `ConsentRequired(document)`, `SocialDisabled`, `FeatureDisabled(flag)`, `UpdateRequired`, `RateLimited(retryAfter)`, `TokenUnavailable`, `Network`, `Server(code)`.
- Nama fitur, model, dan perilaku mengikuti library Flutter supaya dokumentasi bisa dipakai bersama.

### 3.2 Struktur modul

```
rendezvous_community_kmp/
  community/                 modul KMP yang dirilis
    core/auth                tukar token ke auth-bridge, perbarui sebelum kedaluwarsa
    core/network             RPC, realtime, media gateway, konektivitas
    core/storage             SQLDelight: cache offline, outbox, nilai lokal
    core/error, core/logging
    feature/<nama>           data + state per fitur
  samples/android            aplikasi contoh Compose
  samples/ios                aplikasi contoh SwiftUI
  conformance/               skenario uji ke server dev
  docs/                      panduan integrasi, panduan UI, checklist kepatuhan
```

### 3.3 Yang tetap di aplikasi klien

UI dan navigasi, pemilih foto dan kamera, izin, penerimaan push (FCM/APNs), membuka layar saham sendiri, dan menyimpan file transkrip. SDK menyediakan data dan aksinya, misalnya `push.parse(payload)` mengembalikan tujuan yang harus dibuka.

## 4. Tahapan

Setiap tahap menghasilkan rilis yang bisa dipakai klien. Rencana teknis per tugas dibuat saat tahap dimulai, di repo SDK.

Ukuran: S = kecil, M = sedang, L = besar, XL = paling besar.

### Tahap 0: Persiapan (S)

- Repo baru, kerangka modul KMP, CI Android di Linux dan iOS di macOS, rilis otomatis dari tag.
- **Kontrak API v1**: dokumen daftar RPC, parameter, bentuk respons, channel realtime, dan kode galat yang dipakai SDK. Ini sekaligus acuan versi untuk library Flutter.
- Keputusan nama: paket (`id.rendezvous.community`), dan apakah nama "OLT" di kontrak push (`olt.*`) dibiarkan atau dinetralkan.

Selesai bila: CI hijau di kedua platform, rilis `0.0.1` kosong bisa dipasang di aplikasi contoh Android dan iOS.

### Tahap 1: Fondasi (M)

| Bagian | RPC / layanan |
|---|---|
| Login: tukar token sosial ke auth-bridge, perbarui otomatis, token realtime | `auth-bridge /exchange` |
| Konfigurasi klien: kill switch, flag fitur, versi minimum, selisih jam server | `get_client_config` |
| Banner dan popup: data, aturan frekuensi, event | `get_client_config`, `record_banner_event` |
| Dokumen hukum dan persetujuan | `get_legal_documents`, `accept_legal_document` |
| Push token | `register_push_device`, `unregister_push_device` |
| Analitik (batch, whitelist properti) | `track_events` |
| Galat, logging tanpa data sensitif, konektivitas | |

Selesai bila: aplikasi contoh login dengan token sosial dev, menampilkan status kill switch dan banner, dan menolak aksi sebelum S&K disetujui.

### Tahap 2: Chat CS, Pusat Bantuan, pengaduan tamu (L)

Ini paling sering dibutuhkan klien, jadi dikerjakan lebih dulu.

| Bagian | RPC |
|---|---|
| Chat CS: beranda, topik, pertanyaan awal, buka tiket, pesan realtime, lampiran (gambar, PDF, video sesuai kebijakan), tanda baca, mengetik, rating dan survei, tiket saya, transkrip, lapor CS palsu, laporkan penipuan, status gangguan | `support_home`, `topics`, `open_ticket`, `send_message`, `get_messages`, `ticket_messages`, `mark_read`, `send_typing`, `rate_ticket`, `close_ticket`, `my_tickets`, `ticket_transcript`, `report_fake_cs`, `request_complaint`, `service_status`, `attachment_policy`, `check_sensitive`, `room_members`, `get_message_info` |
| Pusat Bantuan | `faq`, `faq_search`, `faq_article`, `faq_feedback`, `faq_for_topic` |
| Pengaduan tamu (tanpa login, anon key) | `guest_config`, `guest_start`, `guest_send`, `guest_poll`, `guest_end` |
| Unggahan lewat media gateway | layanan `media` |

Selesai bila: aplikasi contoh bisa membuka tiket, berbalas dengan CS dari Hub secara realtime, mengirim lampiran, memberi rating, dan pengaduan tamu berjalan sampai ditutup.

### Tahap 3: Chat komunitas (XL)

| Bagian | RPC |
|---|---|
| Daftar room, pratinjau, jumlah belum dibaca, DM, room saham | `get_my_rooms`, `get_my_room`, `get_room_previews`, `get_unread_counts`, `get_unread_chat_count`, `get_or_create_direct_room`, `join_stock_room`, `get_stock_room_state` |
| Pesan: kirim, balas, reaksi, edit, hapus, kartu saham, bagikan post | `send_message`, `get_messages`, `get_messages_by_ids`, `get_message_ids`, `get_message_info`, `react_to_message`, `edit_message`, `delete_message`, `share_post_to_chat` |
| Tanda terima dan mengetik | `mark_room_read`, `mark_rooms_delivered`, `send_typing` |
| Grup | `create_group_room`, `update_group_info`, `add_room_members`, `remove_room_member`, `set_room_member_role`, `transfer_room_ownership`, `delete_group`, `leave_room`, `hide_room`, `get_room_members` |
| Permintaan pesan dan kebijakan DM | `get_message_requests`, `get_message_request_count`, `respond_message_request`, `get_dm_request_state`, `get_dm_policy`, `set_dm_policy` |
| Moderator room | `room_mod_hide_message`, `room_mod_mute_user`, `room_mod_escalate` |
| Pratinjau tautan | `get_link_previews` |
| Realtime broadcast, isi celah pesan setelah putus, outbox kirim ulang, cache offline per user | |

Selesai bila: tes kesesuaian chat lulus, termasuk kirim saat offline lalu online, putus koneksi lalu celah terisi, dan pesan tidak dobel.

### Tahap 4: Stream dan profil (L)

| Bagian | RPC |
|---|---|
| Feed, filter, postingan tersemat, detail post | `get_feed`, `get_feed_filters`, `get_pinned_posts`, `get_post`, `get_market_instruments`, `get_stock` |
| Tulis, edit, hapus post; polling; draf | `create_post`, `edit_post`, `delete_post`, `vote_poll`, `save_post_draft`, `get_post_drafts`, `delete_post_draft` |
| Komentar | `get_comment_thread`, `create_comment`, `edit_comment`, `delete_comment` |
| Bookmark | `get_bookmarks`, `toggle_bookmark` |
| Trending dan sentimen | `get_trending`, `get_market_sentiment`, `get_stock_sentiment`, `get_stock_stats`, `get_trending_hashtags`, `get_hashtag_feed` |
| Pencarian | `search`, `search_profiles` |
| Profil dan ikuti | `get_profile`, `get_follow_list`, `get_suggested_users`, `get_official_accounts` |

Selesai bila: aplikasi contoh menampilkan Stream, membuat post dengan gambar dan sentimen, berkomentar, dan membuka profil.

### Tahap 5: Notifikasi, moderasi, akun (M)

| Bagian | RPC |
|---|---|
| Kotak notifikasi, badge, preferensi, jam tenang, statistik dibuka/diketuk | `get_notifications`, `get_notification_unread_count`, `mark_notifications_read`, `get_notification_prefs`, `set_notification_prefs`, `report_notification_event` |
| Isi push: menentukan tujuan (post, room, banding, push transaksi klien) | |
| Banding dan sanksi | `get_my_sanctions`, `get_my_moderated_content`, `get_my_appeals`, `create_appeal` |
| Akun: ekspor data, hapus akun, hapus cache lokal | `export_my_data`, `delete_my_account` |

### Tahap 6: Rilis 1.0 (M)

- Panduan integrasi Android dan iOS, panduan UI per fitur, dan checklist kepatuhan (bagian 6).
- Tabel kesetaraan fitur dengan library Flutter.
- Penguncian API publik (validator kompatibilitas biner) dan semantic versioning.
- Tabel kompatibilitas versi SDK dengan versi migrasi server.

## 5. Pengujian

| Lapisan | Isi | Di mana |
|---|---|---|
| Unit | Logika token, outbox, isi celah, paging, frekuensi popup, pemetaan galat; server palsu memakai Ktor MockEngine | CI Linux (JVM/Android) dan macOS (iOS simulator) |
| Kesesuaian | Skenario yang sama dengan library Flutter dijalankan ke server dev: login, kill switch, S&K, tiket CS sampai rating, chat offline/online, celah setelah putus, edit/hapus pesan, notifikasi | CI, terhadap server dev |
| Aplikasi contoh | Build Android dan iOS, tes asap di emulator dan simulator | CI |
| Perangkat fisik | iPhone dan HP Android sungguhan sebelum rilis | Manual oleh tim |

## 6. Panduan UI dan checklist kepatuhan

UI dibuat klien, jadi elemen wajib harus didokumentasikan dan diperiksa sebelum go-live:

- Disclaimer "bukan rekomendasi investasi" di Stream dan detail post.
- Label **CS Resmi** dan peringatan "CS tidak pernah meminta password, PIN, atau OTP" di Chat CS dan pengaduan tamu.
- Tombol **Laporkan Penipuan** di Chat CS.
- Dialog persetujuan S&K saat SDK mengembalikan `ConsentRequired`.
- Label konten ditahan/disembunyikan, serta tombol lapor dan blokir.
- Tampilan saat fitur dimatikan (`SocialDisabled`) dan wajib update (`UpdateRequired`).
- State memuat, kosong, gagal, dan offline di setiap layar.

Yang bisa ditegakkan dari server atau SDK tetap ditegakkan di sana, misalnya penolakan aksi tanpa persetujuan S&K dan penanda resmi pada pesan CS.

## 7. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Perilaku SDK dan library Flutter berbeda | Kontrak API berversi, tes kesesuaian bersama, tabel kesetaraan per rilis |
| Setiap fitur baru dikerjakan dua kali (Dart dan Kotlin) | Pindahkan logika ke server bila memungkinkan; fitur baru dicatat di kedua backlog |
| supabase-kt dikelola komunitas | Dibungkus lapisan `core/network` sendiri; bisa diganti Ktor langsung |
| Build iOS bergantung pada runner macOS | GitHub Actions macOS; pemakaian menitnya lebih mahal dari runner Linux, jadi tes iOS lengkap hanya di branch utama dan tag |
| Ukuran aplikasi iOS bertambah | Ukur di tahap 0; aktifkan pemangkasan simbol |
| UI klien melewatkan elemen wajib | Panduan UI, checklist, dan pemeriksaan Kepatuhan sebelum go-live |

## 8. Yang perlu disiapkan

- Repo GitHub baru (privat), misalnya `rendezvous_community_kmp`, dan izin memakai runner macOS di GitHub Actions.
- Satu iPhone dan satu HP Android untuk uji manual sebelum rilis.
- Akun Apple Developer **tidak** wajib untuk SDK. Akun ini hanya perlu bila aplikasi contoh iOS mau dipasang di perangkat lewat TestFlight.

## 9. Keputusan yang masih terbuka

1. Nama paket dan nama produk SDK.
2. Nama "OLT" di kontrak push dan callback: dibiarkan atau dinetralkan (berpengaruh ke library Flutter dan server).
3. Perlu tidaknya API yang nyaman dipanggil dari Java (aplikasi Android lama).
4. Urutan tahap 3 dan 4 bila klien pertama lebih butuh Stream daripada chat.
5. UI kit (Compose Multiplatform atau SwiftUI) sebagai proyek lanjutan atau tidak.
