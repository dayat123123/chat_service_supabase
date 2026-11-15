# trade-relay

Relay realtime order dan trade OLT untuk fitur **Berbagi Trade** dan **notifikasi trade ke pemilik order** (versi **0.1.0**). Rencana lengkap: [docs/berbagi-trade/rencana.md](../../docs/berbagi-trade/rencana.md). Runbook: [docs/berbagi-trade/operasional.md](../../docs/berbagi-trade/operasional.md).

Relay meniru cara proses OLT `clientOrdersRealtimeMME` menerima realtime: ZMQ **DEALER** ke iProxy dengan identity sendiri, paket `CIPackage`. Relay tidak menyimpan apa pun ke disk dan tidak mencatat isi paket, nomor rekening, harga, atau volume ke log.

```
iProxy OLT ──ZMQ DEALER──▶ socket ──antrean terima (berbatas)──▶ decode ──antrean event (berbatas)──▶ kirim batch
 (ROUTER 9990)              │ heartbeat 0xffff                    │ saring id paket + custId          │ trade_relay_events
                            │ reconnect / restart dari Hub        │ dekripsi AES + Snappy            ▼
                            ▼                                     ▼                                 PostgREST (service_role)
                       trade_relay_config  ◀── tarik setiap 15 dtk (alamat, identity, AES, daftar rekening, generation)
                       trade_relay_status + service_heartbeat ◀── setiap 30 dtk
```

## Alur paket

1. **Socket** hanya menerima frame lalu memasukkannya ke antrean terima tanpa pernah menunggu. Antrean penuh: frame dibuang dan dihitung `recv_overflow`, supaya antrean iProxy untuk identity relay tidak menumpuk.
2. **Decode** (satu goroutine, urutan terjaga):
   - id paket dibaca dari header lebih dulu. Selain `0x0022`, `0x0023`, `0x0024` dibuang (`other`), heartbeat dihitung (`heartbeats`);
   - fitur mati atau daftar rekening kosong: dibuang (`filtered_out`) sebelum dekripsi;
   - dekripsi bila flag bit 0 (AES `rijndael-128` seperti `CMCrypt` OLT: ECB, atau CBC dengan IV; padding nol), lalu dekompresi bila flag bit 1 (blok Snappy, panjang hasil dicek sebelum didekode);
   - hanya `custId` yang dibaca dulu. Rekening yang tidak ada di daftar dibuang tanpa jejak;
   - decode penuh secara ketat: frame terpotong, string lebih dari 4.096 byte, tanggal atau jam tidak valid ditolak (`decode_errors`).
3. **Event** dibentuk minimal: update order (status, volume, harga order) untuk rekening trader, dan fill (volume, harga match) untuk rekening trader atau pemilik. `orderId` dan id trade dikirim sebagai hash SHA-256.
4. **Kirim** batch berurutan (bawaan 200 event per panggilan). Database tidak terjangkau: dicoba lagi dengan backoff sampai 30 detik. Batch ditolak database (4xx): dibuang dan dihitung `send_rejected`. Antrean event penuh: event tertua dibuang (`buffer_overflow`).

Harga dan volume selalu diteruskan karena notifikasi pemilik order membutuhkannya. Pengaturan trader untuk menyembunyikan harga ditegakkan di database: harga dibuang sebelum disimpan.

## Perintah dari Hub

`trade_relay_config` membawa `reconnect_generation` dan `restart_generation`. Nilai saat relay mulai dianggap sudah dijalankan.

| Perintah | Perilaku |
|---|---|
| Sambung ulang | Socket ditutup dan dibuka lagi tanpa keluar proses |
| Restart | Sisa antrean dikirim (maksimal `RESTART_FLUSH`), status terakhir dilaporkan, proses keluar dengan kode 0, Docker menjalankannya lagi |

**Watchdog.** Setiap loop (config, socket, decode, send, status) melapor detak. Bila ada loop yang macet lebih dari `WATCHDOG_TIMEOUT`, `/healthz` mengembalikan 503 (healer me-restart container), dan bila masih macet lewat satu periode lagi proses keluar dengan kode 2.

