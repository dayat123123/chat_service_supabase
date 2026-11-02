# Push notification ke HP

Semua notifikasi aplikasi nasabah bisa dikirim sebagai push ke layar HP lewat Firebase Cloud Messaging (FCM). Ini mencakup balasan, mention, like, follow, chat, balasan CS, pengumuman, dan push uji. Push dikirim oleh layanan **notifier** (`services/notifier`). Migrasi: `0058_push_notifications`.

```
public.notifications ──trigger──▶ private.push_queue ──push_claim──▶ notifier ──HTTP v1──▶ FCM ──▶ HP
  (fitur apa pun)                  (1 baris per perangkat)            (Go, N replika)
```

- Fitur yang membuat baris `public.notifications` otomatis ikut dikirim sebagai push. Jadi fitur notifikasi baru tidak perlu kode push tambahan.
- Notifier hanya mengirim isi antrean dan tidak tahu jenis notifikasi. Push jenis baru cukup masuk antrean (lihat [Menambah jenis push](#menambah-jenis-push)).
- Tanpa file Firebase, semua tetap berjalan. Notifikasi masuk ke kotak notifikasi aplikasi, notifier berstatus **Belum dipasang**, dan antrean yang belum terkirim kedaluwarsa sendiri.

## Memasang Firebase (operasional)

Yang dibutuhkan hanya satu file JSON *service account* dari project Firebase yang sama dengan aplikasi OLT (`google-services.json` / `GoogleService-Info.plist`).

1. Di Firebase Console, buka **Project settings → Service accounts**, lalu klik **Generate new private key**.
2. Simpan file itu di server, di `docker/secrets/firebase/` (nama file bebas, akhiran `.json`, cukup satu file). Pastikan file bisa dibaca container:
   ```bash
   chmod 755 docker/secrets/firebase && chmod 644 docker/secrets/firebase/*.json
   ```
3. Tunggu sekitar 30 detik. Notifier membaca file itu otomatis tanpa restart. Status di web CS (**Pengaturan → Push notification**) berubah menjadi **Aktif** dan menampilkan id project Firebase.
4. Dari halaman yang sama, kirim **push uji** ke akun Anda sendiri, cari dengan username. Akun itu harus sudah membuka aplikasi OLT yang mendaftarkan token (lihat bagian berikut).

Untuk iOS, unggah juga **APNs Authentication Key** di Firebase Console (**Project settings → Cloud Messaging → Apple app configuration**). Tanpa kunci itu, push iOS gagal dan status menjadi **Bermasalah**: "Firebase ditolak APNs/Web Push".

File itu berisi kunci privat. Jangan kirim lewat chat atau email, dan jangan commit (`docker/secrets/` sudah di-gitignore). Rotasi kunci:
1. Buat kunci baru dan ganti file lama.
2. Tunggu status kembali Aktif.
3. Hapus kunci lama di Google Cloud Console (**IAM → Service accounts → Keys**).

**Profil cluster (Swarm).** Folder bind tidak tersedia di setiap node, jadi kredensial memakai Docker secret `docker/secrets/firebase_service_account`. File kosong berarti push belum dipasang. Isi file itu dengan JSON yang sama, lalu deploy ulang stack.

### Status di web CS

| Status | Arti | Tindakan |
|---|---|---|
| Aktif | Notifier hidup dan kredensial diterima | – |
| Belum dipasang | Notifier hidup, file kredensial belum ada atau kosong | Pasang file (langkah di atas) |
| Bermasalah | File ada tetapi tidak valid, ditolak Google/Firebase, atau APNs ditolak | Baca pesan error di halaman; biasanya kunci dicabut, project salah, atau API FCM belum aktif |
| Layanan mati | Tidak ada heartbeat notifier dalam 90 detik | `make up` / periksa `docker compose logs notifier` |

Halaman yang sama juga menampilkan:
- jumlah perangkat per platform;
- jumlah terkirim dan gagal dalam 24 jam, termasuk token mati dan push kedaluwarsa;
- antrean dan umur push tertua;
- kegagalan terakhir.

Status ringkas juga tampil di tab **Komunitas → Notifikasi**, dan setiap kampanye menampilkan jumlah push terkirim, menunggu, dan gagal.

## Aplikasi OLT (pengembang)

Paket `rendezvous_community` **tidak** bergantung pada Firebase. Aplikasi OLT yang memasang `firebase_messaging`, lalu menyerahkan token dan data push ke paket:

```dart
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();

Future<void> registerPush(String token) => RendezvousCommunity.instance.registerPushToken(
  token,
  platform: Platform.isIOS ? CommunityPushPlatform.ios : CommunityPushPlatform.android,
  locale: Localizations.localeOf(context).languageCode,
  appVersion: packageInfo.version,
);

final token = await messaging.getToken();
if (token != null) await registerPush(token);
messaging.onTokenRefresh.listen(registerPush);

FirebaseMessaging.onMessageOpenedApp.listen((message) {
  openCommunityPush(navigatorKey.currentContext!, message.data);
});
final initial = await messaging.getInitialMessage();
if (initial != null) openCommunityPush(navigatorKey.currentContext!, initial.data);
```

- **Panggil `registerPushToken` sekali setelah `initialize`, dan setiap token berganti.** Token terikat ke akun yang sedang login. Bila akun berganti di perangkat yang sama, paket mendaftarkan ulang token ke akun baru secara otomatis.
- **`signOut()` melepas token dari akun** supaya push akun lama tidak muncul di perangkat itu. Pemanggilan ini tidak menghapus izin push.
- **`unregisterPushToken()`** dipakai bila pengguna mematikan push di pengaturan aplikasi OLT.
- **`openCommunityPush(context, data)`** membuka postingan, chat, chat CS, profil pengikut, atau tautan pengumuman, dan menandai notifikasinya terbaca. Nilainya `false` bila push bukan milik paket komunitas (`data['source'] != 'rendezvous_community'`), misalnya push order milik OLT sendiri. Push seperti itu ditangani aplikasi OLT.
- **Saat aplikasi di depan layar**, Android tidak menampilkan push otomatis. Badge dan daftar notifikasi di dalam aplikasi sudah diperbarui lewat realtime, jadi menampilkan notifikasi lokal saat itu opsional.
- **Android** memakai channel default FCM. Bila OLT punya channel sendiri, isi `NOTIFIER_ANDROID_CHANNEL_ID` di `docker/.env`.
- Untuk web, tambahkan `firebase-messaging-sw.js` sesuai dokumentasi FlutterFire, lalu pakai `CommunityPushPlatform.web`.

### Isi push

Teks dibuat di server dalam bahasa perangkat (`locale` `id` atau `en`) dan mengikuti teks kotak notifikasi aplikasi:

| Jenis | Judul | Isi | Prioritas | Digabung per |
|---|---|---|---|---|
| reply | "Budi membalas Anda" / "Budi dan 2 lainnya membalas postingan Anda" | cuplikan komentar | tinggi | postingan |
| mention | "Budi menyebut Anda" | cuplikan | tinggi | postingan |
| like | "Budi menyukai konten Anda" (hanya like pertama sampai dibaca) | cuplikan | normal | konten |
| follow | "Budi mulai mengikuti Anda" | – | normal | pengikut |
| message | nama pengirim / nama grup / nama CS | cuplikan pesan | tinggi | room |
| announcement | judul kampanye | isi kampanye | tinggi | – |
| test | "Tes push notification" | – | tinggi | – |

Data push (semua nilai string) memuat:
- `source=rendezvous_community`, `type`, `notification_id`, dan `push_id`;
- semua id dari payload notifikasi (`post_id`, `comment_id`, `room_id`, `room_type`, `ticket_id`, `campaign_id`, `url`);
- `actor_id` dan `actor_username`.

Kunci gabung (`collapse_key`) dipakai sebagai tag Android dan `apns-collapse-id`, jadi push lanjutan menggantikan push sebelumnya untuk percakapan yang sama. Badge iOS diisi jumlah notifikasi yang belum dibaca.

## Menambah jenis push

Cara paling sederhana: buat baris `public.notifications` dengan `type` baru (tambahkan ke constraint `notifications_type`). Push dan kotak notifikasi langsung jalan. Atur judulnya di `private.notification_push` bila teks bawaan ("Notifikasi baru" + `payload.title/body`) kurang cocok.

Untuk push tanpa entri di kotak notifikasi, panggil langsung dari SQL (fungsi `security definer` milik fitur):

```sql
select private.push_enqueue(
  p_user_id => '…',
  p_kind    => 'price_alert',
  p_title   => '{"id": "BBCA naik 5%", "en": "BBCA up 5%"}',
  p_body    => '"Harga menyentuh 10.500"',
  p_data    => '{"source": "rendezvous_community", "stock_code": "BBCA"}',
  p_options => '{"collapse_key": "price:BBCA", "priority": "high", "ttl_seconds": 3600, "ref": "price_alert", "badge": false}'
);
```

`p_title` dan `p_body` boleh berupa string atau objek per bahasa. Opsi:

| Opsi | Default | Keterangan |
|---|---|---|
| `collapse_key` | – | Push dengan kunci sama saling menggantikan di HP |
| `priority` | `high` | `normal` untuk yang tidak mendesak |
| `ttl_seconds` | `push.ttl_hours` | Batas umur push di antrean dan di FCM |
| `ref` | – | Kunci statistik (`private.push_ref_stats`), misalnya `campaign:<id>` |
| `badge` | `true` | Isi badge iOS dengan jumlah notifikasi belum dibaca |

Fungsi ini mengembalikan jumlah perangkat yang masuk antrean (0 bila pengguna belum punya perangkat).

## Keandalan

- **Antrean per perangkat** (`private.push_queue`). `push_claim` memakai `FOR UPDATE SKIP LOCKED` dengan lease, jadi notifier aman dijalankan beberapa replika. Bila notifier mati di tengah jalan, push diambil ulang setelah lease habis. Pengiriman bersifat *at-least-once*.
- **Retry dengan backoff** (30 detik, digandakan sampai 30 menit, ditambah jitter, atau mengikuti `Retry-After` FCM). Setelah `push.max_attempts` percobaan, push ditandai gagal. Gangguan layanan, seperti kredensial ditolak atau Google tidak bisa dihubungi, tidak menghabiskan jatah percobaan: notifier berhenti sebentar dan antrean menunggu.
- **Token mati** (`UNREGISTERED`, `SENDER_ID_MISMATCH`, token tidak valid) langsung menghapus perangkat dan menghentikan push lain ke token itu.
- **Kedaluwarsa**: push yang belum terkirim setelah `push.ttl_hours` ditutup oleh job `push-maintenance` (pg_cron, tiap menit). Job yang sama menghapus riwayat lebih tua dari `push.retention_days` dan perangkat yang tidak membuka aplikasi selama `push.device_stale_days`.

| Pengaturan (`private.settings`) | Default |
|---|---|
| `push.ttl_hours` | 24 |
| `push.max_attempts` | 6 |
| `push.retention_days` | 7 |
| `push.device_stale_days` | 270 |
| `push.max_devices_per_user` | 10 |

## Privasi & keamanan

- Token perangkat ada di `private.push_devices`. Tabel ini tidak bisa dibaca aplikasi, dan notifier tidak pernah mencatat token lengkap.
- Hapus akun (`deleted_at`) langsung menghapus perangkat dan antrean push pengguna itu.
- Perangkat yang berganti akun membatalkan push milik akun lama yang belum terkirim.
- RPC notifier (`push_claim`, `push_report`, `push_heartbeat`) hanya untuk `service_role`. Notifier tidak terekspos ke internet; satu-satunya egress-nya adalah Google (OAuth + FCM).
- Push uji dari web CS hanya untuk Super Admin dan tercatat di **Kepatuhan → Jejak Audit** (`push.test`).

## Monitoring

- Web CS: **Pengaturan → Push notification**.
- Notifier `GET /metrics` (port 8080, hanya di jaringan internal):
  - `notifier_push_total{outcome}`;
  - `notifier_queue_depth`;
  - `notifier_configured`;
  - `notifier_healthy`.
- Log: `docker compose logs notifier`.

Konfigurasi notifier ada di [services/notifier/README.md](../../services/notifier/README.md).
