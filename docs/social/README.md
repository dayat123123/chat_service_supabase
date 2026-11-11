# Fitur sosial & produk

Paket fitur komunitas tahap 3 November 2026: pencarian, trending & sentimen saham, edit konten, bookmark, reaksi pesan, bagikan postingan ke chat, preferensi notifikasi, feature flag & kill switch, serta analitik. Semua berada di database (Postgres + PostgREST), tanpa layanan baru.

| Migrasi | Isi | Tes pgTAP |
|---|---|---|
| `0073_search` | pencarian, hashtag, hashtag trending | `053_search_test` |
| `0074_trending` | agregat 5 menit, sentimen saham, trending | `054_trending_test` |
| `0075_post_extras` | edit, bookmark, reaksi pesan, bagikan postingan, baris feed/pesan baru, filter permintaan DM | `055_post_extras_test` |
| `0076_notification_prefs` | preferensi notifikasi, jam tenang, penggabungan like/follow, `push_allowed` | `056_notification_prefs_test` |
| `0077_client_config` | feature flag, kill switch, versi minimum aplikasi | `057_client_config_test` |
| `0078_analytics` | event analitik (partisi bulanan), laporan Super Admin, `export_my_data` | `058_analytics_test` |
| `0081_trending_snapshot` | snapshot hashtag trending di job 5 menit, bobot penulis inline, retensi riwayat edit | `061_trending_snapshot_test` |
| `0083_moderation_status_rows` | `moderation_status` di baris post/komentar/pesan untuk penulis, `dm_policy` di ekspor, jenis preferensi `appeal` | `062_moderation_status_rows_test` |
| `0087_notification_types` | mention di room saham, notifikasi postingan akun yang diikuti, ringkasan saham pantauan, notifikasi moderasi, jenis preferensi baru | `066_notification_types_test` |
| `0088_notification_stats_segments` | statistik dibuka/diketuk notifikasi, segmen kampanye baru, `broadcast_id` di siaran OLT | `067_notification_stats_segments_test` |
| `0089_app_banners` | banner aplikasi di `get_client_config`, RPC Super Admin | `068_app_banners_test` |
| `0090_post_drafts_stock_cards` | sinkron draf postingan, kartu saham di chat, ekspor & hapus akun | `069_post_drafts_stock_cards_test` |
| `0091_fixed_feature_flags` | daftar feature flag tetap (8 kunci), hanya sakelar nyala/mati | `070_fixed_feature_flags_test` |
| `0103_message_gap_index` | indeks id pesan untuk gap-fill (`get_message_ids`) dan ambil pesan per id (`get_messages_by_ids`), lihat [Mengisi celah](#mengisi-celah) | `083_message_gap_index_test` |
| `0119_banner_popup` | popup promo (gambar, label tombol, frekuensi, sasaran pengguna baru), deep link banner, statistik tayang/klik/tutup, lihat [Popup promo](#popup-promo-dan-deep-link-banner-0119) | `099_banner_popup_test` |

Semua pengaturan baru ada di `private.settings` (ubah lewat `update private.settings set value = ... where key = ...`), batas laju di `private.rate_limits`. Kode error memakai pola yang sudah ada: HTTP status dari `PTxxx`, field `message` berisi kode stabil (mis. `query_too_short`), `details` berisi teks bahasa Indonesia. Error `429 rate_limited` membawa header `Retry-After`.

## Kompatibilitas klien lama

Tidak ada parameter atau kolom yang dihapus atau diganti nama. Pemanggilan lama tetap jalan:

- `get_feed`, `get_post`, `create_post`, `get_pinned_posts`: baris `feed_post` hanya **bertambah** kolom `is_bookmarked`, `hashtags`, `is_bot`, `author_is_official` (`edited_at` sudah ada sejak awal).
- `get_messages`, `send_message`, `cs_api.get_messages`: baris `chat_message` bertambah `reactions` dan `shared_post`.
- `get_my_rooms(p_cursor, p_limit)`: parameter sama; permintaan pesan DM yang belum diterima tidak lagi tampil untuk penerimanya.
- `get_notifications(p_cursor, p_limit)`: bertambah `actor_count` dan `actors`.
- `export_my_data()`: bertambah bagian baru (lihat [Ekspor data](#ekspor-data)).

Paket Flutter versi lama mengabaikan field baru, jadi tidak perlu rilis bersamaan.

## Pencarian (`0073`)

- **Postingan**: teks dipecah dengan dua konfigurasi full-text Postgres, `indonesian` (stemming: "penguatan" menemukan "menguat") dan `simple` (kata apa adanya, termasuk kode saham dan hashtag). Kata terakhir dicocokkan sebagai awalan ("zorvexba" menemukan "zorvexbank"). Untuk salah ketik, kata kunci ≥ `search.typo_min_length` (4) karakter juga dicocokkan dengan trigram (`pg_trgm`, `word_similarity` ≥ 0,6). Hasil diurutkan terbaru dulu.
- Vektor pencarian disimpan di tabel terpisah `private.post_search(post_id, search_vector)` dengan indeks GIN, **bukan** kolom di `posts`. Alasannya: `posts` disiarkan Realtime ke semua klien setiap like/komentar, dan kolom stored-generated dihitung ulang setiap update; tabel terpisah menjaga payload Realtime tetap kecil dan like tidak memicu `to_tsvector`. Indeks trigram ada di `posts.body` (parsial, `deleted_at is null`).
- **Hashtag** `#topik`: diekstrak trigger dari isi postingan (`posts_42_search`), huruf kecil, pola `^[a-z0-9_]{2,50}$`, maksimal 10 per postingan, disimpan di `public.post_hashtags(post_id, tag, post_created_at)` (bisa dibaca klien). Fragmen URL (`/halaman#bagian`) dan entitas HTML (`&#39;`) tidak dianggap hashtag. Edit postingan menyinkronkan ulang hashtag.
- **Direktori** kode saham (`private.stock_codes`) dan hashtag (`private.hashtags`) diisi otomatis untuk pencarian awalan yang murah. Data saham induk tetap milik klien (OLT); pencarian saham hanya mengenal kode yang pernah dibahas, di-watch, atau punya room.
- Pencarian menghormati blokir (dua arah), user yang dibisukan (postingan saja), status moderasi (`held`/`hidden` hanya terlihat penulis), akun dihapus, dan akun yang di-ban (tidak muncul di pencarian pengguna). Akun staf CS tidak bisa dicari.

### `search(p_query, p_type = 'all', p_cursor = null, p_limit = 20)` → `jsonb` (authenticated)

| `p_type` | Isi | Cursor |
|---|---|---|
| `all` | 5 teratas tiap jenis: `posts`, `users`, `stocks`, `hashtags`; `next_cursor` selalu null | tidak boleh |
| `posts` | baris `feed_post` (sama dengan feed) | `cursor` baris terakhir (keyset) |
| `users` | `{id, username, display_name, avatar_url, is_verified, follower_count, is_official, is_following, is_me}` | `o:<offset>` |
| `stocks` | `{code, posts_7d, watcher_count, is_watching}`; awalan kode, boleh diawali `$` | `o:<offset>` |
| `hashtags` | `{tag, posts_7d}`; awalan, boleh diawali `#` | `o:<offset>` |

Bentuk: `{"query": "...", "type": "posts", "posts": [...], "next_cursor": "..." | null}`. Batas `p_limit` 1–50, offset maksimal 1000.

Error: `401 not_authenticated`, `400 invalid_type`, `400 query_too_short` (< `search.min_query_length` = 2 karakter atau tanpa huruf/angka), `400 query_too_long` (> 100), `400 invalid_cursor`, `429 rate_limited` (`search`: 30/menit dan 600/jam per user, dikali faktor trust level).

Hasil `users` tidak memuat staf, akun yang diblokir/dibanned, dan sejak `0145` profil tamu pengaduan (`profiles.is_guest`).

### `get_hashtag_feed(p_tag, p_cursor = null, p_limit = 20)` → `setof feed_post`

Feed hashtag (tanpa `#`, tidak peka huruf besar). Keyset sama dengan `get_feed`; menghormati RLS, mute user, dan kata yang dibisukan. Error `400 invalid_hashtag`.

### `get_trending_hashtags(p_window = '24h', p_limit = 10)` → `table(tag, post_count, author_count, score)`

`p_window`: `24h` | `7d` (`400 invalid_window`), `p_limit` maksimal 50. Skor = jumlah bobot penulis berbeda (lihat [bobot akun baru](#trending--sentimen-0074)); hashtag butuh minimal `trending.min_authors` (2) penulis. Sejak `0081` hasil dibaca dari snapshot job `social-trending` (50 teratas per jendela), jadi tertunda maksimal 5 menit.

## Trending & sentimen (`0074`)

- Job pg_cron `social-trending` (tiap 5 menit) menghitung ulang agregat 1 jam terakhir ke `private.stock_mention_buckets(stock_code, bucket 5 menit, posts, authors, weighted, bullish/bearish/neutral, bobot sentimen)` lalu menyusun snapshot ranking `private.trending_snapshot` (saham, rising, postingan, hashtag) untuk jendela `24h` dan `7d`. Job `social-trending-rebuild` (02:40 UTC) membangun ulang 15 hari terakhir (menangkap postingan yang dihapus/ditahan belakangan) dan membuang agregat > `trending.bucket_retention_days` (35).
- **Anti-manipulasi**: satu penulis dihitung sekali per saham per 5 menit. Akun baru (lebih muda dari `trending.new_account_days` = 7 hari) atau `trust_level` 0 berbobot `trending.new_account_weight` (0,2). Saham yang punya alert manipulasi terbuka di `cs.manipulation_alerts` (dibaca bila tabel ada; kolom `stock`, `status = 'open'`) dan postingan yang membahasnya dikali `trending.manipulation_weight` (0,3). Postingan `held`/`hidden`/dihapus tidak dihitung.
- **Postingan populer**: hot score `(like + 2×komentar + 1) × bobot penulis × faktor alert / (umur_jam + 2)^trending.post_gravity` (1,5); 100 teratas per jendela disimpan di snapshot, lalu disaring per penonton (blokir, mute user, saham yang dibisukan).

### `get_stock_sentiment(p_code)` → `jsonb` (authenticated)

```json
{"code": "BBCA",
 "24h": {"posts": 4, "bullish": 2, "bearish": 1, "neutral": 0, "unlabeled": 1,
         "bullish_pct": 67, "bearish_pct": 33, "neutral_pct": 0},
 "7d": {...}, "updated_at": "..."}
```

Persentase dihitung dari postingan berlabel dengan bobot penulis (akun baru tidak bisa menggeser sentimen sendirian); `*_pct` null bila belum ada label. Data tertunda maksimal 5 menit. Error `400 invalid_stock_code`.

### `get_trending(p_window = '24h')` → `jsonb` (authenticated)

`{"window", "computed_at", "stocks": [{code, posts, score, bullish_pct, bearish_pct, neutral_pct, growth_pct}], "rising": [{code, posts, prev_posts, growth_pct}], "posts": [feed_post…], "hashtags": [{tag, post_count, author_count, score}]}` — masing-masing maksimal 10. `rising` = kenaikan skor dibanding jendela sebelumnya yang sama panjang, minimal `trending.rising_min_posts` (5) postingan. Error `400 invalid_window`.

## Edit, bookmark, reaksi, bagikan (`0075`)

### Edit postingan & komentar

- `edit_post(p_post_id, p_body)` → `setof feed_post`; `edit_comment(p_comment_id, p_body)` → `setof thread_comment`.
- Hanya penulis, dalam `content.edit_minutes` (15) menit sejak dibuat. Postingan berpolling tidak bisa diedit. Lampiran dan sentimen tidak berubah. Isi baru melewati validasi dan kebijakan konten yang sama dengan isi baru (kata terlarang, link, mention). Baris memuat `edited_at` → klien menampilkan label "diedit".
- Batas waktu juga ditegakkan untuk `UPDATE` langsung lewat REST (trigger `posts_40_edit`, `comments_40_edit`).
- Versi lama disimpan di `private.content_edits` (arsip, retensi `retention.archive_days`, mendukung `legal_hold`; lihat [Catatan operasional](#catatan-operasional)). Moderator (`community.moderate`) membaca riwayat lewat `cs_api.community_edit_history(p_target_type 'post'|'comment', p_target_id)` → `[{body, edited_at, edited_by}]`.
- Error: `404 post_not_found` / `comment_not_found`, `403 forbidden`, `403 edit_window_expired`, `409 poll_not_editable`, `400 empty_body`, `400 body_too_long`, `422 content_blocked` (dll. dari kebijakan konten), `403 social_disabled` (sebelum `0109`: `503`), `429 rate_limited` (`content_edit` 20/menit).

### Bookmark

- `toggle_bookmark(p_post_id, p_bookmarked = null)` → `boolean` (status baru). `null` = toggle, `true/false` = set idempoten. Postingan harus terlihat (`404 post_not_found`). Batas `bookmark` 120/menit.
- `get_bookmarks(p_cursor = null, p_limit = 20)` → `setof feed_post`, terbaru disimpan dulu; `cursor` di baris memakai waktu bookmark. Postingan yang dihapus/tidak terlihat lagi tidak ditampilkan.
- Tabel `public.bookmarks` hanya bisa dibaca pemiliknya; tulis hanya lewat RPC.

### Reaksi pesan chat

- Emoji tetap: 👍 ❤️ 😂 😮 😢 🔥 (`❤` tanpa variation selector dinormalkan). Satu reaksi per orang per pesan.
- `react_to_message(p_message_id, p_emoji = null)` → `{"message_id", "emoji" (null = dilepas), "reactions": [{emoji, count, me}]}`. Emoji sama dengan yang aktif = lepas; emoji lain = ganti; `null` = lepas.
- Disiarkan seperti tanda baca: `realtime.send` event **`reaction`** ke channel privat `room:<room_id>` dengan payload `{message_id, user_id, emoji, reactions: [{emoji, count}]}` (tanpa `me`; klien menghitung sendiri dari `user_id`).
- Tidak tersedia di chat CS (`400 reactions_not_supported`). Error lain: `400 invalid_emoji`, `404 message_not_found` (bukan anggota, pesan dihapus/tidak terlihat, atau saling blokir), `429 rate_limited` (`message_reaction` 60/menit).

### Info pesan (`0122`)

- Seperti "Info pesan" WhatsApp: pengirim melihat kapan pesannya **terkirim** ke perangkat dan **dibaca** tiap penerima. Ada di DM, grup, dan chat CS; room saham tidak.
- Waktu per pesan dicatat di `private.message_receipts` oleh trigger `chat_members_message_receipts` saat watermark `last_delivered_at`/`last_read_at` anggota naik (`mark_rooms_delivered`, `mark_room_read`, `cs_api.mark_read`, dan pesan yang dikirim anggota itu sendiri). Pesan yang dibuka lagi kemudian tidak mengubah waktu pertama. Satu pembaruan watermark mencatat paling banyak 1.000 pesan dari 14 hari terakhir.
- `get_message_info(p_message_id)` → `{"message_id", "sent_at", "room_type", "recipients": [{user_id, username, display_name, avatar_url, delivered, read, delivered_at, read_at}]}`, urut yang terakhir membaca lebih dulu. `delivered`/`read` berasal dari watermark, jadi tetap benar meski waktunya sudah tidak tersimpan (`*_at` = `null`, klien menampilkan "Waktu tidak tercatat"). Hanya pengirim pesan yang masih anggota room; selain itu `404 message_not_found`. Room saham mengembalikan `recipients: []`.
- Retensi 30 hari (cron harian `message-receipts-retention`). Super Admin yang memantau tiket bukan anggota room, jadi tidak pernah muncul sebagai pembaca.

### Bagikan postingan ke chat

- Kirim pesan dengan lampiran `{"type": "post", "post_id": "<uuid>"}` lewat `send_message`, atau `share_post_to_chat(p_room_id, p_post_id, p_body = null, p_client_id = null)` → `setof chat_message`. Maksimal satu postingan per pesan (boleh digabung gambar, total lampiran ≤ 4). Lampiran dinormalkan menjadi persis `{"type": "post", "post_id": ...}`.
- Validasi saat kirim: postingan ada, tidak dihapus, terlihat oleh pengirim, tidak saling blokir dengan penulisnya; tidak bisa ke chat CS (`400 share_not_allowed`). Error lain: `400 invalid_attachments`, `404 post_not_found`.
- `shared_post` di baris pesan dihitung **untuk penonton**: `{"post_id", "available": true, author_*, body (≤ 280 karakter), attachments, sentiment, stock_codes, like_count, comment_count, created_at}` bila postingan terlihat untuknya, atau `{"post_id", "available": false}` bila dihapus/ditahan/disembunyikan/saling blokir. Buka detail dengan `get_post`.
- Pratinjau room (`last_message_preview`) untuk pesan tanpa teks tetap `[lampiran]`.

### Baris baru

- `feed_post`: `is_bookmarked`, `hashtags text[]`, `is_bot` (postingan dari API bot integrasi, dari `private.post_is_bot` milik agen P), `author_is_official`.
- `feed_post`, `thread_comment`, `chat_message` (sejak `0083`): `moderation_status` = `visible` | `held` | `hidden` **hanya bila penulis/pengirim adalah pemanggil**, selain itu null. Konten `held`/`hidden` hanya terlihat oleh penulisnya (RLS), jadi klien menampilkan label "Menunggu tinjauan" (`held`) atau "Disembunyikan moderator" (`hidden`) pada konten miliknya di feed, profil, thread komentar, dan chat.
- `chat_message`: `reactions jsonb` (`[{emoji, count, me}]`, `[]` bila kosong atau pesan dihapus), `shared_post jsonb` (null bila bukan bagikan postingan).

### Permintaan pesan DM

`get_my_rooms` tidak menampilkan room DM yang masih berupa permintaan untuk **penerima**, memakai `private.dm_request_pending(room, user)` dari agen S (dicek saat runtime; bila belum ada, semua room tampil seperti sebelumnya). Pengirim tetap melihat room-nya. `get_my_room(p_room_id)` tidak disaring agar layar permintaan tetap bisa membuka room.

### Akun resmi tidak menerima DM (`0144`)

Akun resmi adalah baris aktif di `cs.official_accounts` (sumber yang sama dengan `get_official_accounts`), dicek lewat `private.is_official_account(uuid)`. Akun yang hanya terverifikasi (`is_verified`) tidak terpengaruh dan tetap bisa di-DM. Pengecualian (`private.official_dm_exempt`): akun resmi itu sendiri, staf (`cs.is_staff`), dan `service_role`.

| Jalur | Perilaku untuk user biasa |
|---|---|
| `get_or_create_direct_room(p_other_user_id)` | DM **baru** ke akun resmi ditolak `403 official_no_dm`, jadi tidak ada permintaan pesan ke akun resmi. Room DM lama tetap dikembalikan agar riwayatnya bisa dibuka |
| `create_group_room`, `add_room_members` | Menyertakan akun resmi ditolak `403 official_no_dm` (seluruh panggilan, tidak ada anggota yang ditambahkan) |
| Kirim pesan ke room DM dengan akun resmi (`send_message`, `share_post_to_chat`, kartu saham, lampiran) | Ditolak trigger `messages_26a_official_no_dm` dengan `403 official_no_dm`. Kirim ulang pesan lama dengan `client_id` yang sama tetap idempoten. Riwayat tetap bisa dibaca |
| Akun resmi sendiri | Tetap boleh memulai DM, mengirim ke DM lama (pengumuman/balasan terakhir), dan membuat grup |
| Chat CS | Tidak berubah (trigger hanya untuk pesan tanpa `session_id`) |

`get_profile` dan `search_profiles` kini mengembalikan kolom `is_official boolean`, sehingga klien tidak perlu menebak dari daftar akun resmi. Akun resmi yang dinonaktifkan (`disabled_at`) tidak lagi dihitung resmi dan kembali bisa di-DM.

### Kelola grup (`0146`)

Peran anggota grup ada di `chat_members.role`: `owner` (pembuat), `admin`, `member`. Semua RPC di bawah `authenticated`, hanya untuk room `type = 'group'` (selain itu `404 room_not_found`), dan bukan anggota ditolak `403 not_member`.

| RPC | Siapa | Catatan |
|---|---|---|
| `add_room_members(p_room_id, p_user_ids uuid[])` → `integer` | owner, admin | perilaku lama tetap (blokir, akun resmi `official_no_dm`, maks. 100 anggota); kini menulis pesan sistem `added` |
| `remove_room_member(p_room_id, p_user_id)` | owner: siapa pun selain dirinya; admin: hanya `member` | diri sendiri `400 use_leave_room`; target bukan anggota `404 member_not_found`; selain itu `403 forbidden`. Anggota yang dikeluarkan langsung kehilangan akses `get_messages`/`send_message` |
| `set_room_member_role(p_room_id, p_user_id, p_role)` | jadikan `admin`: owner, admin; jadikan `member`: owner | `p_role` hanya `admin`/`member` (`400 invalid_role`); peran owner tidak bisa diubah lewat RPC ini (`403 forbidden`); peran yang sama tidak menulis event |
| `transfer_room_ownership(p_room_id, p_user_id)` | owner | owner lama menjadi admin |
| `update_group_info(p_room_id, p_name = null, p_description = null, p_avatar_url = null)` | admin/owner, atau semua anggota bila `only_admins_edit = false` (`403 group_admins_only_edit`) | `null` = tidak diubah; `''` untuk deskripsi/foto = hapus. Nama 1–80 (`invalid_name`), deskripsi ≤ 500 (`invalid_description`), foto `http(s)://` ≤ 500 (`invalid_avatar`) |
| `update_group_settings(p_room_id, p_only_admins_send = null, p_only_admins_edit = null)` | owner, admin | bawaan `only_admins_send = false`, `only_admins_edit = true` |
| `leave_room(p_room_id)` | semua | perilaku lama tetap (owner digantikan admin paling lama, lalu anggota paling lama); kini menulis pesan sistem `left` dengan `new_owner_*` bila kepemilikan pindah |

Mengubah nama lewat `update public.chat_rooms` langsung tidak lagi diizinkan (`grant update (name)` dicabut), supaya pengaturan dan pesan sistem selalu berlaku. Trigger `messages_26b_group_admins_only` menolak pesan anggota biasa di grup `only_admins_send` dengan `403 group_admins_only` (kirim ulang `client_id` lama tetap idempoten).

`get_my_rooms`/`get_my_room` mengembalikan kolom tambahan `description`, `avatar_url`, `only_admins_send`, `only_admins_edit` (dua terakhir `null` untuk room selain grup).

**Pesan sistem grup.** Setiap perubahan menulis baris `messages` dengan `kind = 'group_event'`, `sender_id = null`, `body` kalimat bahasa Indonesia (untuk pratinjau daftar chat), dan `payload`:

| `event` | Kunci tambahan |
|---|---|
| `added` | `targets` (`[{id, name}]`, maks. 20), `count` |
| `removed`, `promoted`, `demoted`, `owner_changed` | `target_id`, `target_name` |
| `left` | `new_owner_id`, `new_owner_name` bila kepemilikan pindah |
| `renamed` | `name` |
| `description_changed`, `photo_changed` | `removed` (boolean) |
| `settings_changed` | `setting` (`only_admins_send`/`only_admins_edit`), `value` (boolean) |

Semua event membawa `actor_id` dan `actor_name`. Pesan sistem dibuat dengan klaim JWT dikosongkan sementara (pola `0040`), sehingga tidak terkena rate limit, persetujuan, dan filter pengirim; tetap disiarkan realtime dan dihitung sebagai belum dibaca, tetapi **tidak** membuat notifikasi/push (`messages_after_insert` melewati `kind = 'group_event'`). Klien yang belum mengenal `group_event` melihatnya sebagai teks biasa tanpa pengirim.

## Preferensi notifikasi (`0076`)

- Jenis (urutan = urutan di `get_notification_prefs` dan `config.notification_types`): `reply`, `mention`, `like`, `follow`, `message`, `announcement`, `appeal` (keputusan banding, sejak `0083`), `followed_post`, `watchlist_digest`, `moderation` (sejak `0087`, lihat [Notifikasi baru](#notifikasi-baru-0087)), lalu lima jenis OLT (sejak `0086`): `olt.trade`, `olt.funds`, `olt.market`, `olt.info`, `olt.promo`. Masing-masing `in_app` dan `push` (bawaan **aktif**, kecuali push `olt.promo` dan push `followed_post` yang **mati** sampai pengguna mengaktifkannya; pengguna tanpa pengaturan berperilaku persis seperti sebelumnya). `in_app` jenis `moderation` selalu aktif (`in_app_locked: true`; nilai `false` diabaikan).
- Pemetaan `kind` OLT (`private.notification_pref_type(kind, category)`): `olt.trade*`/`olt.order*` → `olt.trade` (Transaksi); `olt.deposit*`/`olt.withdrawal*`/`olt.rdn*` → `olt.funds` (Dana); `olt.price_alert*`/`olt.ipo*`/`olt.corporate_action*` → `olt.market` (Pasar); `olt.*` lain → `olt.info` (Info); pesan ber-`category` `promo` apa pun jenisnya → `olt.promo` (Promo). Kategori `important` **menembus** preferensi per jenis (in-app dan push) dan jam tenang; tetap hanya ke perangkat yang terdaftar.
- Sebelum `0086` semua `olt.*` memakai satu preferensi `olt.trade` (push saja). Migrasi `0086` menyalin `olt.trade` yang push-nya dimatikan ke `olt.funds`, `olt.market`, dan `olt.info` supaya pengguna yang sudah mematikan push OLT tetap tidak menerimanya. `olt.trade` kini juga punya `in_app` (pesan OLT bisa masuk kotak notifikasi sebagai `announcement` dengan `payload.source = 'olt'`).
- `in_app = false`: notifikasi tidak masuk kotak notifikasi; bila `push = true`, push tetap dikirim. `push = false`: push tidak diantrekan.
- **Chat CS dikecualikan**: notifikasi `message` dari room `support` selalu masuk dan selalu di-push (layanan nasabah, bukan sosial). Push uji Super Admin (`kind = 'test'`) tidak terkena preferensi maupun jam tenang.
- **Jam tenang** (WIB, bawaan mati): push yang dibuat di dalam jam tenang **ditunda** sampai jam tenang selesai (`available_at`), masa berlaku ikut digeser. Push tertunda dengan `collapse_key` sama hanya menyisakan yang terbaru. Notifikasi in-app tetap masuk seketika. Mendukung lintas tengah malam (22:00–06:00).
- Ditegakkan di trigger `push_queue_40_preferences` (BEFORE INSERT `private.push_queue`) dan `notifications_40_preferences`, jadi berlaku untuk semua jalur push (notifikasi, kampanye, API integrasi OLT) tanpa mengubah `push_enqueue`.
- `private.push_allowed(p_profile, p_kind) → boolean` (definer, untuk layanan internal seperti `integration_notify`): `false` hanya bila pengguna mematikan push jenis itu. `private.push_allowed_for(p_profile, p_kind, p_category)` (sejak `0086`) menambahkan kategori OLT: `important` selalu `true`, `promo` memakai `olt.promo`, selain itu sama dengan `push_allowed`. Trigger `push_queue_40_preferences` membaca kategori dari `data.category` baris push `olt.*`, trigger `notifications_40_preferences` dari `payload.kind`/`payload.category` notifikasi OLT, jadi keduanya memakai pemetaan yang sama.
- **Penggabungan like/follow**: like ke konten yang sama, atau follow dari siapa pun, dalam `notifications.aggregate_minutes` (60) menit sejak notifikasi pertama digabung ke satu baris belum dibaca (`event_count` +1, `actor_id` = pelaku terbaru, naik ke atas). Push hanya untuk yang pertama; push memakai `collapse_key` = `group_key`. Setelah lewat jendela atau setelah dibaca, notifikasi baru dibuat.

### RPC

- `get_notification_prefs()` → `{"types": [{type, in_app, push, in_app_locked}], "quiet_hours": {enabled, start "HH:MM", end, timezone "Asia/Jakarta"}, "aggregate_minutes": 60, "watchlist_digest": {time "HH:MM", timezone "Asia/Jakarta"}}`. `watchlist_digest.time` = jam kirim ringkasan saham pantauan yang diatur Super Admin (`0147`); tampilkan di keterangan jenis `watchlist_digest`.
- `set_notification_prefs(p_prefs jsonb)` → bentuk yang sama. Parsial: `{"types": {"like": {"push": false}}, "quiet_hours": {"enabled": true, "start": "22:00", "end": "06:00"}}` (atau `types` berupa array `[{type, in_app?, push?}]`). Error: `400 invalid_preferences`, `400 invalid_notification_type`, `400 invalid_quiet_hours`, `429 rate_limited` (`notification_prefs` 30/menit).
- `get_notifications(p_cursor, p_limit)` bertambah `actor_count integer` dan `actors jsonb` (≤ 3 pelaku terbaru `{id, username, display_name, avatar_url}`). Contoh teks: "Budi dan {actor_count−1} lainnya menyukai postingan Anda". Notifikasi lama (sebelum 0076) memiliki `actor_count` 1.

## Feature flag, kill switch, versi minimum (`0077`, `0091`)

Daftar flag **tetap**: aplikasi hanya membaca delapan kunci `search`, `trending`, `bookmarks`, `post_edit`, `message_reactions`, `share_post_to_chat`, `notification_prefs`, `analytics` (`private.known_feature_flags()`). Kunci yang tidak ada di `flags` dianggap **mati** oleh aplikasi. Flag baru tidak bisa dibuat dan flag tidak bisa dihapus; di web CS (Fitur & Kampanye → Fitur & versi) setiap fitur hanya punya sakelar nyala/mati. Menambah fitur baru = migrasi baru yang memperluas daftar.

### `get_client_config(p_platform = null, p_app_version = null)` → `jsonb` (`anon` dan `authenticated`)

```json
{"social_enabled": true,
 "flags": {"search": true, "trending": true, "bookmarks": true, "post_edit": true, "message_reactions": true,
           "share_post_to_chat": true, "notification_prefs": true, "analytics": true},
 "min_version": {"android": "2.10.0", "ios": null, "web": null},
 "update_required": false,
 "config": {"edit_minutes": 15, "message_reactions": ["👍","❤️","😂","😮","😢","🔥"], "search_min_length": 2,
            "notification_types": [...], "notification_aggregate_minutes": 60,
            "trending_windows": ["24h","7d"], "server_time": "..."}}
```

- Panggil saat aplikasi dibuka (sebelum login boleh). `p_platform`: `android|ios|web` (`400 invalid_platform`), `p_app_version` berformat angka `2.4.1` (boleh akhiran build `+57`; `400 invalid_version`). Perbandingan versi per angka (2.10.0 > 2.9.9).
- Flag aktif bila `enabled` dan cocok platform (kosong = semua) dan versi ≥ `min_app_version`, lalu: persentase 100, **atau** user ada di `user_ids`, **atau** `md5(key:sub)` jatuh di bawah persentase (deterministik per user, berbeda per flag). Pengguna anonim hanya mendapat flag 100%.
- **Kill switch** (`social_enabled = false`): klien menyembunyikan UI sosial. Server menolak postingan, komentar, edit, dan pesan chat **non-CS** baru dari pengguna aplikasi dengan `403 social_disabled` (SQLSTATE `PT403`, migrasi `0109`; sebelumnya `503`, yang membuat PostgREST mengira database putus, T24). Chat CS tetap berjalan. Membaca, like, follow, reaksi tetap jalan. Postingan staf/akun resmi/bot (bukan pengguna aplikasi) tidak diblokir.

### RPC Super Admin (`cs_api`, peran `cs_super_admin` atau `product` sejak `0121`, semua tercatat di audit)

- `admin_feature_flags()` → `{kill_switch: {social_enabled, reason, changed_by, changed_at}, flags: [...], min_versions: [...]}`; `flags` hanya berisi delapan flag tetap dalam urutan di atas.
- `admin_toggle_feature_flag(p_key, p_enabled)` — satu-satunya yang dipakai web CS: hanya mengubah `enabled`, kolom lain tetap; audit `feature_flag.set` (before/after). Error `400 unknown_flag` (kunci di luar daftar), `400 invalid_flag` (`p_enabled` kosong).
- `admin_set_feature_flag(p_key, p_enabled, p_percentage = 100, p_user_ids = '{}', p_platforms = '{}', p_min_app_version = null, p_description = null)` — tetap ada untuk kompatibilitas (rollout persentase/platform/versi), tetapi hanya untuk kunci yang dikenal; audit `feature_flag.set`. Error `400 use_kill_switch` (kunci `social.enabled`), `invalid_flag_key`, `unknown_flag`, `invalid_percentage`, `invalid_platform`, `too_many_users` (> 1000), `invalid_version`.
- `admin_delete_feature_flag(p_key)` — selalu ditolak `400 flag_not_deletable`; matikan fitur alih-alih menghapusnya.
- `admin_set_kill_switch(p_enabled, p_reason)` — alasan wajib 10–500 karakter (`400 reason_required`) untuk mematikan maupun menghidupkan; audit `kill_switch.set`.
- `admin_set_min_version(p_platform, p_min_version | null)` — audit `client.min_version_set`.

Fungsi server lain bisa memakai `private.feature_enabled(key, user)` dan `private.social_enabled()`.

## Analitik (`0078`)

- `private.analytics_events` dipartisi bulanan (pola `cs.ensure_partitions`): job `social-analytics` (02:25 UTC) membuat partisi bulan lalu s.d. 3 bulan ke depan dan **menghapus partisi** lebih tua dari `analytics.retention_months` (12) bulan; baris lama di partisi default ikut dihapus.
- Event yang diizinkan: `feed_open`, `post_create`, `comment_create`, `message_send`, `stock_tap`, `order_tap`, `search`, `share_chart`. **Tanpa teks bebas**: properti selain daftar berikut dibuang diam-diam.

| Properti | Nilai |
|---|---|
| `stock_code` | kode saham (dinormalkan huruf besar) |
| `post_id`, `room_id`, `target_id`, `notification_id` | UUID |
| `hashtag` | `^[a-z0-9_]{2,50}$` |
| `source` | `feed, post, comment, chat, search, profile, notification, stock, hashtag, trending, push, deep_link, share, other` |
| `scope` | `global, following, stock, user, hashtag, bookmarks, trending` |
| `type` | `all, posts, users, stocks, hashtags, direct, group, stock, support, text, image, post` |
| `side` | `buy, sell` |
| `interval` | `intraday, 1d, 1w, 1m, 3m, 6m, 1y, 5y, all` |
| `result_count`, `position`, `query_length`, `duration_ms` | bilangan bulat ≥ 0 |
| `has_attachment`, `has_poll`, `is_reply` | boolean |

### `track_events(p_events jsonb, p_platform = null, p_app_version = null)` → `{"accepted", "dropped"[, "disabled": true]}` (authenticated)

`p_events` = array maksimal `analytics.max_batch` (50) objek `{"event", "ts"?, "props"?}`. `ts` ISO-8601 dipakai bila dalam 7 hari terakhir s.d. 5 menit ke depan, selain itu waktu server. Event tak dikenal dibuang (dihitung `dropped`). Flag `analytics` mati → tidak dicatat, `disabled: true`. Error: `400 invalid_events`, `400 too_many_events`, `400 invalid_platform`, `429 rate_limited` (`analytics` 30/menit, 2000/hari). Klien sebaiknya menampung event dan mengirim per 20–50 event atau saat aplikasi ke latar belakang. Contoh pencarian: kirim `{"event": "search", "props": {"type": "posts", "query_length": 9, "result_count": 12}}`, **jangan** kirim kata kuncinya.

### `cs_api.admin_analytics(p_from date = null, p_to date = null)` → `jsonb` (Super Admin)

Bawaan 30 hari terakhir (WIB), maksimal 366 hari (`400 invalid_range`).

- `active_users`: `dau` (`[{date, users}]` per hari), `avg_dau`, `wau`, `mau` (7/30 hari berakhir di `p_to`), `stickiness_pct`. Aktif = mengirim minimal satu event analitik.
- `retention`: kohort mingguan pengguna baru (minggu Senin–Minggu, dari `profiles.created_at` dalam rentang; tanpa akun resmi/staf): `[{cohort_week, users, weeks: [{week 0..7, active, pct}]}]`.
- `content`: jumlah `posts`, `comments`, `messages` (non-CS), `likes`, serta `daily` posts/komentar.
- `top_stocks`: 10 saham paling dibahas (postingan terlihat, penulis berbeda).
- `events`: jumlah per jenis event.
- `order_taps`: `taps`, `users`, `stock_tap_users`, `conversion_pct` (user order_tap / user stock_tap), `by_source`, `top_stocks`.

## Ekspor data

`export_my_data()` kini juga memuat `bookmarks`, `message_reactions`, `notification_preferences`, `dm_policy` (sejak `0083`), `linked_accounts` (rekening OLT tertaut dari agen P, bila fungsi `private.account_links_export` ada), `appeals` (banding dari agen S, dibaca dari `public.appeals` bila tabel ada; kolom pemilik `user_id`/`appellant_id`/`created_by`), `analytics_events` (5000 terakhir), `post_drafts` (sejak `0090`), dan `notification_events` (event dibuka/diketuk notifikasi, 5000 terakhir: `{event, source_type, source_id, notification_id, created_at}`).

## Hapus akun

Trigger `profiles_40_social_forget` (saat `profiles.deleted_at` terisi) menghapus bookmark, reaksi pesan, preferensi & jam tenang, jejak pelaku notifikasi (`private.notification_actors`), event analitik pengguna, dan draf postingan (sejak `0090`). Event dibuka/diketuk notifikasi dianonimkan (`user_id = null`) agar statistik kampanye/siaran tidak berubah. Riwayat edit (`private.content_edits`) tetap disimpan sebagai arsip regulator, sama seperti `private.content_archive`.

## Catatan untuk pengembang klien

1. Panggil `get_client_config(platform, versi)` saat start dan saat kembali ke foreground; hormati `update_required`, `social_enabled`, dan `flags`. Tangani error dengan kode `social_disabled` dari tulis konten (status `403`, backend lama `503`; kenali dari kodenya, bukan statusnya) dengan pesan "sementara tidak tersedia", bukan error umum.
2. Label "diedit" dari `edited_at`; tombol edit hanya bila `now - created_at < config.edit_minutes` dan bukan postingan polling (server tetap memeriksa).
3. Search-as-you-type: debounce ±300 ms, minimal `config.search_min_length` karakter; `p_type = 'all'` untuk saran, lalu per jenis dengan cursor.
4. Reaksi pesan: optimistic update, lalu sinkron dari event Realtime `reaction` (field `reactions` adalah total terbaru). Baris pesan dari `get_messages` sudah membawa `reactions` dengan `me`.
5. Bagikan postingan: render kartu dari `shared_post`; bila `available = false` tampilkan "Postingan tidak tersedia".
6. Notifikasi: gunakan `actor_count`/`actors` untuk teks gabungan; jangan menghitung dari `event_count` (bisa lebih besar karena like-unlike berulang).
7. Analitik: jangan pernah kirim teks pengguna (isi postingan, kata kunci, nama). Properti tak dikenal dibuang server.

## Catatan operasional

- Semua job baru: `social-trending` (*/5 menit), `social-trending-rebuild` (harian), `social-analytics` (harian), `social-content-edits-retention` (03:35 UTC). Pantau dengan `select * from cron.job_run_details order by start_time desc`.
- Uji beban sintetis (30.000 postingan/7 hari, 200 penulis, dalam transaksi yang di-rollback, setelah `0081`): `get_feed` ±3 ms, `get_hashtag_feed` ±3 ms, `search(... 'posts')` ±80 ms (kata umum yang cocok ribuan postingan), `get_trending('24h')` ±2 ms, `get_trending('7d')` ±4 ms, `get_trending_hashtags` < 1 ms, `get_stock_sentiment` ±1 ms, job 5 menit ±0,3 dtk, rebuild harian ±0,4 dtk. Sebelum `0081`, hashtag trending dihitung langsung (7 hari ±370 ms) dan bobot penulis dipanggil per baris.
- Riwayat edit `private.content_edits` dibersihkan job `social-content-edits-retention` (`private.content_edits_purge()`, maks 50.000 baris per jalan): baris dihapus bila tidak `legal_hold`, `retain_until` sudah lewat, **dan** `edited_at` lebih tua dari `retention.archive_days` (1825) saat ini. Jadi menaikkan setting langsung memperpanjang retensi; menurunkannya berlaku untuk baris yang `retain_until`-nya juga sudah lewat (sama konservatifnya dengan arsip regulator).

## Banner aplikasi (`0089`)

`get_client_config(p_platform, p_app_version)` (anon dan authenticated) kini memuat kunci tingkat atas **`banners`**: maksimal 10 banner yang aktif **saat ini** untuk platform dan versi pemanggil, urut `priority` menurun lalu `starts_at` terbaru.

```json
"banners": [{"id": "uuid", "title": "Pemeliharaan sistem", "body": "Chat dipelihara pukul 22.00 WIB",
             "link_url": "https://olt.example/status", "level": "warning", "dismissible": true, "priority": 10,
             "starts_at": "2026-11-03T10:00:00+00:00", "ends_at": "2026-11-04T10:00:00+00:00"}]
```

- Aktif = `starts_at ≤ now` dan (`ends_at` kosong atau `> now`). `platforms` kosong = semua platform; bila diisi, banner hanya tampil bila `p_platform` termasuk di dalamnya. `min_app_version`/`max_app_version` (inklusif, perbandingan per angka) hanya terpenuhi bila `p_app_version` dikirim. `link_url` boleh `null`; `body` boleh kosong.
- `level`: `info` | `warning` | `critical` (gaya tampilan diserahkan ke klien). `dismissible = false` → jangan tampilkan tombol tutup.
- **Penutupan disimpan klien** (tidak ada status di server): simpan `id` banner yang ditutup di penyimpanan lokal dan sembunyikan id itu. Mengubah banner mempertahankan `id`; untuk menampilkan ulang ke semua orang, Super Admin membuat banner baru.

RPC Super Admin (`cs_api`, peran `cs_super_admin`, semua tercatat di audit dengan isi sebelum/sesudah):

- `admin_banners()` → `[{id, title, body, link_url, level, starts_at, ends_at, platforms, min_app_version, max_app_version, dismissible, priority, status: active|scheduled|ended, created_by {id, name}, updated_by, created_at, updated_at}]` (aktif/terjadwal dulu, yang berakhir di akhir).
- `admin_save_banner(p_id uuid, p_title text, p_body text = '', p_link_url text = null, p_level text = 'info', p_starts_at timestamptz = null, p_ends_at timestamptz = null, p_platforms text[] = '{}', p_min_app_version text = null, p_max_app_version text = null, p_dismissible boolean = true, p_priority integer = 0)` → satu banner (bentuk seperti daftar). `p_id = null` membuat baru; `p_starts_at = null` berarti sekarang (saat membuat) atau tetap (saat mengubah). Audit `banner.save`. Error `400`: `invalid_title` (1–80), `invalid_body` (> 300), `invalid_link` (harus `http(s)://`, ≤ 500), `invalid_level`, `invalid_platform` (android, ios, web, windows, macos, linux), `invalid_version` (format `2.4.0`, min ≤ max), `invalid_priority` (0–1000), `invalid_schedule` (`ends_at` harus setelah `starts_at`); `404 banner_not_found`.
- `admin_delete_banner(p_id)` → `{"id", "deleted": true}`; audit `banner.delete`; `404 banner_not_found`.

## Popup promo dan deep link banner (`0119`)

Banner kini punya dua tampilan: `strip` (bawaan, perilaku `0089`) dan `popup` (kartu di tengah layar). Semua tambahan bersifat aditif; banner lama tetap `strip`, field lama tidak berubah.

```json
"banners": [{"id": "uuid", "title": "Promo akhir tahun", "body": "Diskon biaya transaksi 50%",
             "link_url": "olt://promo/akhir-tahun", "level": "info", "dismissible": true, "priority": 50,
             "starts_at": "2026-11-05T01:00:00+00:00", "ends_at": "2026-11-12T01:00:00+00:00",
             "display": "popup",
             "image_url": "https://api.olt.example/storage/v1/object/public/app-banners/3f2a…c1.jpg",
             "cta_label": "Lihat promo", "frequency": "daily"}]
```

- `display`: `strip` | `popup`. `image_url`: URL publik penuh gambar popup di bucket `app-banners` atau `null` (strip selalu `null`). `cta_label`: label tombol ≤ 24 karakter atau `null`; bila ada `link_url` tanpa label, klien memakai label bawaan. `frequency` (hanya bermakna untuk popup, strip selalu `once`): `once` (sekali per pengguna), `daily` (sekali per hari), `every_open` (setiap aplikasi dibuka). Penjadwalan frekuensi disimpan klien, seperti penutupan banner.
- **Sasaran** disaring server: `audience = all` atau `new_users` (profil dibuat ≤ `audience_days` hari lalu, 1–90). Pemanggil tanpa login hanya menerima banner `all`. Field sasaran tidak dikirim ke klien.
- **`link_url`** boleh `https://…` atau deep link `<skema>://…` dengan skema dari setting `banners.deep_link_schemes` (`cs.cs_settings`, bawaan `["olt"]`, maks 5, `^[a-z][a-z0-9+.-]{0,31}$`; `http`, `https`, `javascript`, `vbscript`, `data`, `file`, `filesystem`, `blob`, `about`, `intent`, `content` ditolak). Server hanya mengirim `link_url` (dan `cta_label`) bila tautan masih valid: `http(s)://` lama tetap dikirim, deep link yang skemanya sudah dicabut dikirim sebagai `null`. Constraint tabel `app_banners_link_url_check` menolak skema berbahaya walau lewat SQL langsung.
- Maksimal tetap 10 banner aktif (strip dan popup bersama), urut prioritas.

### `record_banner_event(p_banner_id uuid, p_event text)` → `{"recorded": boolean}` (authenticated, nasabah)

- `p_event`: `impression` (popup/strip ditampilkan), `click` (tombol/tautan diketuk), `dismiss` (ditutup). Lainnya → `400 invalid_event`.
- Dedupe per (banner, pengguna, event, hari WIB): panggilan berulang menjawab `recorded: false`, tidak pernah error. Banner yang tidak ada, belum mulai, sudah selesai, atau di luar sasaran pengguna juga menjawab `recorded: false` (tidak membocorkan keberadaan banner).
- Tanpa login → `401 not_authenticated` (anon tidak punya hak execute). Akun CS → `403 customer_required`. Rate limit `banner_event` 120/menit (`429 rate_limited`).
- Disimpan di `private.app_banner_events` (RLS, tanpa akses langsung), retensi 180 hari (`banners.events_retention_days` di `private.settings`) lewat job harian `app-banner-maintenance` (03:47 UTC), yang juga membersihkan baris rate limit `banner_event` lama dan memasukkan gambar `app-banners` yatim > 1 hari ke antrean janitor.

### Gambar popup

Bucket `app-banners`: publik baca (`/storage/v1/object/public/app-banners/<uuid>.<jpg|png|webp>`), maks 2 MB, JPEG/PNG/WebP. Tulis dan daftar objek hanya untuk Super Admin (`private.can_manage_banners()`, aal2) lewat upload Storage langsung dari Hub, sama dengan foto akun resmi; kebijakan restriktif `cs_staff_public_edge` (`0105`) tetap menolak staf dari domain publik. Tidak ada kebijakan update/delete; gambar yang diganti, dilepas, atau banner yang dihapus masuk `private.storage_cleanup_queue` dan dihapus janitor. Hub memotong gambar ke 4:5 (960×1200) atau 1:1 (960×960) dan mengecilkannya di bawah 2 MB sebelum unggah.

### RPC Super Admin tambahan (juga peran `product`, `0121`)

- `admin_save_banner(..., p_display text = 'strip', p_image_url text = null, p_cta_label text = null, p_frequency text = 'once', p_audience text = 'all', p_audience_days integer = 7)`: `p_image_url` adalah URL publik hasil unggah (path diambil dari URL dan objeknya harus ada di `app-banners`). Error `400` baru: `invalid_display`, `invalid_image` (bukan popup, bukan bucket `app-banners`, atau objek tidak ada), `invalid_cta` (> 24 atau tanpa tautan), `invalid_frequency`, `invalid_audience` (atau hari di luar 1–90); `invalid_link` kini berarti bukan `https://` atau skema deep link terdaftar.
- `admin_banners()` dan hasil `admin_save_banner` bertambah `display`, `image_path`, `image_url`, `cta_label`, `frequency`, `audience`, `audience_days`, dan `stats {impressions, clicks, dismissals, unique_viewers, ctr}` (`ctr` = klik ÷ tayang × 100, satu desimal, `null` bila belum ada tayang).
- `admin_banner_stats(p_id)` → `stats` + `{"id", "days": [{day, impressions, clicks, dismissals, ctr}]}` untuk 7 hari terakhir (WIB, termasuk hari tanpa event); `404 banner_not_found`.
- `admin_banner_settings()` → `{deep_link_schemes, forbidden_schemes, max_schemes, updated_at, updated_by}`; `admin_set_banner_link_schemes(p_schemes text[])` (khusus Super Admin sejak `0124`, dari Pengaturan → Integrasi → Integrasi aplikasi; dinormalkan huruf kecil, unik) → bentuk yang sama, audit `banner.link_schemes` dengan nilai sebelum/sesudah; `400 invalid_link_schemes`.

## Statistik dibuka/diketuk notifikasi (`0088`)

### `report_notification_event(p_event, p_notification_id = null, p_campaign_id = null, p_broadcast_id = null)` → `jsonb` (authenticated)

```json
{"recorded": true, "source": "campaign", "source_id": "uuid", "read": true}
```

- `p_event`: `opened` = pengguna membuka notifikasi (mengetuk push sistem atau membuka item di kotak notifikasi); `tapped` = pengguna mengikuti tujuan notifikasi (tautan/postingan/layar tujuan). `tapped` otomatis juga mencatat `opened`.
- Sumber: kirim `notification_id` bila ada (data push dan baris `get_notifications`); bila tidak ada, kirim `campaign_id` atau `broadcast_id` dari data push. Server mencari kampanye/siaran dari `payload.campaign_id` / `payload.broadcast_id` notifikasi milik pemanggil. Prioritas atribusi: kampanye → siaran OLT → notifikasi itu sendiri (`source = "notification"`). Notifikasi milik orang lain, kampanye yang belum dikirim, atau id yang tidak dikenal → `{"recorded": false, "source": null, ...}` tanpa error.
- **Dedupe** per (pengguna, sumber, event): event kedua dijawab `recorded: false`. `read = true` bila notifikasi milik pemanggil baru saja ditandai dibaca (terjadi untuk `opened` maupun `tapped`).
- Error: `400 invalid_event`, `400 missing_source` (ketiga id kosong), `401 not_authenticated`, `429 rate_limited` (`notification_event` 120/menit). Klien boleh "kirim lalu lupakan"; kegagalan tidak perlu ditampilkan.
- Data push yang relevan (semua nilai string): `notification_id` (push dari kotak notifikasi, termasuk siaran OLT yang masuk kotak masuk), `campaign_id` (kampanye Komunitas), `broadcast_id` (siaran OLT, sejak `0088`; juga ada di `payload` notifikasi kotak masuknya).
- Penyimpanan: `private.notification_events`. Saat akun dihapus, `user_id` dikosongkan sehingga angka statistik tetap.

Web CS: setiap baris `cs_api.community_campaigns()` (dan respons `community_save_campaign`/`submit`/`review`/`cancel`) serta `cs_api.community_campaign_push(id)` kini memuat `opened`, `tapped` (jumlah pengguna unik), `open_rate`, `tap_rate` (persen dari `recipients`, 1 desimal; `null` bila `recipients = 0`). `cs_api.integration_broadcasts()` memuat field yang sama terhadap `recipients` siaran.

## Segmen kampanye notifikasi (`0088`)

`cs.community_campaigns.audience` kini: `all`, `stock` (pemantau saham, seperti sebelumnya), plus:

| Segmen | Parameter | Penerima |
|---|---|---|
| `new_users` | `days` 1–365 | profil dibuat kurang dari N hari lalu |
| `inactive` | `days` 1–365 | aktivitas terakhir ≥ N hari lalu. Aktivitas = nilai terbesar dari login/tukar token terakhir (`private.user_private.last_login_at`), `last_seen_at` perangkat push, dan event analitik terakhir; bila tidak ada, tanggal profil dibuat |
| `platform` | `platform` (android, ios, web, windows, macos, linux) | punya perangkat push terdaftar di platform itu **atau** platform event analitik terakhirnya sama |
| `followers` | `account_id` akun resmi aktif | pengikut akun resmi itu |

Semua segmen tetap mengecualikan profil terhapus, akun resmi, dan staf. Alur empat mata tidak berubah.

- `cs_api.community_audience_size(p_audience, p_stock = null, p_days = null, p_platform = null, p_account_id = null)` → `integer` (izin `community.post` atau `community.publish`). Panggilan lama `(audience, stock)` tetap jalan.
- `cs_api.community_save_campaign(p_id, p_account_id, p_title, p_body, p_link_post_id = null, p_link_url = null, p_audience = 'all', p_audience_stock = null, p_send_at = null, p_version = null, p_audience_days = null, p_audience_platform = null, p_audience_account_id = null)`: tiga parameter baru di akhir (kompatibel). Parameter yang tidak relevan dengan segmen dibersihkan. Audit `community.campaign_save` kini memuat `audience`.
- Error `400 invalid_audience` dengan detail: segmen tidak dikenal, kode saham salah, hari di luar 1–365, platform tidak dikenal, atau akun pengikut bukan akun resmi aktif.
- Bentuk kampanye bertambah `audience_days`, `audience_platform`, `audience_account` (`{id, username, display_name, avatar_url}` atau null) serta statistik di atas.

## Notifikasi baru (`0087`)

Notifikasi masuk lewat `get_notifications` seperti biasa (tipe baru di kolom `type`). Data push memakai pola standar: semua kunci `payload` kecuali `title`/`body`/`snippet`/`excerpt`, ditambah `source = "rendezvous_community"`, `type`, `kind` (= type), `notification_id`, `actor_id`, `actor_username`. Semua nilai data push berupa string (array/boolean diserialisasi JSON, mis. `stocks = "[\"BBCA\"]"`, `appealable = "true"`).

### Mention di room saham (tipe `mention`)

- `@username` di pesan room **saham** memberi notifikasi ke maksimal `notifications.mention_room_max` (5) pengguna pertama yang disebut. Tidak untuk diri sendiri, profil terhapus, pengguna yang sedang di-ban, pengguna yang membisukan pengirim, atau pasangan yang saling blokir. Mute room tidak menahan mention. Pesan yang ditahan (`held`) tidak memberi notifikasi. Preferensi `mention` berlaku.
- `payload`: `{"room_id", "room_type": "stock", "room_name", "stock_code", "message_id", "snippet"}` (bedakan dari mention postingan yang memuat `post_id`/`comment_id`). Buka room saham lalu gulir ke `message_id`.
- Digabung per room per pengguna (`group_key = mention:room:<room_id>`): mention berikutnya sebelum dibaca menaikkan `event_count`. Push: judul "Budi menyebut Anda di $BBCA", isi cuplikan; `collapse_key` sama.

### Postingan baru dari akun yang diikuti (tipe `followed_post`; bawaan in-app aktif, push **mati**)

- Saat pengguna memposting konten yang langsung terlihat (`visible`), pengikutnya diberi notifikasi oleh job `social-followed-posts` (tiap 30 detik, `notifications.followed_post_batch` = 5000 pengikut per putaran). Dilewati: pengikut yang membisukan/saling blokir dengan penulis, profil terhapus, postingan yang ditahan/dihapus sebelum job berjalan, postingan lebih dari 1 hari.
- **Akun resmi, staf, dan postingan bot integrasi tidak memicu notifikasi ini**; mereka memakai pengumuman/kampanye Komunitas (opsi "beri notifikasi") agar pengikut tidak menerima dobel.
- `payload`: `{"post_id", "author_id", "snippet"}`; `actor_id` = penulis. Digabung per penulis per jam (UTC) selama belum dibaca: `event_count` = jumlah postingan, `payload.post_id` = postingan terbaru. Push hanya untuk postingan pertama dalam jam itu ("Budi membuat postingan baru").

### Ringkasan saham pantauan (tipe `watchlist_digest`; bawaan in-app dan push aktif)

- Job `social-watchlist-digest` setiap hari pada jam `notifications.watchlist_digest_time` (bawaan 17.05 WIB = 10.05 UTC), sekali per hari menurut tanggal WIB (`private.watchlist_digest_runs`). Super Admin mengubah jamnya di Hub → Push notification (`admin_set_setting`, tercatat di riwayat pengaturan dan jejak audit); trigger di `cs.cs_settings` langsung menjadwalkan ulang job (`0147`). Bila jam diubah setelah ringkasan hari itu terkirim, ringkasan berikutnya baru besok. Rentang = sejak ringkasan sebelumnya (pertama kali `notifications.digest_lookback_hours` = 24 jam; maksimal 7 hari).
- Satu notifikasi per pengguna yang punya postingan baru **terlihat** tentang saham pantauannya (`stock_watchers`), tidak termasuk postingan sendiri, penulis yang dibisukan/saling blokir, dan saham yang dibisukan (`muted_stocks`). Pengguna tanpa postingan baru tidak diberi notifikasi.
- `payload`: `{"date": "2026-11-03", "post_count": 12, "stock_count": 4, "stocks": ["BBCA", "TLKM", "ASII"], "since", "until"}`; `stocks` = 3 kode dengan postingan terbanyak, `post_count` = postingan unik. Tanpa `actor_id`. Push: "Ringkasan saham pantauan" / "12 postingan baru tentang $BBCA, $TLKM, $ASII, dan 1 saham lainnya". Ketuk → feed saham/watchlist.

### Notifikasi moderasi (tipe `moderation`; in-app selalu aktif, push bawaan aktif)

- Dikirim ke penulis saat postingan/komentar/pesan miliknya **disembunyikan** moderator (`moderation_status` → `hidden`) atau **dihapus** moderator (arsip alasan `moderator_remove`), dari jalur mana pun (web CS, admin, moderator room). Tidak dikirim untuk penahanan otomatis (`held`), konten staf/akun resmi, chat CS, atau sanksi toleransi nol.
- `payload`: `{"target_type": "post"|"comment"|"message", "target_id", "state": "hidden"|"removed", "excerpt" (≤ 140 karakter), "appealable": true|false}` + `post_id` (komentar) atau `room_id` (pesan). `appealable = false` bila banding untuk konten itu sudah pernah diajukan. Tanpa `actor_id` (moderator tidak diungkap). Ketuk → layar konten yang dimoderasi (`get_my_moderated_content`) / `create_appeal`.
- Push: "Postingan Anda disembunyikan moderator" / "Komentar Anda dihapus moderator", isi "Ketuk untuk melihat detail dan mengajukan banding"; data push tanpa `excerpt`.

## Draf postingan (`0090`)

Tabel `public.post_drafts` (hanya bisa dibaca pemiliknya; tulis lewat RPC). Maksimal `drafts.max_per_user` (20) draf.

- `save_post_draft(p_client_draft_id uuid, p_body text = '', p_sentiment text = null, p_stocks text[] = '{}', p_attachments jsonb = '[]', p_poll jsonb = null, p_base_updated_at timestamptz = null)` → draf. Upsert per `client_draft_id` (dibuat klien). Teks dirapikan, kode saham dinormalkan (huruf besar, tanpa duplikat). `p_base_updated_at` = `updated_at` draf yang terakhir diketahui klien; bila draf di server lebih baru → `409 draft_conflict` (muat ulang). Tanpa `p_base_updated_at` = tulis terakhir menang.
- `get_post_drafts()` → `[{id, client_draft_id, body, sentiment, stocks, attachments, poll, created_at, updated_at}]` terbaru dulu.
- `delete_post_draft(p_client_draft_id)` → `boolean` (`false` bila tidak ada).
- `create_post(..., p_client_id => client_draft_id)` menghapus draf dengan id itu secara otomatis.
- Validasi: isi ≤ 2000 (`400 body_too_long`), sentimen `bullish|bearish|neutral` (`400 invalid_sentiment`), ≤ 10 kode `^[A-Z][A-Z0-9]{1,11}$` (`400 invalid_stocks`), lampiran ≤ 4 di folder `posts/<uid>/` (`400 invalid_attachments`), `poll` objek ≤ 4000 byte (`400 invalid_poll`, isinya divalidasi saat terbit), draf kosong (`400 empty_draft`), tanpa id (`400 invalid_draft`), `409 draft_limit`, `429 rate_limited` (`post_draft` 60/menit). Ikut `export_my_data` (`post_drafts`) dan terhapus saat akun dihapus.

## Kartu saham di chat (`0090`)

- Lampiran `{"type": "stock", "code": "BBCA"}` lewat `send_message(..., p_attachments)` di room `direct`, `group`, dan `stock` (bukan chat CS: `400 share_not_allowed`). Maksimal 3 kode unik per pesan (`400 invalid_attachments`), format `^[A-Z][A-Z0-9]{1,11}$` (huruf kecil/spasi dinormalkan). Kunci lain (mis. harga) dibuang; lampiran dinormalkan menjadi persis `{"type", "code"}`.
- Boleh digabung dengan gambar dan satu bagikan postingan. Urutan tersimpan: gambar, postingan, kartu saham. Baris `get_messages` menampilkannya apa adanya di `attachments`; **harga diambil klien dari aplikasi OLT**. Pratinjau room untuk pesan tanpa teks tetap `[lampiran]`.

## Catatan untuk klien (`0087`–`0090`)

1. Render `banners` dari `get_client_config` sesuai `display` (strip atau popup); simpan id yang ditutup dan jadwal `frequency` secara lokal; hormati `dismissible`; laporkan `impression`/`click`/`dismiss` lewat `record_banner_event` (`0119`).
2. Laporkan `opened` saat push dibuka atau item kotak notifikasi dibuka, dan `tapped` saat tujuan diikuti, lewat `report_notification_event` (pakai `notification_id` bila ada, selain itu `campaign_id`/`broadcast_id` dari data push). Server menandai notifikasi dibaca.
3. Tampilkan jenis preferensi baru dari `get_notification_prefs`; nonaktifkan sakelar in-app bila `in_app_locked`.
4. Tangani tipe notifikasi `followed_post`, `watchlist_digest`, `moderation`, dan `mention` ber-`room_id` (lihat payload di atas). Klien lama menampilkan tipe yang belum dikenal sebagai notifikasi umum.
5. Draf: simpan lokal + `save_post_draft` (debounce), gunakan `client_draft_id` sebagai `p_client_id` saat menerbitkan.
6. Kartu saham: render dari `attachments` bertipe `stock`; ambil harga dari aplikasi OLT.

Job baru: `social-followed-posts` (30 detik), `social-watchlist-digest` (bawaan 10.05 UTC; jamnya diatur dari Hub sejak `0147`).

## Moderator room (`0093`)

Nasabah tepercaya bisa ditunjuk staf (izin `community.moderate`) menjadi moderator room saham dari web CS: Komunitas → Room saham → Moderator room. Kuasa mereka terbatas pada room itu saja.

Syarat dan batas (`private.settings`, diubah Kepatuhan/Super Admin lewat `cs_api.community_set_room_moderator_settings`, tercatat di audit):

| Kunci | Bawaan | Rentang |
| --- | --- | --- |
| `room_mods.min_trust_level` | 2 (tepercaya) | 1–3 |
| `room_mods.sanction_free_days` | 90 hari tanpa sanksi (sanksi yang dicabut tidak dihitung; zero tolerance selalu menolak) | 0–365 |
| `room_mods.max_mute_hours` | 24 jam | 1–24 |
| `room_mods.max_per_room` | 10 moderator | 1–50 |
| `room_mods.max_rooms_per_user` | 3 room | 1–20 |

Akun staf CS, akun resmi, dan agen tidak bisa ditunjuk. Moderator yang dikenai sanksi apa pun otomatis dicopot (`community.room_moderator_auto_remove`); trust level yang turun menangguhkan hak (`403 room_moderator_suspended`).

### RPC nasabah (authenticated)

- `room_mod_hide_message(p_message_id, p_reason, p_note = null)` → `{id, action: "hide", room_id, target_user_id, message_id, ...}`. Pesan menjadi `hidden` (bisa dipulihkan staf), pengirim mendapat notifikasi `moderation` dan bisa banding lewat `create_appeal('message', id, ...)` / `get_my_moderated_content`. Disiarkan ke `room:<id>` sebagai event `message_hidden` `{message_id, user_id}`.
- `room_mod_mute_user(p_room_id, p_user_id, p_minutes, p_reason, p_note = null, p_message_id = null)` → `{..., mute_until}`. 5 menit sampai `max_mute_hours`. Anggota yang dibisukan ditolak saat mengirim pesan di room itu: `403 room_muted`, `detail` = batas waktu ISO UTC. Tetap bisa membaca.
- `room_mod_escalate(p_message_id, p_reason, p_note = null)` → `{..., report_id}`. Membuat laporan di antrean staf (`details` diawali `[Moderator room $KODE]`). Boleh untuk pesan moderator lain; tidak untuk pesan sendiri.
- `p_reason`: `spam|abuse|scam|pump_and_dump|misinformation|other` (`400 invalid_mod_reason`), catatan ≤ 500 (`400 invalid_note`).
- Galat: `403 not_room_moderator`, `403 room_moderator_suspended`, `403 protected_account` (akun resmi/staf), `403 moderator_target` (moderator lain), `403 self_target`, `404 message_not_found` (hanya pesan room saham yang tampil), `409 already_moderated|already_muted|already_escalated`, `429 rate_limited` (`room_mod_action` 15/jam dan 50/hari, dikali faktor trust).
- Moderator **tidak** bisa: menghapus akun, melihat DM, mengubah sematan/slow mode, atau menindak akun resmi, staf, dan moderator lain.

`get_stock_room_state` dan siaran `room_state` memuat `moderators` (array user id, untuk lencana). `get_stock_room_state` juga memuat `is_moderator` dan `muted_until` milik pemanggil.

#### Privasi bisu (`0096`)

Siapa yang sedang dibisukan tidak dibagikan ke anggota room (di room saham, itu sama dengan membuka siapa yang sedang ditindak):

- Siaran `room_state` di `room:<id>` tidak pernah memuat `mutes`, `muted_until`, atau `is_moderator`. Membisukan dan mencabut bisu juga tidak memicu siaran `room_state` sama sekali, jadi waktu siaran tidak bisa dipakai menebak.
- `get_stock_room_state` memuat `mutes` (`[{user_id, until}]` yang masih berlaku) **hanya** bila pemanggil moderator room itu (untuk menghindari bisu ganda). Anggota biasa tidak menerima kunci `mutes`; tiap anggota tetap menerima `muted_until` miliknya sendiri. Staf melihat daftar bisu di `cs_api.community_room_state`.
- Anggota yang dibisukan diberi tahu lewat notifikasi pribadinya: baris `public.notifications` jenis `moderation` (in-app tidak bisa dimatikan, push mengikuti preferensi) dengan payload `{target_type: "room", target_id, room_id, stock_code, state: "muted"|"unmuted", until, reason, appealable: false}`, tanpa `actor_id` dan tanpa identitas moderator. Dikirim saat dibisukan (`state: muted`) dan saat staf mencabut bisu lewat `community_undo_room_moderator_action` (`state: unmuted`, atau `muted` dengan `until` baru bila masih ada bisu lain yang berlaku). Bisu yang habis waktunya tidak dikirimi notifikasi: klien memakai `until`, dan server menolak kiriman berdasarkan waktu yang sama.
- Push: "Anda dibisukan moderator di $KODE" / "Anda bisa mengirim pesan lagi setelah DD/MM HH:MI WIB"; pencabutan: "Bisu Anda di $KODE dicabut". Ketukan membuka room.
- Cadangan: `403 room_muted` (`detail` = batas waktu ISO UTC) tetap dikembalikan saat mengirim.


### RPC staf (`cs_api`, izin `community.moderate`)

- `community_room_moderators(p_code)` → `{room_id, stock_code, moderators[], removed[] (20 terakhir), settings}`; tiap moderator memuat `problems` (alasan hak ditangguhkan), `actions_7d`, `undone_7d`.
- `community_room_moderator_candidates(p_code, p_query)` → pengguna dengan `eligible`, `problems`, `is_moderator`, `moderated_rooms`, `member`.
- `community_appoint_room_moderator(p_code, p_user_id, p_note = null)` (room dibuat bila belum ada, nasabah otomatis menjadi anggota; `400 not_eligible` dengan `detail` = daftar masalah, `409 already_moderator|room_moderator_limit|user_moderator_limit`) dan `community_remove_room_moderator(p_code, p_user_id, p_reason)` (alasan 5–500). Keduanya tercatat di `cs.cs_audit_log`.
- `community_room_moderator_actions(p_code = null, p_limit = 50, p_before = null, p_before_id = null)` → `{items}` log aksi (semua room bila `p_code` kosong) beserta cuplikan pesan, status laporan/banding, dan `can_undo`.
- `community_undo_room_moderator_action(p_id, p_note)`: memulihkan pesan tersembunyi (banding yang menunggu ikut diterima dan pengirim diberi tahu) atau mencabut bisu. Eskalasi diselesaikan dari antrean laporan (`400 undo_not_supported`). Tercatat `community.room_moderator_undo`.
- `community_room_moderator_settings()`; `community_set_room_moderator_settings(p_values)` khusus peran `compliance`/`cs_super_admin`.

### Klien Flutter (`rendezvous_community`)

Tanpa kode tambahan di aplikasi host: `CommunityChatRoom` membaca `StockRoomState.moderatorIds`, `viewerMutedUntil` (bisu milik sendiri, dari `muted_until`), dan `mutes` (hanya terisi untuk moderator; kosong untuk anggota biasa). Selama room saham terbuka, koneksi room mendengarkan notifikasi bisu milik pengguna (postgres_changes `notifications` dengan filter `user_id`, satu channel bersama untuk semua room) dan memancarkan `OwnRoomMuteChanged(mutedUntil)`; `ChatRoomCubit` langsung menerapkannya lalu memuat ulang `get_stock_room_state`. Siaran `room_state` tidak mengubah bisu milik sendiri maupun daftar bisu moderator; anggota yang baru ditunjuk moderator memuat ulang status untuk mendapat daftar bisu. Moderator melihat strip pemberitahuan dan aksi tekan-lama (sembunyikan, bisukan, eskalasi) di pesan anggota; pesan moderator berlencana; anggota yang dibisukan melihat banner dan tombol kirim nonaktif sampai waktunya habis. API: `ChatExtrasRepository.hideMessage/muteMember/escalateMessage`, `ChatRoomCubit.hideMessage/muteMember/escalateMessage`, dan `CommunityMessageDetails.senderIsModerator/onHide/onMuteSender/onEscalate` untuk builder kustom.

## Pengiriman pesan realtime (`0098`)

Pesan chat (room saham, DM, grup, dan chat CS) tidak lagi dikirim lewat `postgres_changes`. Database menyiarkannya sendiri lewat Broadcast (`realtime.send`) ke topik privat. Realtime hanya memeriksa izin sekali saat join, bukan RLS per pesan per penerima, sehingga beban DB tidak tumbuh dengan jumlah penerima. Tabel `messages` dikeluarkan dari publikasi `supabase_realtime`; `posts`, `comments`, `reactions`, dan `notifications` tetap di sana.

### Topik dan siapa boleh apa

| Topik | Terima (`SELECT`) | Kirim dari klien (`INSERT`) | Event dari server |
|---|---|---|---|
| `room:<room_id>` | anggota room (`chat_members`; nasabah diblokir hanya untuk room CS miliknya) | **presence saja**, dan tidak di room saham atau room non-CS ≥ 50 anggota (`0106`) | `message`, `message_hidden`, `typing`, `typing_summary`, `receipt`, `reaction`, `room_state` |
| `user:<user_id>` | hanya pemilik | tidak ada | `room_activity` |
| `cs:room:<room_id>` | nasabah pemilik dan staf yang boleh membaca room (`cs.can_read_room`) | tidak ada | `ticket`, `message` |
| `cs:queue`, `cs:agent:<id>` | staf (tidak berubah) | tidak ada | tidak berubah |
| `online` | semua user login yang tidak diblokir | presence saja | — |

Kebijakan `olt_realtime_send` kini hanya mengizinkan `extension = 'presence'`. Broadcast buatan klien, lewat WebSocket maupun `POST /realtime/v1/api/broadcast`, tidak pernah sampai ke anggota lain. Ini menutup temuan T2 ([laporan uji](../testing/report-2026-11-03.md)): anggota tidak bisa lagi memalsukan `message_hidden`, `room_state`, `reaction`, `receipt`, atau typing atas nama orang lain. Kunci presence tetap dipilih klien (Realtime tidak mengikatnya ke JWT). Dampaknya kecil: presence hanya dipakai untuk indikator online di DM, dan pemalsu di DM adalah lawan bicara itu sendiri.

### Isi event

- **`message`** (`room:<id>`), dikirim trigger `messages_60_broadcast` saat pesan baru, diubah, atau dihapus. Isinya bentuk `chat_message` yang sama dengan `get_messages`, tanpa kolom per penonton (`reactions`, `shared_post`, `moderation_status`): `id`, `room_id`, `sender_id`, profil pengirim, `body`, `is_deleted`, balasan, `attachments`, `client_id`, `edited_at`, `created_at`, `cursor`, `kind`, `payload`, `session_id`, `sender_role`.
  - Pesan terhapus dikirim tanpa `body`, `attachments`, dan `payload`.
  - Di room CS, profil pengirim tidak disertakan. Klien membaca pengirim dari anggota room, sehingga lencana resmi CS tetap benar.
  - Pesan `held`/`hidden` tidak pernah disiarkan. Pengirim sudah mendapat barisnya dari RPC kirim.
  - Bila pengirim terlibat blokir (dua arah) dengan anggota mana pun di room, yang disiarkan hanya referensi `{id, room_id, created_at, cursor, ref: true}`. Klien mengambil isinya lewat `get_messages(p_after)`, yang tetap menyaring blokir lewat RLS.
- **`message_hidden`** `{room_id, message_id, user_id}`: pesan berubah dari `visible` ke `held`/`hidden`, oleh siapa pun.
- **`typing`** `{user_id, username, display_name, typing}` hanya lewat RPC `send_typing(p_room_id, p_typing = true)` (nasabah) atau `cs_api.agent_typing(p_room_id, p_typing = true)` (CS, room CS). Identitas diambil dari JWT. Server meredam pengulangan: nilai sama dalam 3 detik dan mulai mengetik lagi dalam 1 detik tidak disiarkan (fungsi mengembalikan `false`). Typing CS memakai nama tampilan agen.
- **`room_activity`** (`user:<id>`) `{room_id, room_type, message_id, sender_id, created_at, preview}`: untuk DM, grup, dan room CS (hanya ke nasabah), satu per anggota yang tidak terlibat blokir dengan pengirim. Room saham sengaja tidak mengirim aktivitas per anggota. Daftar chat dan penanda terkirim memakai event ini.
- **`message`** (`cs:room:<id>`) `{id, room_id, ticket_id, client_id}`: sinyal untuk web CS. Isi pesan diambil lewat `cs_api.get_messages(p_after)`.

### Mengisi celah

Event yang dibuang Realtime (batas tenant, putus sambungan, slot replikasi dibuat ulang setelah Realtime restart) tidak memberi sinyal ke klien. Karena itu klien menambal dari **horizon**, bukan dari pesan terbaru yang terlihat (`0103`, temuan T18/T19 [laporan uji](../testing/report-2026-11-03.md)):

- **Horizon** per room = `(created_at, id)` terbaru yang sudah dikonfirmasi dari server: halaman pertama saat room dibuka, muat ulang, atau gap-fill sebelumnya yang selesai. Pesan yang hanya datang lewat Realtime tidak memajukan horizon, jadi lubang di tengah aliran tetap tertambal walau pesan sesudahnya sudah sampai.
- Setiap gap-fill membaca maju dari `horizon − 10 detik` (id nol), paling banyak 5 halaman, lalu memajukan horizon ke baris terbaru yang dibaca. Overlap 10 detik menutup pesan yang commit belakangan dengan `created_at` lebih awal (misalnya `send_message` yang menunggu kunci baris).
- **Aplikasi (room saham, DM, grup):** `get_message_ids(p_room_id, p_after, p_limit)` mengembalikan `{ids, last, more}` saja (≤ 1.000 id per halaman, urut maju, RLS berlaku). Klien membandingkan dengan pesan yang sudah dimilikinya dan hanya mengambil yang belum ada lewat `get_messages_by_ids(p_room_id, p_ids)` (≤ 100 id per panggilan). Di room ramai biaya gap-fill tetap kecil walau jendelanya 45 detik.
- **Chat CS (aplikasi dan web CS):** `get_messages(p_after)` / `cs_api.get_messages(p_after)` per 100 baris. Web CS tidak memakai isi pesan dari Realtime (hanya sinyal), jadi horizonnya selalu baris terbaru yang diambil dari server.
- Lebih dari 5 halaman: room dimuat ulang dari pesan terbaru; pesan lama tetap bisa dimuat dengan scroll.

Kapan gap-fill berjalan:

- channel room tersambung **pertama kali**: langsung;
- channel tersambung **ulang**: setelah jeda acak 0–5 detik (agar ratusan klien yang sambung ulang serentak setelah Realtime restart tidak memanggil RPC bersamaan), lalu **sekali lagi** 5–10 detik kemudian untuk pesan yang commit saat slot replikasi Realtime dibuat ulang;
- berkala selama room terbuka: 45 detik ± 25% (acak per putaran, web CS hanya saat tab terlihat);
- saat aplikasi kembali ke depan (Flutter `AppLifecycleListener.onResume`, web `visibilitychange`/`focus`): langsung, karena dipicu pengguna dan tidak serentak.

Duplikat digabung lewat `id` dan `client_id`.

### Typing dan presence di room besar (`0106`)

Satu event di `room:<id>` dihitung sekali per subscriber, jadi biayanya ≈ jumlah anggota yang online. Di room saham ramai, typing per orang (±2 siaran per pesan: mulai dan berhenti) lebih mahal dari pesannya sendiri. Contoh: 500 penerima × 25 pesan/dtk menghasilkan ±25.000 event typing/dtk di atas 12.500 event pesan/dtk, padahal batas tenant 10.000. Presence menambah `presence_diff` ke semua anggota setiap kali ada yang join, keluar, atau sambung ulang.

Aturan server (tidak bergantung klien, jadi klien lama tidak bisa membanjiri):

| Setting (`private.settings`) | Bawaan | Arti |
|---|---|---|
| `rooms.typing_aggregate_members` | 50 | Room non-CS dengan anggota sebanyak ini atau lebih memakai ringkasan typing |
| `rooms.typing_summary_seconds` | 3 | Paling sering satu ringkasan per room per interval ini |
| `rooms.typing_off_members` | 2000 | Mulai jumlah anggota ini typing tidak disiarkan sama sekali |
| `rooms.presence_max_members` | 50 | `track` presence ditolak di DM dan grup dengan anggota sebanyak ini atau lebih |
| `rooms.presence_stock_members` | 0 | `track` presence ditolak di room saham dengan anggota sebanyak ini atau lebih (0 = selalu; nilai besar memulihkan perilaku lama untuk uji A/B) |

- **Typing:** `send_typing` di room besar tidak menyiarkan `typing` bernama.
  - Server mencatat user di `private.typing_throttle` (throttle per user tetap berlaku).
  - Paling sering sekali per interval per room, server mengirim **`typing_summary`** `{room_id, count, ttl_ms}`: jumlah yang mengetik dalam 2 × interval, maksimal 99, tanpa identitas.
  - Pengirim ringkasan dipilih lewat `FOR UPDATE SKIP LOCKED` di tabel unlogged `private.typing_rooms`. Tidak ada yang menunggu kunci, jadi tidak ada konvoi seperti T17.
  - Berhenti mengetik (`p_typing = false`) tidak disiarkan; ringkasan kedaluwarsa sendiri setelah `ttl_ms`.
  - User yang dibanned atau dibisukan di room tidak dihitung.
  - Room CS selalu memakai jalur lama (juga `cs_api.agent_typing`).
- **Ukuran room** dihitung dari `chat_members` dengan batas (`private.room_has_members`: paling banyak n baris index). Jumlah subscriber Realtime tidak terlihat dari Postgres, jadi jumlah anggota dipakai sebagai proksi konservatif.
- **Presence:** `olt_realtime_send` (dari `0105`) mendapat syarat tambahan `private.can_track_presence(topic)`.
  - Policy baca tidak berubah: join dan penerimaan broadcast tetap sama.
  - Realtime menjawab `track` yang ditolak dengan reply `error`, dan channel tetap tersambung (sudah diuji ke Realtime v2.143.3 dan v2.148.6).
  - Klien 1.5.0 yang tetap `track` di room saham tidak terganggu.
  - Aplikasi 1.6.0 hanya memakai presence di DM. Web CS tetap memakai presence di room CS.
- **Biaya di room 500 penerima:** typing ±25.000 → ±167 event/dtk; presence room saham → 0.

### Pratinjau room saham di daftar chat (`0107`)

Room saham tidak mengirim `room_activity` per anggota (terlalu mahal). Daftar chat aplikasi karena itu memoll RPC ringan selama daftar terlihat:

- `get_room_previews(p_room_ids uuid[])` (≤ 50 id, read-only, tanpa kunci baris):
  - mengembalikan `{poll_seconds, rooms: [{room_id, last_message_at, last_message_preview, last_message_sender_id, unread_count, cursor}]}`;
  - hanya untuk room saham yang diikuti pemanggil; id lain diabaikan;
  - `unread_count` dan `cursor` sama dengan `get_my_rooms`, tetapi tanpa hitungan anggota.
- `rooms.preview_poll_seconds` (bawaan 15) dikirim di respons. Klien menjepitnya ke 5 dtk–5 mnt dan mengacaknya × 0,75–1,25 per putaran. Interval bisa diperlambat dari server saat beban tinggi tanpa rilis aplikasi.
- **Biaya:** 500 nasabah melihat daftar ≈ 33 req/dtk yang read-only, tanpa event Realtime dan tanpa jalur tulis baru.
  - Alternatif yang ditolak: subscribe `room:<id>` dari daftar (25 × L event/dtk) dan ringkasan ke `user:<id>` tiap anggota (tulis naik sesuai keanggotaan).

### Batas tenant

Event yang diterima setiap klien dihitung ke `REALTIME_MAX_EVENTS_PER_SECOND`, yang bawaannya sekarang 10.000. Lihat [PRODUCTION.md](../PRODUCTION.md#batas-realtime).
