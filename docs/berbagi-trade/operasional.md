# Operasional Berbagi Trade dan Relay Trade

Panduan untuk Super Admin, Kepatuhan, dan tim IT. Desain lengkap ada di [rencana.md](rencana.md), detail teknis relay di [services/trade-relay/README.md](../../services/trade-relay/README.md).

## Status saat ini: dijeda (sejak 15 November 2026)

Fitur ini disimpan di repo tetapi tidak aktif:

- **Hub:** menu Berbagi Trade, Pengaturan → Relay Trade, Sistem → Relay Trade, serta izin Berbagi Trade di akun staf disembunyikan lewat `SHOW_TRADE_SHARE = false` di `src/lib/nav-config.ts` (repo rendezvous_hub).
- **Server:** container `trade-relay` dan `dummy-iproxy` ada di profil compose `trade-relay`, jadi `make up` tidak menjalankannya. `make` / `make.ps1` juga tidak punya perintah apa pun untuk relay (termasuk `test-trade-relay`). Di cluster, `trade-relay` berjalan dengan `replicas: 0`. Bila container relay lama masih jalan di server, matikan sekali dengan `docker stop olt-social-trade-relay-1`.
- Migrasi, cron, dan RPC tetap terpasang. Tombol darurat `trade_share.enabled` dan `trade_notify.enabled` tetap mati, sehingga tidak ada alert relay dan aplikasi nasabah tidak menampilkan fitur ini.

Cara mengaktifkan lagi:

1. Hub: ubah `SHOW_TRADE_SHARE` menjadi `true`, lalu deploy Hub.
2. Server: tambahkan kembali dukungan relay ke `Makefile` / `make.ps1` (profil `trade-relay` dan target `test-trade-relay`, lihat riwayat git commit 2b8de53), atau jalankan langsung `docker compose -f docker/compose.yml -f docker/compose.prod.yml --profile trade-relay up -d trade-relay`. Untuk simulator iProxy di dev, tambahkan `-f docker/compose.dummy-olt.yml` dan service `dummy-iproxy`. Di cluster, kembalikan `replicas: 1` untuk `trade-relay` di `docker/stack.cluster.yml`.
3. Lanjutkan dari bagian 1 di bawah.

## 1. Pemasangan pertama

1. **Deploy server** seperti biasa (`git pull`, lalu `make up`). Migrasi 0160–0164 berjalan otomatis dan container `trade-relay` ikut naik. Fitur bawaannya **mati**, jadi tidak ada yang berubah bagi nasabah.
2. **Minta ke tim OLT:**
   - buka port iProxy (bawaan 9990) khusus untuk IP server kita; bila jalurnya lewat internet, pakai tunnel VPN;
   - arahkan realtime order dan trade ke identity relay (bawaan `social_trade_relay`), sama seperti ke identity `realtime` milik `clientOrdersRealtimeMME`.
3. **Hub → Pengaturan → Integrasi → Relay Trade** (Super Admin, tekan **Ubah** dulu):
   - isi alamat `tcp://<ip-iproxy>:9990` dan identity;
   - bila OLT mengaktifkan enkripsi, isi kunci, IV, dan mode AES. Kunci tidak bisa dibaca kembali dari Hub;
   - pastikan status instance menjadi **terhubung** dan **paket realtime terakhir** bergerak di jam bursa.
4. **Hub → Akun staf:** beri izin `trade_share.review` / `trade_share.manage` ke staf Kepatuhan dan `trade_relay.operate` ke staf IT jaga.
5. **Hub → Dokumen hukum:** terbitkan **S&K Berbagi Trade** dan **Pernyataan Risiko Berbagi Trade** setelah disetujui Kepatuhan sekuritas. Draf teks Indonesia dan Inggris ada di [draf-dokumen-hukum.md](draf-dokumen-hukum.md). Tanpa kedua dokumen ini, pengajuan trader dan langganan tidak bisa dilakukan.
6. **Pilot:** biarkan `trade_share.pilot_only` menyala, undang beberapa nasabah dari tab Daftar, lalu nyalakan `trade_share.enabled` dari tab Pengaturan.

