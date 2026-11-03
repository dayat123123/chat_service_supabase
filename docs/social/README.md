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
- Error: `404 post_not_found` / `comment_not_found`, `403 forbidden`, `403 edit_window_expired`, `409 poll_not_editable`, `400 empty_body`, `400 body_too_long`, `422 content_blocked` (dll. dari kebijakan konten), `503 social_disabled`, `429 rate_limited` (`content_edit` 20/menit).

### Bookmark

- `toggle_bookmark(p_post_id, p_bookmarked = null)` → `boolean` (status baru). `null` = toggle, `true/false` = set idempoten. Postingan harus terlihat (`404 post_not_found`). Batas `bookmark` 120/menit.
- `get_bookmarks(p_cursor = null, p_limit = 20)` → `setof feed_post`, terbaru disimpan dulu; `cursor` di baris memakai waktu bookmark. Postingan yang dihapus/tidak terlihat lagi tidak ditampilkan.
- Tabel `public.bookmarks` hanya bisa dibaca pemiliknya; tulis hanya lewat RPC.

### Reaksi pesan chat

- Emoji tetap: 👍 ❤️ 😂 😮 😢 🔥 (`❤` tanpa variation selector dinormalkan). Satu reaksi per orang per pesan.
- `react_to_message(p_message_id, p_emoji = null)` → `{"message_id", "emoji" (null = dilepas), "reactions": [{emoji, count, me}]}`. Emoji sama dengan yang aktif = lepas; emoji lain = ganti; `null` = lepas.
- Disiarkan seperti tanda baca: `realtime.send` event **`reaction`** ke channel privat `room:<room_id>` dengan payload `{message_id, user_id, emoji, reactions: [{emoji, count}]}` (tanpa `me`; klien menghitung sendiri dari `user_id`).
- Tidak tersedia di chat CS (`400 reactions_not_supported`). Error lain: `400 invalid_emoji`, `404 message_not_found` (bukan anggota, pesan dihapus/tidak terlihat, atau saling blokir), `429 rate_limited` (`message_reaction` 60/menit).

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

## Preferensi notifikasi (`0076`)

- Jenis: `reply`, `mention`, `like`, `follow`, `message`, `announcement`, `appeal` (keputusan banding, sejak `0083`), lalu lima jenis OLT (sejak `0086`): `olt.trade`, `olt.funds`, `olt.market`, `olt.info`, `olt.promo`. Masing-masing `in_app` dan `push` (bawaan **aktif**, kecuali push `olt.promo` yang **mati** sampai pengguna mengaktifkannya; pengguna tanpa pengaturan berperilaku persis seperti sebelumnya).
- Pemetaan `kind` OLT (`private.notification_pref_type(kind, category)`): `olt.trade*`/`olt.order*` → `olt.trade` (Transaksi); `olt.deposit*`/`olt.withdrawal*`/`olt.rdn*` → `olt.funds` (Dana); `olt.price_alert*`/`olt.ipo*`/`olt.corporate_action*` → `olt.market` (Pasar); `olt.*` lain → `olt.info` (Info); pesan ber-`category` `promo` apa pun jenisnya → `olt.promo` (Promo). Kategori `important` **menembus** preferensi per jenis (in-app dan push) dan jam tenang; tetap hanya ke perangkat yang terdaftar.
- Sebelum `0086` semua `olt.*` memakai satu preferensi `olt.trade` (push saja). Migrasi `0086` menyalin `olt.trade` yang push-nya dimatikan ke `olt.funds`, `olt.market`, dan `olt.info` supaya pengguna yang sudah mematikan push OLT tetap tidak menerimanya. `olt.trade` kini juga punya `in_app` (pesan OLT bisa masuk kotak notifikasi sebagai `announcement` dengan `payload.source = 'olt'`).
- `in_app = false`: notifikasi tidak masuk kotak notifikasi; bila `push = true`, push tetap dikirim. `push = false`: push tidak diantrekan.
- **Chat CS dikecualikan**: notifikasi `message` dari room `support` selalu masuk dan selalu di-push (layanan nasabah, bukan sosial). Push uji Super Admin (`kind = 'test'`) tidak terkena preferensi maupun jam tenang.
- **Jam tenang** (WIB, bawaan mati): push yang dibuat di dalam jam tenang **ditunda** sampai jam tenang selesai (`available_at`), masa berlaku ikut digeser. Push tertunda dengan `collapse_key` sama hanya menyisakan yang terbaru. Notifikasi in-app tetap masuk seketika. Mendukung lintas tengah malam (22:00–06:00).
- Ditegakkan di trigger `push_queue_40_preferences` (BEFORE INSERT `private.push_queue`) dan `notifications_40_preferences`, jadi berlaku untuk semua jalur push (notifikasi, kampanye, API integrasi OLT) tanpa mengubah `push_enqueue`.
- `private.push_allowed(p_profile, p_kind) → boolean` (definer, untuk layanan internal seperti `integration_notify`): `false` hanya bila pengguna mematikan push jenis itu. `private.push_allowed_for(p_profile, p_kind, p_category)` (sejak `0086`) menambahkan kategori OLT: `important` selalu `true`, `promo` memakai `olt.promo`, selain itu sama dengan `push_allowed`. Trigger `push_queue_40_preferences` membaca kategori dari `data.category` baris push `olt.*`, trigger `notifications_40_preferences` dari `payload.kind`/`payload.category` notifikasi OLT, jadi keduanya memakai pemetaan yang sama.
- **Penggabungan like/follow**: like ke konten yang sama, atau follow dari siapa pun, dalam `notifications.aggregate_minutes` (60) menit sejak notifikasi pertama digabung ke satu baris belum dibaca (`event_count` +1, `actor_id` = pelaku terbaru, naik ke atas). Push hanya untuk yang pertama; push memakai `collapse_key` = `group_key`. Setelah lewat jendela atau setelah dibaca, notifikasi baru dibuat.

