# Modul 6: Realtime

**Tujuan:** mengerti bagaimana pesan yang disimpan di database bisa muncul di HP orang lain dalam hitungan milidetik, dan kenapa tidak ada pesan yang hilang walaupun sinyal putus.

---

## 6.1 Masalahnya: server tidak bisa memanggil HP

HTTP berjalan satu arah: klien bertanya, server menjawab. Server tidak bisa memulai pembicaraan ke HP, karena HP berada di balik NAT operator atau WiFi dan tidak punya alamat yang bisa dihubungi.

Ada tiga cara supaya klien tahu ada data baru:

| Cara | Kerja | Kekurangan |
|---|---|---|
| **Polling** | Klien bertanya tiap N detik | Boros dan lambat. Tetap kita pakai untuk preview room saham (`get_room_previews`, 15 detik) |
| **WebSocket** | Klien membuka satu koneksi yang **tetap terbuka**, lalu server bisa mengirim kapan saja | Koneksi putus saat app ditutup |
| **Push (FCM/APNs)** | Google/Apple menjaga satu koneksi per HP untuk semua app | Hanya untuk notifikasi, bukan aliran data (modul 7) |

## 6.2 WebSocket dan Phoenix

WebSocket dimulai sebagai request HTTP biasa yang lalu di-*upgrade* menjadi saluran dua arah:

```
GET /realtime/v1/websocket?apikey=…&vsn=1.0.0
Upgrade: websocket
→ 101 Switching Protocols
```

Supabase Realtime ditulis dalam Elixir dan memakai protokol **Phoenix Channels** di atas WebSocket. Setiap pesan berbentuk:

```json
{"topic": "realtime:room:a3e0…", "event": "phx_join", "payload": {…}, "ref": "1", "join_ref": "1"}
```

| Konsep | Arti |
|---|---|
| **Topic** | Nama saluran: `room:<id>`, `user:<id>`, `cs:room:<id>` |
| **Join** | Mulai berlangganan topik (`phx_join`) |
| **Event** | Jenis pesan: `message`, `typing`, `receipt`, … |
| **ref / join_ref** | Nomor untuk mencocokkan balasan dengan permintaan. Pesan dengan `join_ref` yang salah diabaikan |
| **Heartbeat** | Pesan kecil tiap ±25 detik ke topik `phoenix` supaya koneksi tidak dianggap mati |

Kontrak lengkapnya ada di [docs/api/asyncapi.yaml](../api/asyncapi.yaml).

## 6.3 Tiga fitur Realtime, dan yang kita pakai

| Fitur | Cara kerja | Dipakai? |
|---|---|---|
| **Postgres Changes** | Realtime membaca WAL, lalu mengirim setiap insert/update tabel ke pelanggan, dicek RLS **per pelanggan per baris** | **Tidak lagi** untuk chat. Uji beban T1 menunjukkan event terbuang di atas ±1.000/detik |
| **Broadcast** | Pesan bebas ke semua pelanggan topik | **Ya**, tapi dikirim dari **database**, bukan dari klien |
| **Presence** | Daftar siapa yang sedang online di topik | Hanya di DM |

### Broadcast dari database

Sejak 0098, semua event chat dikirim oleh trigger memakai `realtime.send()`:

```sql
perform realtime.send(
  jsonb_build_object('id', new.id, 'room_id', new.room_id, …),   -- payload
  'message',                                                      -- event
  'room:' || new.room_id::text,                                   -- topic
  true);                                                          -- private
```

Di balik layar, `realtime.send` menulis satu baris ke tabel `realtime.messages`. Realtime membaca tabel itu lewat replikasi logis (WAL), lalu mendorongnya ke semua pelanggan topik tersebut.

```sql
select topic, event, private, left(payload::text, 80) as payload, inserted_at
from realtime.messages
order by inserted_at desc
limit 10;
```

Karena event ditulis di dalam **transaksi yang sama** dengan pesannya, event hanya terkirim bila pesan benar-benar tersimpan. Kalau `send_message` gagal dan di-rollback, event-nya ikut batal.

### Kenapa klien tidak boleh broadcast sendiri

Dulu anggota room bisa mengirim broadcast langsung ke `room:<id>`, sehingga pesan palsu bisa muncul di layar anggota lain tanpa pernah tersimpan atau diperiksa (temuan T2). Sekarang policy `olt_realtime_send` di `realtime.messages` tidak mengizinkan klien menulis ke topik chat. Satu-satunya jalan adalah RPC, yang melewati semua pemeriksaan.

## 6.4 Siapa boleh join topik

Saat aplikasi mengirim `phx_join` dengan `config.private = true` dan `access_token`, Realtime menjalankan policy `olt_realtime_receive` di `realtime.messages` dengan JWT pengguna itu. Policy tersebut memanggil:

```sql
\sf private.can_access_topic
```

Ringkasnya:
- `user:<uuid>` → hanya bila uuid itu adalah `auth.uid()`;
- `room:<uuid>` → hanya anggota room (dan bukan pengguna yang di-ban, kecuali di chat CS);
- `cs:…` → diperiksa `cs.can_access_topic` (agen atau pemilik tiket);
- lainnya → ditolak.