## 2. Notifikasi trade untuk pemilik order

`trade_notify.enabled` (Super Admin, Sistem → Relay Trade) mengirim push "Order beli BBCA match 5 lot @ 9.150" ke nasabah setiap kali order-nya match. **Sebelum dinyalakan**, pastikan notifEngine OLT tidak lagi mengirim push trade yang sama, supaya nasabah tidak menerima notifikasi ganda.

## 3. Arti alert

| Alert | Arti | Langkah |
|---|---|---|
| `trade_relay:down` (kritis) | Relay tidak melapor lebih dari 2 menit | Cek container: `docker compose ps trade-relay`, lihat log. Healer biasanya sudah me-restart. Bila tetap mati, `docker compose restart trade-relay` |
| `trade_relay:disconnected` (kritis) | Socket ke iProxy tertutup di jam bursa | Cek jaringan ke OLT dan apakah iProxy berjalan. Tekan **Sambung ulang** di Hub |
| `trade_relay:silent` (peringatan) | Terhubung tetapi tidak ada paket realtime 30 menit di jam bursa | Tanyakan ke OLT apakah realtime masih diarahkan ke identity relay |
| `trade_relay:decode_errors` | Lebih dari 1% paket rusak | Kemungkinan format paket OLT berubah. Kumpulkan contoh dari tim OLT |
| `trade_relay:overflow` | Antrean event penuh, sebagian event terbuang | Database lambat atau mati. Cek kesehatan database |
| `trade_relay:encrypted_no_key` | Datang paket terenkripsi tetapi kunci AES belum diatur | Isi kunci AES di Hub |

## 4. Sambung ulang dan restart

- **Dari Hub** (Sistem → Relay Trade): tombol **Sambung ulang** atau **Restart**, wajib beralasan, maksimal satu per menit. Perintah dijalankan relay paling lambat 15 detik, dan Hub menampilkan **Selesai** setelah relay melapor.
- **Bila Hub tidak bisa dipakai:** di server, `docker compose restart trade-relay`.

## 5. Mematikan fitur

| Kebutuhan | Langkah |
|---|---|
| Darurat (sementara) | Hub → Kepatuhan → Berbagi Trade → Pengaturan → matikan `trade_share.enabled`. UI di aplikasi hilang, relay berhenti meneruskan, order yang belum dilaporkan dan pengiriman yang tertunda langsung dibatalkan |
| Hentikan notifikasi pemilik | Matikan `trade_notify.enabled` |
| Hentikan relay saja | Kosongkan alamat iProxy di Hub |
| Pensiun permanen | Matikan kedua pengaturan, kosongkan alamat iProxy, minta OLT menutup port dan menghapus identity relay dari tujuan realtime. Data terhapus sendiri setelah masa simpan (`trade_share.retention_days`, bawaan 30 hari) |

## 6. Pemeliharaan otomatis

| Jadwal | Isi |
|---|---|
| `trade-share-tick` setiap 30 detik | Menentukan order selesai atau sebagian, membuat aktivitas, mengirim notifikasi ke pelanggan |
| `trade-share-maintenance` setiap 15 menit | Kedaluwarsakan permintaan langganan, akhiri penangguhan yang lewat batas, segarkan status rekening, hapus data lewat masa simpan, buat penanda pemantauan |

## 7. Pengecekan cepat (psql, Super Admin)

```sql
select instance, connected, state, last_realtime_at, counters ->> 'received' as received,
       counters ->> 'forwarded_fill' as fills, counters ->> 'decode_errors' as errors
from private.trade_relay_status order by reported_at desc;

select * from private.trade_relay_daily where day = (now() at time zone 'Asia/Jakarta')::date;
```
