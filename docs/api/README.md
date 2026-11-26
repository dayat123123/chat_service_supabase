# Spesifikasi API Chat

Kontrak standar untuk tim yang ingin menghubungkan aplikasi atau layanannya ke chat Rendezvous Community tanpa memakai library Flutter.

| File | Standar | Isi |
|---|---|---|
| [openapi.yaml](openapi.yaml) | OpenAPI 3.1 | Semua panggilan HTTP: tukar token, RPC chat (room, pesan, reaksi, tanda baca, mengetik, permintaan DM, grup, room saham), upload lampiran, push, konfigurasi klien, API notifikasi server, dan API kesehatan sistem untuk aplikasi internal |
| [kesehatan-sistem.openapi.yaml](kesehatan-sistem.openapi.yaml) | OpenAPI 3.1 | Khusus API kesehatan sistem untuk aplikasi internal: `GET /integration/v1/system/health` dan `/system/nodes`. Panduan: [../integration/kesehatan-sistem.md](../integration/kesehatan-sistem.md) |
| [laporan-keuangan.openapi.yaml](laporan-keuangan.openapi.yaml) | OpenAPI 3.1 | API kirim laporan keuangan: `POST /integration/v1/financial-reports` (body `instance.zip`) dan `GET /integration/v1/financial-reports/{id}`. Panduan: [../integration/laporan-keuangan.md](../integration/laporan-keuangan.md) |
| [asyncapi.yaml](asyncapi.yaml) | AsyncAPI 3.0 | Event realtime lewat WebSocket: cara join, heartbeat, ganti token, dan isi setiap event |

Kedua file bisa dibuka di editor apa pun yang mendukung standarnya. Misalnya, tempel isinya ke [Swagger Editor](https://editor.swagger.io) atau [AsyncAPI Studio](https://studio.asyncapi.com), atau pakai generator klien OpenAPI/AsyncAPI untuk bahasa yang dipakai.

## Alur integrasi klien

```
1. Sistem host (OLT) menerbitkan token sosial bertanda tangan   → docs/olt-integration.md
2. POST /bridge/v1/exchange {token}                             → access_token (±15 menit)
3. POST /rest/v1/rpc/get_my_rooms, get_messages, send_message … → header apikey + Bearer access_token
4. WebSocket /realtime/v1/websocket, join room:{id} dan user:{id} → event message, typing, receipt …
5. POST /media/v1/object/attachments/rooms/{room}/{saya}/{uuid}.jpg → lalu kirim path-nya di send_message
6. POST /rest/v1/rpc/register_push_device                       → push FCM saat aplikasi tertutup
```

Contoh mengirim pesan:

```bash
curl -sS -X POST "https://api.contoh.co.id/rest/v1/rpc/send_message" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" \
  -d '{"p_room_id":"a3e0c1f2-7d4b-4c55-9a51-0f8a3f7c1d20","p_body":"Halo","p_client_id":"5b9f2c1e-3a77-4f0c-8d2e-91c3a0b7e6f4"}'
```

## Aturan yang wajib diikuti klien

- **Semua aksi lewat RPC.** Klien hanya mendengarkan WebSocket dan tidak pernah menyiarkan event sendiri. Server memeriksa keanggotaan, blokir, kebijakan DM, slow mode, bisu, dan filter konten di setiap aksi.
- **`p_client_id` di setiap pesan.** Pakai UUID buatan klien. Mengirim ulang dengan id yang sama aman (tidak membuat pesan ganda), dan id itu ikut di event `message` untuk mencocokkan pesan sementara.
- **Isi celah setelah tersambung ulang.** Realtime tidak menyimpan event yang terlewat. Setelah koneksi pulih, panggil `get_message_ids` dengan cursor pesan terakhir lalu `get_messages_by_ids`. Event `message` dengan `ref: true` juga diambil isinya lewat `get_messages_by_ids`.
- **Kode error dari `message`.** Untuk error berkode `PT…`, pakai `message` (misalnya `slow_mode`, `dm_not_allowed`) untuk logika program dan terjemahan. Teks di `details`/`hint` bisa berubah.
- **Abaikan field yang tidak dikenal.** Field baru bisa ditambah tanpa pemberitahuan. Fungsi yang belum ada di server lama dijawab `PGRST202`.
- **Perbarui token sebelum kedaluwarsa,** di HTTP maupun di setiap topik WebSocket (event `access_token`).
- **Rahasiakan API key integrasi** (`oik_…`). Key ini hanya untuk server, tidak boleh dipasang di aplikasi.

## Cakupan

Tercakup: chat DM, grup, room saham, permintaan DM, lampiran, push, dan notifikasi dari server host.

Belum tercakup di spesifikasi ini: feed dan komentar, notifikasi di dalam aplikasi, pusat bantuan, alur tiket CS dari sisi nasabah, dan API Hub (`cs_api`). Semuanya memakai pola yang sama (RPC + event realtime); daftar fungsinya ada di [docs/social](../social/README.md) dan [docs/cs-chat](../cs-chat/README.md).

## Versi

Versi spesifikasi mengikuti tanggal rilis server (`2026.11.18` = sampai migrasi `0171`). Perubahan RPC chat wajib ikut memperbarui file ini di commit yang sama.