### RPC

- `get_notification_prefs()` → `{"types": [{type, in_app, push}], "quiet_hours": {enabled, start "HH:MM", end, timezone "Asia/Jakarta"}, "aggregate_minutes": 60}`.
- `set_notification_prefs(p_prefs jsonb)` → bentuk yang sama. Parsial: `{"types": {"like": {"push": false}}, "quiet_hours": {"enabled": true, "start": "22:00", "end": "06:00"}}` (atau `types` berupa array `[{type, in_app?, push?}]`). Error: `400 invalid_preferences`, `400 invalid_notification_type`, `400 invalid_quiet_hours`, `429 rate_limited` (`notification_prefs` 30/menit).
- `get_notifications(p_cursor, p_limit)` bertambah `actor_count integer` dan `actors jsonb` (≤ 3 pelaku terbaru `{id, username, display_name, avatar_url}`). Contoh teks: "Budi dan {actor_count−1} lainnya menyukai postingan Anda". Notifikasi lama (sebelum 0076) memiliki `actor_count` 1.

## Feature flag, kill switch, versi minimum (`0077`)

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
- **Kill switch** (`social_enabled = false`): klien menyembunyikan UI sosial. Server menolak postingan, komentar, edit, dan pesan chat **non-CS** baru dari pengguna aplikasi dengan `503 social_disabled`. Chat CS tetap berjalan. Membaca, like, follow, reaksi tetap jalan. Postingan staf/akun resmi/bot (bukan pengguna aplikasi) tidak diblokir.

### RPC Super Admin (`cs_api`, peran `cs_super_admin`, semua tercatat di audit)

- `admin_feature_flags()` → `{kill_switch: {social_enabled, reason, changed_by, changed_at}, flags: [...], min_versions: [...]}`.
- `admin_set_feature_flag(p_key, p_enabled, p_percentage = 100, p_user_ids = '{}', p_platforms = '{}', p_min_app_version = null, p_description = null)` — buat/ubah; audit `feature_flag.set` (before/after). Error `400 use_kill_switch` (kunci `social.enabled`), `invalid_flag_key`, `invalid_percentage`, `invalid_platform`, `too_many_users` (> 1000), `invalid_version`.
- `admin_delete_feature_flag(p_key)` — audit `feature_flag.delete`; `404 flag_not_found`.
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

`export_my_data()` kini juga memuat `bookmarks`, `message_reactions`, `notification_preferences`, `dm_policy` (sejak `0083`), `linked_accounts` (rekening OLT tertaut dari agen P, bila fungsi `private.account_links_export` ada), `appeals` (banding dari agen S, dibaca dari `public.appeals` bila tabel ada; kolom pemilik `user_id`/`appellant_id`/`created_by`), dan `analytics_events` (5000 terakhir).

## Hapus akun

Trigger `profiles_40_social_forget` (saat `profiles.deleted_at` terisi) menghapus bookmark, reaksi pesan, preferensi & jam tenang, jejak pelaku notifikasi (`private.notification_actors`), dan event analitik pengguna. Riwayat edit (`private.content_edits`) tetap disimpan sebagai arsip regulator, sama seperti `private.content_archive`.

## Catatan untuk pengembang klien

1. Panggil `get_client_config(platform, versi)` saat start dan saat kembali ke foreground; hormati `update_required`, `social_enabled`, dan `flags`. Tangani `503 social_disabled` dari tulis konten dengan pesan "sementara tidak tersedia", bukan error umum.
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