## Konfigurasi (env)

Alamat iProxy, identity, interval heartbeat, dan kunci AES diatur di Hub (Sistem → Relay Trade), bukan di env.

| Variabel | Bawaan | Keterangan |
|---|---|---|
| `PORT` | `8080` | Ops: `/healthz`, `/metrics` |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Secret JWT Supabase untuk `service_role` |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname | |
| `CONFIG_INTERVAL` | `15s` | |
| `STATUS_INTERVAL` | `30s` | |
| `FLUSH_INTERVAL` | `500ms` | |
| `BATCH_SIZE` | `200` | 1–500 |
| `BUFFER_SIZE` | `10000` | Antrean event |
| `RECV_QUEUE` | `100000` | Antrean frame mentah |
| `ZMQ_HWM` | `100000` | RCVHWM socket |
| `RECV_TIMEOUT` | `500ms` | Sama dengan `clientOrdersRealtimeMME` |
| `SILENT_RECONNECT` | `10m` | Sambung ulang bila tidak ada frame sama sekali. `0` = mati |
| `REQUEST_TIMEOUT` | `10s` | |
| `WATCHDOG_TIMEOUT` | `60s` | |
| `RESTART_FLUSH` | `5s` | |
| `LOG_LEVEL` | `info` | |

## Metrik

`/metrics` berisi penghitung `trade_relay_<nama>_total` (`received`, `recv_overflow`, `heartbeats`, `other`, `filtered_out`, `orders`, `trades`, `forwarded_order`, `forwarded_fill`, `decode_errors`, `encrypted_no_key`, `decrypt_errors`, `decompress_errors`, `buffer_overflow`, `sent_batches`, `send_errors`, `send_rejected`, `accepted`, `duplicate`, `ignored`, `dropped`, `invalid`, `reconnects`, `config_errors`) dan gauge `connected`, `queue_length`, `recv_queue_length`. Penghitung yang sama dikirim ke `trade_relay_status` dan tampil di Hub.

## Tiruan iProxy (dev)

Biner kedua di image yang sama: `/dummy-iproxy` (`cmd/dummy-iproxy`), dipakai di `docker/compose.dummy-olt.yml`. ROUTER yang mengirim skenario order dan trade (penuh, sebagian lalu ditarik) untuk rekening `ACCOUNTS`, ditambah paket noise nasabah lain sebanyak `NOISE_RATE` per detik. `COMPRESS_RATIO` mengatur porsi paket terkompresi. `AES_KEY` / `AES_MODE` / `AES_IV` (dev saja) membuat paket terenkripsi.

Untuk mencoba di dev: jalankan stack dengan `-DummyOlt`, isi alamat `tcp://dummy-iproxy:9990` di Hub, nyalakan fitur, lalu buat trader dengan rekening `DEMO1`.

## Tes

Selama fitur dijeda, `make` / `make.ps1` tidak punya target untuk relay. Jalankan tes langsung dari root repo:

```
docker run --rm -v "$PWD/services/trade-relay:/src" -w /src golang:1.27.3-alpine3.24 sh -euc 'apk add --no-cache build-base pkgconf zeromq-dev >/dev/null && CGO_ENABLED=1 go test -race -count=1 ./...'
```

Tes berjalan di container Go dengan libzmq: frame golden yang dihasilkan kode C++ OLT asli (`internal/protocol/testdata/olt`, lihat README di sana), round-trip protokol (plain, Snappy, AES ECB/CBC, gabungan), paket terpotong dan bom dekompresi, fuzz `FuzzFrame`, hash dan validasi event, antrean, serta relay dengan socket dan store palsu (saring trader/pemilik, retry, batch ditolak, sambung ulang, restart, heartbeat, antrean penuh). Fuzz manual: `go test -run=XXX -fuzz=FuzzFrame -fuzztime=60s ./internal/protocol`.