### Latihan: uji akses topik

```sql
begin;
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.profiles where username = 'budi_santoso'))::text, true);

select r.type, r.id,
       private.can_access_topic('room:' || r.id) as boleh
from public.chat_rooms r
order by r.type
limit 12;

select private.can_access_topic('user:' || auth.uid()) as kanal_saya,
       private.can_access_topic('user:' || (select id from public.profiles where username = 'sari_invest')) as kanal_sari;
rollback;
```

## 6.5 Event yang dikirim

| Topik | Event | Pemicu (cari dengan `\sf`) |
|---|---|---|
| `room:` | `message` | `private.broadcast_message` (trigger `messages_60_broadcast`) |
| `room:` | `message_edited` | `private.message_edit_preview` |
| `room:` | `message_hidden` | `private.broadcast_message` saat moderasi |
| `room:` | `reaction` | `private.broadcast_message_reaction` |
| `room:` | `receipt` | `private.broadcast_receipt` |
| `room:` | `typing` / `typing_summary` | `private.room_typing` / `private.room_typing_summary` |
| `room:` | `room_state` | `private.broadcast_room_state` (room saham) |
| `user:` | `room_activity` | `private.broadcast_room_activity` |
| `user:` | `room_removed` | `hide_room`, `leave_room`, `delete_group` |

### Detail yang menarik

- **Blokir:** bila pengirim dan sebagian anggota saling blokir, isi pesan tidak disiarkan. Yang dikirim hanya `{"id", "room_id", "ref": true}`, lalu klien mengambil isinya lewat `get_messages_by_ids`, dan RLS menyaring siapa yang boleh melihat. Satu siaran tidak bisa dibedakan per penerima, jadi penyaringan diserahkan ke RLS.
- **Typing di room besar:** di room ≥ 50 anggota, event `typing` per orang diganti `typing_summary` ("12 orang mengetik") paling sering tiap 3 detik. Di room ≥ 2.000 anggota tidak dikirim sama sekali (0106). Tanpa ini, satu orang mengetik di room 1.000 anggota menghasilkan 1.000 pesan per ketikan.
- **`room_activity` per pengguna:** event ini ditulis langsung ke `realtime.messages` untuk setiap anggota DM/grup (topik `user:<id>`), supaya daftar chat di layar lain ikut naik. Room saham tidak mengirimnya karena terlalu banyak anggota.

## 6.6 Tidak ada pesan yang hilang: gap-fill

Realtime **tidak menyimpan** event untuk klien yang sedang terputus. Jadi aturannya: **database adalah sumber kebenaran, WebSocket hanyalah bel**.

```
Koneksi putus (lift, ganti jaringan) ──► status "menyambung ulang…"
Tersambung lagi ──► join ulang topik
                └─► get_message_ids(room, cursor pesan terakhir yang saya punya)
                        → ["id1", "id2", …], more
                └─► get_messages_by_ids(room, id yang belum saya punya)
                └─► gabungkan, urutkan, buang duplikat (pakai id)
```

Library juga mengulang pengecekan sedikit ke belakang (sekitar 10 detik, 0103), karena event yang terjadi tepat saat koneksi tersambung bisa terlewat.

## 6.7 Melihat frame WebSocket langsung

1. Jalankan app contoh library versi web (`make web-example`, butuh Flutter SDK), buka <http://localhost:8086>, lalu login. Buka juga <http://localhost:8086/?user=sari_invest> di tab lain sebagai lawan bicara.
2. Buka DevTools (F12) → **Network** → filter **WS** → klik koneksi `websocket`.
3. Tab **Messages**: lihat `phx_join`, `phx_reply`, `heartbeat`, lalu kirim pesan dari akun lain dan lihat frame `broadcast` / `message` masuk.

---

## Latihan

1. Jalankan 6.4 untuk `sari_invest`. Room mana yang boleh di-join Sari tapi tidak boleh oleh Budi?
2. Kirim satu pesan (lewat app atau `curl` dari modul 4), lalu cari barisnya di `realtime.messages`. Ada berapa baris untuk satu pesan di DM? (Petunjuk: `room:` + `user:` untuk setiap anggota.)
3. Baca `\sf private.broadcast_message`. Kapan event berisi pesan lengkap, dan kapan hanya `ref: true`?
4. Jelaskan kenapa "mengirim event setelah commit" tidak perlu dikhawatirkan di sistem ini.
5. Lakukan 6.7, lalu matikan WiFi sebentar dan nyalakan lagi. Frame apa yang dikirim app saat tersambung ulang, dan RPC apa yang dipanggil?

## Cek pemahaman

- Kenapa kita berhenti memakai Postgres Changes untuk chat?
- Kenapa klien hanya boleh mendengarkan, tidak boleh broadcast?
- Kenapa gap-fill tetap diperlukan walaupun Realtime cepat?

**Bacaan:** Supabase docs *Realtime: Broadcast*, *Broadcast from the Database*, *Realtime Authorization*; Phoenix docs *Channels*.
