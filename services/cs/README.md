# services/cs: `customer-adapter`

Module Go untuk customer service lewat chat ([docs/cs-chat](../../docs/cs-chat/README.md)). Saat ini berisi satu binary, `customer-adapter`. `cs-matcher` menyusul di tahap CS2 di module yang sama.

`customer-adapter` adalah satu-satunya pintu ke data nasabah di OLT (Protokol v1). Service ini stateless dan aman dijalankan beberapa replika. **Izin selalu diputuskan database** (schema `cs`). Adapter hanya mengerjakan I/O ke OLT.

```
Panel agen / App nasabah ──JWT──▶ Kong /cs/v1 ──▶ customer-adapter ──RPC cs_api (JWT pemanggil)──▶ izin, batas & audit di DB
                                                        └──────────────▶ OLT (Protokol v1, kredensial khusus data nasabah)
```

- Adapter memverifikasi tanda tangan JWT, lalu meneruskan JWT pemanggil ke RPC `cs_api`.
- RPC itu memeriksa peran + 2FA (`aal2`), apakah agen sedang menangani sesi tersebut, dan batas anomali (30 profil/jam, 10 pembukaan data/jam per agen). Setelah itu ia menulis audit log. Baru setelahnya adapter memanggil OLT.
- Data sensitif disamarkan oleh OLT (sesuai protokol). Adapter menyamarkan sekali lagi sebagai pengaman.
- Setiap request ke OLT membawa `correlation_id` (ID sesi + kode agen).

## API (lewat Kong: `/cs/v1`)

Semua request wajib membawa `apikey` dan `Authorization: Bearer <JWT>`. Respons sukses berbentuk `{"available": true, "data": …}`. Bila OLT tidak bisa dihubungi, respons `503 {"available": false, "code": "olt_unavailable"}` dan panel menampilkan "tidak tersedia".

| Method & path | Siapa | Isi |
|---|---|---|
| `GET /agent/sessions/{session}/customer/profile` | Agen yang menangani sesi, supervisor, kepatuhan (sesi berflag) | Profil tersamar |
| `GET /agent/sessions/{session}/customer/orders` | 〃 | Daftar order (`from`, `to`, `status`, `code`, `cursor`, `limit`) |
| `GET /agent/sessions/{session}/customer/orders/{order}` | 〃 | Detail order + riwayat + eksekusi (isi kartu order di chat) |
| `GET /agent/sessions/{session}/customer/cash-transactions[/{id}]` | 〃 | Transaksi RDN |
| `GET /agent/sessions/{session}/customer/sessions` | 〃 | Perangkat & riwayat login (IP tersamar) |
| `GET /agent/sessions/{session}/customer/security` | 〃 | Status keamanan akun |
| `POST /agent/sessions/{session}/customer/reveal` | 〃 | Buka satu field (`{"field","reason"}`), berlaku 5 menit, tercatat |
| `POST /agent/sessions/{session}/customer/secure-account` | Agen yang menangani, supervisor | "Amankan akun" di OLT (idempoten per sesi). Hasilnya dicatat dan nasabah diberi tahu di chat |
| `GET /me/orders`, `GET /me/orders/{order}`, `GET /me/cash-transactions` | Nasabah (data sendiri) | Memilih order/transaksi untuk kartu konteks di chat |

Port ops (`9100`, tidak lewat Kong) menyediakan `GET /livez`, `GET /readyz`, dan `GET /metrics`.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `APP_ENV` | `production` | `production` menolak OLT tanpa `wss://` |
| `JWT_SECRET[_FILE]` | – | Verifikasi JWT pemanggil dan token readiness ke PostgREST |
| `POSTGREST_URL` | `http://rest:3000` | |
| `PORT`, `OPS_PORT` | 8080, 9100 | |
| `OLT_WS_URL`, `OLT_SERVICE_TOKEN[_FILE]`, `OLT_WS_TIMEOUT`, `OLT_WS_ORIGIN` | –, –, 5 dtk, – | Endpoint & kredensial **khusus data nasabah** (terpisah dari login/harga) |
| `BREAKER_FAILURE_THRESHOLD`, `BREAKER_COOLDOWN` | 5, 30 dtk | Circuit breaker ke OLT |

## Paket

| Paket | Isi |
|---|---|
| `internal/adapter` | Handler HTTP, validasi input, penyamaran ulang |
| `internal/olt` | Klien Protokol v1 (WebSocket) dengan circuit breaker |
| `internal/postgrest` | Klien RPC `cs_api` |
| `internal/token`, `internal/env`, `internal/ops`, `internal/metrics`, `internal/breaker` | JWT HS256, konfigurasi, server ops, metrik Prometheus, circuit breaker |
| `internal/letter` | Pembuat PDF deterministik (fpdf + font Go), dipakai ulang untuk ekspor transkrip PDF di CS5 |

Dependensi: `gorilla/websocket` (BSD), `codeberg.org/go-pdf/fpdf` (MIT), `golang.org/x/image` (BSD).

## Pengembangan

```bash
make test-cs                 # unit test (Windows: .\make.ps1 test-cs)
make up DUMMY_OLT=1          # stack dev + OLT dummy sebagai sumber data nasabah
make smoke-cs                # end-to-end: nasabah -> cs_api -> agen -> adapter -> OLT dummy
```

Dockerfile dipakai bersama semua binary di module ini: `docker build --build-arg SERVICE=customer-adapter services/cs`.
