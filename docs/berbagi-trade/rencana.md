# Rencana Fitur Berbagi Trade

Status: **disetujui pemilik produk 15 Nov 2026**. Keputusan Kepatuhan di bagian 14 diisi dengan rekomendasi dan tetap dikonfirmasi ke Kepatuhan sekuritas sebelum pilot. Bahan dari OLT (bagian 13) belum tersedia, jadi pekerjaan relay menunggu (bagian 15). Belum ada kode, migrasi, atau perubahan library yang dibuat.

Dokumen ini merangkum seluruh keputusan diskusi 15 Nov 2026 dan menjadi acuan pengerjaan.

**Progres (15 Nov 2026):** tahap 1–8 dikerjakan di cabang `feat/berbagi-trade` (belum di-commit): migrasi 0160–0164 dan tes 137–141, relay `services/trade-relay` dengan tiruan iProxy, Hub, dan library. Runbook: [operasional.md](operasional.md). Tahap 9 (UAT bersama OLT) menunggu pembukaan port iProxy dan frame contoh dari OLT.

## 1. Ringkasan

Nasabah yang disetujui Kepatuhan (selanjutnya **trader**) dapat membagikan trade yang sudah **done (match)** di rekeningnya. Nasabah lain yang berlangganan (selanjutnya **pelanggan**) menerima notifikasi seperti:

> Hidayat membeli $BBCA · 25 lot @ 9.150 · 10.32

Fitur ini **hanya informasi**. Tidak ada order otomatis, tidak ada tombol "ikuti order", dan pelanggan bertransaksi sendiri lewat aplikasi OLT seperti biasa.

Seluruh logika ada di service kita. Satu-satunya titik ke OLT adalah **relay** yang mendengarkan realtime order dan trade dari iProxy OLT secara pasif dan hanya membaca, dengan cara yang sama seperti proses OLT `clientOrdersRealtimeMME`. Fitur ini bisa dimatikan kapan saja dari web tanpa rilis ulang aplikasi OLT dan tanpa perubahan apa pun di sisi OLT.

### Tujuan

1. Nasabah dapat mengikuti aktivitas trade nasabah lain secara transparan dan terkendali.
2. Kepatuhan memegang kendali penuh: persetujuan, penangguhan, pencabutan, pengaturan global, tombol darurat, dan pemantauan.
3. Tidak ada ketergantungan baru ke OLT selain relay yang pasif.
4. Data yang keluar dari jaringan OLT seminimal mungkin dan hanya untuk rekening yang sudah disetujui.

### Di luar cakupan

| Tidak dikerjakan | Alasan |
|---|---|
| Order otomatis (auto copy trade) | Mendekati jasa nasihat atau pengelolaan investasi yang butuh izin khusus OJK |
| Grup atau ruang obrolan trader dengan pelanggan | Rawan dipakai mengatur harga bersama dan menambah beban moderasi. Diskusi tetap lewat komentar dan DM yang sudah ada |
| Statistik kinerja, win rate, leaderboard | Terkesan menjanjikan hasil |
| Langganan berbayar atau imbalan bagi trader | Mendekati jasa nasihat investasi berizin |
| Notifikasi order yang masih open atau dibatalkan | Bisa dipakai memancing (spoofing) |
| Profil risiko nasabah sebagai syarat | Menuntut OLT menambah klaim di token, bertentangan dengan tujuan nomor 3 |

## 2. Istilah

| Istilah | Arti |
|---|---|
| Trader | Profil yang disetujui Kepatuhan untuk membagikan trade |
| Pelanggan | Profil yang berlangganan notifikasi trade dari seorang trader |
| Rekening | `custId` di OLT, di server kita `cust_id` pada `private.account_links` |
| Update order | Satu paket realtime order (`0x0022` / `0x0023`) yang membawa status, harga, dan volume terbaru sebuah order |
| Fill | Satu paket realtime trade (`0x0024`), yaitu satu kejadian match dari sebuah order. Saat match sebagian, order tetap berstatus open |
| Aktivitas | Satu order milik trader yang sudah selesai (penuh atau sebagian) dan dikirim sebagai satu notifikasi |
| Relay | Service baru `trade-relay` yang terhubung ke iProxy OLT seperti `clientOrdersRealtimeMME` dan meneruskan update order serta fill yang lolos saring |
| `clientOrdersRealtimeMME` | Proses OLT yang menjadi acuan cara relay menerima realtime dari iProxy. Relay tidak terhubung ke proses ini |
| Jeda | Waktu tunggu sejak trade terjadi sampai notifikasi boleh dikirim |
| Tombol darurat | Pengaturan global yang mematikan seluruh fitur seketika |

## 3. Keputusan yang sudah disepakati

1. Hanya informasi, tanpa order otomatis.
2. Langganan satu arah, bukan grup.
3. Trader **mengajukan** dari aplikasi. Pengajuan ditinjau di Hub (menu Kepatuhan) oleh staf berizin, yang bisa menyetujui, menolak, menangguhkan, atau mencabut.
4. Pelanggan meminta berlangganan. Trader memilih mode **otomatis** atau **perlu persetujuan**.
5. Harga dan lot **ditampilkan secara bawaan**. Trader boleh menyembunyikan masing-masing secara terpisah. Kepatuhan bisa memaksa keduanya tersembunyi untuk semua orang.
6. Beli **dan** jual selalu dibagikan dua-duanya. Trader tidak bisa memilih salah satu.
7. Jeda minimum ditetapkan server (bawaan 15 menit). Trader hanya boleh memilih jeda lebih lama.
8. Sumber data adalah paket realtime **order dan trade** dari iProxy OLT, diterima dengan cara yang sama seperti `clientOrdersRealtimeMME`. Status, lot order, dan harga order dari paket order. Volume match dari paket trade, karena saat match sebagian order tetap berstatus open. Satu order menghasilkan satu notifikasi saat order selesai, bukan per match, supaya match sebagian tidak menghasilkan informasi yang salah. Pemetaan rekening ke profil memakai `private.account_links` yang sudah ada.
9. Relay berjalan sebagai **container sendiri di server kita**, sama seperti container lain (diputuskan 15 Nov 2026). OLT membuka port iProxy untuk server kita. Konfigurasinya dikelola dari Hub, dan relay bisa disambung ulang atau di-restart dari Hub oleh staf berizin.
10. Tombol darurat di Hub mematikan seluruh fitur, termasuk menyembunyikan UI di library.

## 4. Arsitektur

```
 Jaringan OLT          │  Server kita (satu compose project)
                       │
 ┌────────┐  ZMQ       │  ┌─────────────┐  RPC service_role  ┌──────────────┐
 │ iProxy │ ───────────┼─▶│ trade-relay │ ─────────────────▶ │  PostgREST   │
 └────────┘  port      │  │ (container) │ ◀── config,        │  + Postgres  │
     │       dibuka    │  └─────────────┘     perintah       └──────┬───────┘
     │       untuk IP  │        ▲ diawasi healer                    │ cron jeda,
     │       server    │        │ + sentinel                        │ gabung, fan-out
     │       kita      │                                            ▼
     ▼                 │  ┌──────────┐  push   ┌──────────────┐     │
 ┌────────────┐        │  │ notifier │◀────────│ push_enqueue │◀────┤
 │ notifEngine│ tetap  │  └──────────┘         └──────────────┘     │
 └────────────┘ seperti│                                            │
                sekarang  ┌──────────────┐  RPC                     │
                       │  │ Hub (web CS) │◀────────────────────────▶│
                       │  └──────────────┘                          │
                       │  ┌──────────────────────┐  RPC             │
                       │  │ Aplikasi OLT +       │◀────────────────▶│
                       │  │ rendezvous_community │
                       │  └──────────────────────┘
```

### Komponen

| Komponen | Status | Peran |
|---|---|---|
| `services/trade-relay` | **Baru** | Terhubung ke iProxy sebagai DEALER seperti `clientOrdersRealtimeMME`, decode, saring rekening yang disetujui, kecilkan data, simpan lewat RPC, laporkan status, jalankan perintah dari Hub |
| Database | Migrasi baru 0160–0164 | Semua aturan, status, jeda, penggabungan, fan-out, audit, pengaturan |
| `services/integration` | Tidak diubah | Relay tidak lewat gateway karena berada di jaringan internal yang sama dengan PostgREST |
| `services/notifier` | Tidak diubah | Mengirim push dari `private.push_enqueue` seperti biasa |
| `services/sentinel` | Aturan alert baru (di database) | Alert relay mati, tidak terhubung, atau tidak ada paket di jam bursa |
| `services/healer` | Tidak diubah | Relay diberi label `olt.autoheal=true`, jadi ikut di-restart otomatis bila unhealthy |
| Hub (`rendezvous_hub`) | Diubah | Menu Kepatuhan "Berbagi Trade" dan menu Sistem "Relay Trade" |
| Library (`rendezvous_community`) | Diubah (1.28.0) | Pengaturan berbagi, pengajuan, lonceng langganan, notifikasi trade, halaman langganan |
| `dummy-iproxy` (`services/trade-relay/cmd/dummy-iproxy`) | **Baru, hanya dev** | Meniru iProxy (ROUTER) dan mengirim paket `CIPackage` order dan trade sintetis, termasuk yang terkompresi dan terenkripsi, untuk pengujian lokal. Komponen terpisah, kode dummy-olt tidak diubah |

### Lokasi relay (diputuskan)

Relay berjalan di server kita sebagai service di `docker/compose.yml`, sama seperti notifier, janitor, dan service lain. OLT membuka port iProxy (bawaan 9990) khusus untuk alamat IP server kita, dan mengarahkan realtime ke identity relay.

Konsekuensi yang diterima:

| Hal | Penanganan |
|---|---|
| Server kita sekarang punya satu koneksi keluar ke OLT | Hanya untuk fitur ini dan bersifat opsional. Bila koneksi putus atau fitur dimatikan, fitur lain tidak terpengaruh |
| Realtime **seluruh** nasabah OLT sampai ke relay | Sama seperti `clientOrdersRealtimeMME`. Disaring di memori relay. Paket rekening yang tidak disetujui dibuang tanpa disimpan, tanpa log, tanpa metrik per rekening |
| Lalu lintas ZMQ bukan TLS dan paket iProxy tidak dienkripsi | Port iProxy hanya dibuka untuk IP server kita (firewall OLT). Bila server kita dan OLT berada di LAN yang sama (seperti notifEngine yang sudah memanggil server kita dari LAN), allowlist IP cukup. Bila melewati internet, wajib lewat tunnel (VPN site-to-site atau WireGuard) |

## 5. Alur lengkap

### 5.1 Trader mengajukan

1. Di aplikasi, nasabah membuka **Pengaturan → Berbagi aktivitas trade**. Menu ini hanya muncul bila fitur aktif (bagian 9.1).
2. Library memanggil `get_trade_share_status()` yang membawa bagian `eligibility`. Server memeriksa syarat (bagian 6.1) dan mengembalikan daftar syarat beserta status masing-masing. Bila ada yang belum terpenuhi, tombol Ajukan nonaktif dan alasannya ditampilkan.
3. Nasabah memilih:
   - rekening yang dibagikan, dari rekening yang tertaut ke profilnya (`account_links`);
   - tampilkan harga (bawaan aktif) dan tampilkan lot (bawaan aktif), masing-masing bisa disembunyikan;
   - jeda (bawaan sama dengan minimum dari server, bisa dipilih lebih lama);
   - mode langganan: otomatis (bawaan) atau perlu persetujuan.
4. Nasabah membaca dan menyetujui **Syarat & Ketentuan Berbagi Trade**. Dokumen ini dikelola di Hub lewat fitur dokumen hukum yang sudah ada. Persetujuan dicatat dengan versi dokumen, waktu, dan perangkat.
5. `submit_trade_share_application(...)` membuat pengajuan berstatus `pending`. Nasabah melihat status "Menunggu peninjauan".

### 5.2 Kepatuhan meninjau

1. Pengajuan muncul di **Hub → Kepatuhan → Berbagi Trade → Pengajuan**.
2. Reviewer melihat ringkasan:
   - umur akun;
   - riwayat sanksi moderasi;
   - rekening yang diajukan, dengan peringatan bila rekening tertaut ke lebih dari satu profil aktif atau masuk daftar rekening yang dikecualikan;
   - jumlah pengikut;
   - riwayat pengajuan sebelumnya.
3. Reviewer **menyetujui** atau **menolak**. Menolak wajib memberi alasan.
4. Bila mode empat mata diaktifkan (pengaturan `trade_share.four_eyes`, bawaan mati), persetujuan dari staf pertama menjadi usulan dan baru berlaku setelah staf kedua yang berbeda menyetujui.
5. Trader mendapat notifikasi in-app dan push berisi hasil dan alasannya.
6. Saat disetujui, status menjadi `active` dan rekening masuk daftar yang ditarik relay paling lambat satu siklus tarik (bawaan 15 detik).

### 5.3 Pelanggan berlangganan

1. Di profil trader yang aktif, pelanggan melihat tanda **Membagikan trade** dan tombol lonceng **Notifikasi trade**.
2. Saat menekan lonceng pertama kali, pelanggan menyetujui **pernyataan risiko**: "Informasi ini bukan rekomendasi; keputusan investasi sepenuhnya tanggung jawab Anda." Versi pernyataan dicatat.
3. `request_trade_subscription(trader)`:
   - mode otomatis: status langsung `active`;
   - mode persetujuan: status `pending`, trader menerima notifikasi permintaan, dan permintaan kedaluwarsa setelah 14 hari bila tidak dijawab.
4. Pelanggan bisa membisukan, berhenti berlangganan, atau membatalkan permintaan kapan saja.

### 5.4 Order dan trade terjadi

Sumber datanya iProxy OLT, diterima seperti `clientOrdersRealtimeMME` (bagian 7.2). Relay **menggabungkan** dua paket per order, dicocokkan lewat `orderId` + `custId`:

| Paket | Dipakai untuk |
|---|---|
| Realtime order (`IPKG_REP_NEW_ORDER` `0x0022`, `IPKG_REP_AMEND_ORDER` `0x0023`) | Status order (open, matched, withdrawn, amended), **lot order dan harga order yang asli**, sisa volume |
| Realtime trade (`IPKG_REP_TRADE` `0x0024`) | Setiap kejadian match: volume dan harga match. Saat match sebagian, order tetap berstatus **open**, jadi volume match yang berjalan hanya terlihat dari paket trade |

Notifikasi per trade akan memberi informasi yang tidak valid, misalnya "membeli 5 lot" padahal order 100 lot masih berjalan. Karena itu trade hanya dikumpulkan, dan notifikasi dibuat per order.

1. iProxy mengirim paket realtime order dan trade semua nasabah ke identity relay.
2. Relay:
   1. memeriksa signature, lalu mendekripsi dan mendekompresi sesuai flag;
   2. hanya memproses paket `0x0022`, `0x0023`, dan `0x0024`, dan membuang sisanya;
   3. decode dengan ketat, dan frame yang rusak dibuang lalu dihitung;
   4. mencocokkan `custId` dengan daftar rekening aktif di memori, dan yang tidak cocok dibuang tanpa jejak;
   5. membuang board yang tidak dibagikan (bawaan hanya `RG`, bagian 6.4);
   6. membangun **update order** dan **fill** minimal (bagian 7.3). Harga dan volume selalu ikut karena notifikasi pemilik order membutuhkannya; pengaturan sembunyikan harga ditegakkan di database;
   7. menyimpan keduanya secara batch, berurutan sesuai kedatangan, lewat RPC `trade_relay_events` (PostgREST internal, service_role).
3. Server (`trade_relay_events`):
   1. memeriksa ulang bahwa fitur aktif, rekening masih tertaut ke trader, tidak kedaluwarsa, hanya tertaut ke satu profil aktif, status trader `active`, dan saham tidak dikecualikan;
   2. membuang harga bila trader menyembunyikan harga. Volume tetap disimpan karena diperlukan untuk menentukan selesai atau sebagian, tetapi tidak ditampilkan bila trader menyembunyikan lot;
   3. update order diterapkan ke baris **status order** (`private.trade_orders`, satu baris per `orderId` + `custId`) lewat aturan transisi yang meniru klien OLT (`_handleUpdateUserStockOrders`), karena paket bisa datang tidak berurutan. Lihat bagian 5.4.1;
   4. fill disimpan dengan kunci idempoten (`private.trade_fills`) dan menambah volume match serta harga rata-rata pada baris order. Bila fill datang lebih dulu daripada paket order, baris order dibuat sementara dari data fill (saham, sisi) dan dilengkapi saat paket order datang;
   5. bila salah satu pemeriksaan gagal, data dibuang dengan alasan tercatat sebagai penghitung, tanpa isi.

#### 5.4.1 Aturan transisi status order (meniru klien OLT)

Diambil dari `_handleUpdateUserStockOrders` di aplikasi OLT. Server menerapkan aturan yang sama di satu fungsi (`private.trade_order_apply`), supaya hasilnya sama dengan yang dilihat nasabah di aplikasi OLT.

**Duplikat.** Update dengan `orderId`, status, harga, `remainVolume`, dan `tradedVolume` yang sama dengan yang tersimpan dianggap duplikat. Isinya hanya dipakai untuk melengkapi `amendId` yang masih kosong, lalu dijawab `duplicate`. `amendId` dan `idxOrderId` tidak ikut dalam penentuan duplikat.

**Order baru.** Bila `orderId` belum ada, baris dibuat dengan isi update apa pun statusnya.

**Volume match selalu kumulatif dan tidak pernah turun.** `tradedVolume` di paket order bersifat kumulatif, termasuk setelah amend, tetapi paket bisa datang tidak berurutan. Karena itu volume match yang tersimpan = nilai terbesar dari semua `tradedVolume` yang pernah diterima dan jumlah lembar semua fill. Update dengan `tradedVolume` lebih kecil tidak pernah menurunkan volume, dan statusnya hanya dipakai bila tabel di bawah mengizinkan. `remainVolume` yang tersimpan diambil dari update dengan `tradedVolume` terbesar.

| Update baru | Status tersimpan | Hasil |
|---|---|---|
| `rejected` | `open`, `amending`, `withdrawing` | Diganti `rejected` |
| `rejected` | Lainnya | Diabaikan |
| `open` | `matched`, `rejected` | Status diabaikan (paket terlambat). Volume match tetap mengikuti aturan kumulatif di atas |
| `open` | `open` dengan `tradedVolume` lebih kecil | Diganti. Ini progres **match sebagian** |
| `open` | `open` dengan harga atau `remainVolume` berbeda | **Amend**: versi lama ditandai `amended`, versi baru menjadi versi aktif |
| `open` | `amending` | Amend selesai: versi lama `amended`, versi baru aktif |
| `open` | `amended` | Versi baru aktif |
| `open` | `withdrawing`, `withdrawn` | Diganti `open` (penarikan tidak jadi) |
| `matched` | `open` | Diganti `matched` |
| `matched` | `amending` | Versi lama `amended`, versi baru `matched` |
| `matched` | `matched` dengan `tradedVolume` lebih kecil | Diganti. `matched` **tidak selalu penuh**, jadi match berikutnya tetap bisa datang. Ini berbeda dari klien OLT, yang mengabaikan kasus ini |
| `matched` | Lainnya | Diabaikan |
| `amending` | `open` | Diganti `amending` |
| `withdrawing` | `open` | Diganti `withdrawing` |
| `withdrawn` | `open`, `amending`, `withdrawing` | Diganti `withdrawn` |
| `amended` | `open`, `amending` | Diganti `amended` |
| Kombinasi lain | — | Diabaikan dan dihitung `out_of_order` |

Untuk kebutuhan notifikasi, server hanya menyimpan **versi aktif** per `orderId` (harga order, lot order, sisa, volume match, status) ditambah jumlah amend. Riwayat versi tidak disimpan.

### 5.5 Kapan notifikasi dikirim

Satu order menghasilkan **satu** notifikasi, dikirim saat order selesai atau saat penutupan hari. Tidak pernah per trade.

**Volume match** suatu order = nilai terbesar antara jumlah lembar semua fill dan `tradedVolume` dari paket order terakhir. Dengan begitu, data tetap benar walau salah satu paket terlewat. **Lot order** dan **harga order** diambil dari paket order terakhir (setelah amend).

| Keadaan order | Dikirim | Isi |
|---|---|---|
| Match penuh: `remainVolume` 0 (atau volume match sudah mencapai lot order) dengan volume match lebih dari 0, apa pun statusnya | Ya, segera setelah jeda | "membeli $BBCA · 25 lot @ 9.150" |
| Match sebagian lalu ditarik: status `5` dengan volume match lebih dari 0 | Ya, segera setelah jeda | "membeli $BBCA · 10 dari 25 lot @ 9.150 · sebagian" |
| Match sebagian (status `open` atau `matched` dengan volume match lebih dari 0 dan sisa lebih dari 0) dan order masih berjalan saat penutupan hari | Ya, pada sapuan akhir hari (`trade_share.eod_flush_time`, bawaan 16.30 WIB, hari bursa menurut `cs.holidays`) | "membeli $BBCA · 10 dari 25 lot @ 9.150 · sebagian" |
| Ditolak (status `0`), atau ditarik tanpa match | Tidak | — |
| Masih open tanpa match | Tidak | — |
| Amend (status `3` / `6`) | Tidak dikirim sendiri. Lot dan harga order mengikuti amend terakhir, fill tetap dihitung per `orderId` | — |
| GTC | Tidak ditangani khusus. GTC di OLT akan membuat order biasa, dan order biasa itulah yang dibagikan | — |

Saat match sebagian, order bisa berstatus `open` maupun `matched` dengan `tradedVolume` yang terus naik, sementara setiap kejadian match juga datang sebagai paket trade. Status `matched` **tidak selalu berarti penuh**, jadi satu-satunya penanda selesai penuh adalah sisa volume 0. Status akhir lainnya hanya `withdrawn` dan `rejected`.

Aturan tambahan:

1. **Lot** = lembar ÷ `trade_share.lot_size` (bawaan 100). Volume di kedua paket selalu dalam lembar.
2. **Harga yang ditampilkan** = harga order dari paket order (rupiah, apa adanya). Harga rata-rata tertimbang dari fill tetap disimpan untuk pemantauan Kepatuhan, dan dipakai sebagai harga tampil hanya bila paket order tidak pernah diterima.
3. **Jeda tetap berlaku.** Notifikasi baru boleh dikirim bila order sudah selesai **dan** waktu sekarang sudah melewati waktu fill terakhir + jeda trader.
4. **Paket order terlewat** (misalnya relay putus): fill tetap terkumpul, dan sapuan akhir hari mengirimnya dengan label **sebagian** serta harga rata-rata match, supaya tidak ada yang hilang diam-diam dan tidak ada yang dilaporkan lebih besar dari kenyataan.
5. **Fill terlewat**: `tradedVolume` dari paket order berikutnya menutup selisihnya. Selisih antara keduanya dihitung `fill_mismatch` untuk pemantauan.
6. **Perubahan setelah dilaporkan.** Status akhir baru dilaporkan setelah jeda (minimal 15 menit), jadi paket terlambat di rentang itu sudah terserap. Bila setelah dilaporkan order ternyata `open` lagi (penarikan tidak jadi) dan kemudian bertambah match-nya, hanya **tambahan** volume itu yang dilaporkan sebagai aktivitas berikutnya, memakai kolom volume yang sudah dilaporkan.
7. Bila trader menyembunyikan lot, label **sebagian** tetap tampil tanpa angka. Bila trader menyembunyikan harga, bagian "@ harga" tidak tampil.

### 5.6 Penggabungan dan pengiriman

1. Cron `trade-share-flush` berjalan setiap 30 detik. Order yang memenuhi syarat bagian 5.5 menjadi satu **aktivitas**: kode saham, sisi, lot match, lot order, harga order, harga rata-rata match, penanda sebagian, jumlah fill, waktu order, dan waktu selesai.
2. Sapuan akhir hari berjalan sekali per hari bursa pada `trade_share.eod_flush_time`.
3. Aktivitas dibuat sebagai job fan-out, dengan pola yang sama seperti `private.integration_broadcasts` (kursor, batch per putaran), supaya trader dengan banyak pelanggan tidak membuat transaksi panjang.
4. Per pelanggan aktif yang tidak membisukan, tidak memblokir atau diblokir trader, dan akunnya tidak dihapus:
   - satu entri di kotak notifikasi (jenis `trade_activity`);
   - push jenis `trade_activity` lewat `private.push_enqueue`, mengikuti preferensi push dan jam tenang yang sudah ada.
5. **Penggabungan push.** Bila satu trader menghasilkan beberapa aktivitas untuk pelanggan yang sama dalam satu putaran flush, pelanggan menerima satu push gabungan ("Hidayat melakukan 3 transaksi"), dengan `collapse_key` per trader. Kotak notifikasi tetap menampilkan tiap aktivitas.

### 5.7 Penghentian

| Kejadian | Akibat |
|---|---|
| Trader menjeda | Update order baru dibuang. Order yang belum dilaporkan dibatalkan. Pelanggan tetap tercatat dan menerima lagi saat trader melanjutkan |
| Kepatuhan menangguhkan (bisa dengan batas waktu) | Sama dengan jeda, tetapi trader tidak bisa melanjutkan sendiri. Pelanggan melihat "Trader ini sedang tidak membagikan trade" |
| Kepatuhan mencabut | Status `revoked`. Order yang belum dilaporkan dibatalkan, langganan diakhiri, dan pelanggan diberi tahu dengan kalimat netral. Trader boleh mengajukan lagi setelah masa tunggu |
| Trader berhenti sendiri | Sama dengan dicabut, tanpa masa tunggu |
| Rekening tidak tertaut lagi atau kedaluwarsa (tidak login fitur sosial 30 hari) | Rekening itu berhenti dibagikan dan trader diberi tahu. Bila tidak ada rekening tersisa, status menjadi `paused` otomatis |
| Rekening tertaut ke profil kedua | Rekening itu diblokir dari berbagi, update order dibuang, dan Kepatuhan mendapat penanda untuk ditinjau |
| Pelanggan berhenti mengikuti trader, memblokir, atau diblokir | Langganan berakhir |
| Akun trader atau pelanggan dihapus | Semua data fitur ini ikut terhapus (bagian 8.6) |
| **Tombol darurat dimatikan** | Relay berhenti meneruskan, server menolak update order baru, semua order yang belum dilaporkan dibatalkan, job fan-out berhenti, dan UI di library tersembunyi |

### 5.8 Notifikasi order milik nasabah sendiri

Ditambahkan atas permintaan pemilik produk 15 Nov 2026. Relay yang sama juga mengirim push ke **nasabah pemilik order**, seperti "Trade Confirmation" di notifEngine OLT. Bagian ini terpisah dari berbagi trade:

| Hal | Berbagi trade (ke pelanggan) | Notifikasi milik sendiri (ke pemilik) |
|---|---|---|
| Penerima | Pelanggan trader | Profil yang tertaut ke rekening itu (`private.account_links`, belum kedaluwarsa) |
| Syarat | Pengajuan, persetujuan Kepatuhan, langganan | Tidak ada. Ini data nasabah itu sendiri |
| Jeda | Minimal 15 menit | Tidak ada, langsung |
| Isi | Per order saat selesai | Per kejadian trade match saja. Order ditolak, ditarik, atau di-amend tidak dikirim |
| Preferensi | Jenis notifikasi baru `trade_activity` | Preferensi push `olt.trade` yang sudah ada (jenis `olt.trade.*` sudah dipetakan ke sana sejak 0086/0087) |
| Tombol nyala | `trade_share.enabled` | Pengaturan terpisah `trade_notify.enabled` (bawaan **mati**), diatur Super Admin di Hub |

**Isi push:**

| Kejadian | Jenis push | Contoh |
|---|---|---|
| Trade match (`0x0024`) | `olt.trade.matched` | "Order beli BBCA match 5 lot @ 9.150" |

- **Lot** memakai `trade_share.lot_size` yang sama.
- **`collapse_key` per order**, supaya beberapa match dari satu order tidak menumpuk di layar. Notifikasi terbaru menggantikan yang lama di perangkat.
- **Ketuk notifikasi** membuka halaman daftar trade di aplikasi OLT, lewat data push `screen` yang diteruskan ke handler routing yang sudah ada, seperti payload notifEngine (`/trade-list`).
- **Idempoten.** Kunci yang sama dengan fill (`tradeDate`, `idxTradeId`, `custId`, `command`) dicatat sebagai tanda terima 7 hari, supaya kiriman ulang tidak dobel.
- **Isi tidak disimpan.** Server hanya menyimpan tanda terima dan penghitung. Isi trade nasabah yang bukan trader tidak disimpan di tabel mana pun.

**Dampak ke relay.** Daftar rekening yang diproses relay menjadi gabungan dua kelompok:
- rekening trader yang disetujui;
- bila `trade_notify.enabled` menyala, **semua rekening yang tertaut ke akun sosial dan belum kedaluwarsa**.

Daftar ini bisa berisi ratusan ribu rekening. Karena itu:
- daftar dikirim ke relay hanya bila keanggotaannya berubah, memakai nomor versi yang naik lewat trigger insert/delete di `private.account_links`, bukan setiap `seen_at` berubah;
- relay menyimpannya di memori sebagai set hash, sehingga pengecekan per paket tetap O(1);
- untuk rekening yang hanya ada di kelompok kedua, relay meneruskan **hanya** fill (trade match), bukan update order.

**Perlu dikoordinasikan dengan OLT.** notifEngine OLT saat ini sudah mengirim push "Trade Confirmation" langsung ke FCM. Bila `trade_notify.enabled` dinyalakan sementara notifEngine masih mengirim, nasabah menerima dua notifikasi untuk trade yang sama. Pilihannya: OLT mematikan push trade di notifEngine, atau `trade_notify.enabled` dibiarkan mati.

## 6. Aturan dan syarat

Semua angka di bawah adalah pengaturan `private.settings` yang bisa diubah dari Hub. Nilainya hanya bawaan.

### 6.1 Syarat trader

| Syarat | Bawaan | Pengaturan |
|---|---|---|
| Fitur aktif | — | `trade_share.enabled` |
| Profil bukan tamu dan bukan akun resmi | — | — |
| Punya minimal satu rekening tertaut yang belum kedaluwarsa | — | `integration.account_link_days` (sudah ada) |
| Umur profil minimal | 30 hari | `trade_share.min_account_age_days` |
| Tidak sedang dalam sanksi moderasi | — | — |
| Tidak dalam masa tunggu setelah ditolak atau dicabut | 30 hari | `trade_share.reapply_cooldown_days` |
| Rekening tidak ada di daftar rekening dikecualikan (karyawan, sales, afiliasi) | — | Dikelola Kepatuhan di Hub |
| Rekening hanya tertaut ke profil ini | — | — |

Pemeriksaan otomatis hanya mengurangi pengajuan yang pasti ditolak. Keputusan tetap di tangan reviewer.

### 6.2 Syarat pelanggan

| Syarat | Bawaan | Pengaturan |
|---|---|---|
| Fitur aktif dan trader berstatus `active` | — | — |
| Profil bukan tamu dan punya minimal satu rekening tertaut yang belum kedaluwarsa | — | — |
| Sudah mengikuti trader | — | — |
| Tidak saling memblokir dan tidak sedang dalam sanksi | — | — |
| Menyetujui pernyataan risiko versi terbaru | — | — |
| Batas jumlah trader yang dilanggan | 20 | `trade_share.max_subscriptions` |
| Tidak berlangganan diri sendiri | — | — |

### 6.3 Pengaturan trader

| Pengaturan | Bawaan | Batas |
|---|---|---|
| Rekening yang dibagikan | Semua rekening yang lolos syarat | Minimal satu |
| Tampilkan harga | Aktif | Bisa disembunyikan trader. Kalah oleh `trade_share.force_hide_price` |
| Tampilkan lot | Aktif | Bisa disembunyikan trader. Kalah oleh `trade_share.force_hide_lot` |
| Jeda | `trade_share.min_delay_minutes` (15) | Minimal sama dengan pengaturan server, maksimal 240 menit |
| Mode langganan | Otomatis | Otomatis atau perlu persetujuan |

- Mengubah tampil harga, tampil lot, atau rekening dianggap mengubah cakupan data. Trader mengonfirmasi ulang, perubahannya tercatat di audit, dan hanya berlaku untuk order berikutnya.
- Karena harga dan lot tampil secara bawaan, layar pengajuan menampilkan pratinjau notifikasi persis seperti yang akan dilihat pelanggan. S&K menjelaskan bahwa lot memperlihatkan besar posisi dan bisa menarik penipuan atau aksi ikut-ikutan.
- Bila Kepatuhan menaikkan jeda minimum, trader yang jedanya di bawah minimum otomatis ikut naik.

### 6.4 Aturan pengiriman

| Aturan | Bawaan | Pengaturan |
|---|---|---|
| Board yang dibagikan | `RG` | `trade_share.boards` |
| Saham dikecualikan | Kosong | Daftar di Hub, misalnya papan pemantauan khusus atau saham yang kena UMA |
| Interval flush | 30 detik | Jadwal cron |
| Sapuan akhir hari untuk order yang masih terisi sebagian | 16.30 WIB, hanya hari bursa | `trade_share.eod_flush_time` |
| Push gabungan per trader per pelanggan | Satu per putaran flush | — |
| Push trade maksimal per pelanggan per hari | 50 | `trade_share.daily_push_cap` (kotak notifikasi tetap terisi) |
| Masa simpan status order dan aktivitas | 30 hari | `trade_share.retention_days` |
| Jumlah lembar per lot | 100 | `trade_share.lot_size` |
| Kedaluwarsa permintaan langganan | 14 hari | `trade_share.request_expiry_days` |
| Ambang tinjauan pelanggan | 1.000 | `trade_share.review_subscriber_threshold` |

- Trade sesudah penutupan tetap terkirim setelah jedanya habis. Misalnya, trade jam 15.55 dengan jeda 15 menit terkirim 16.10.

### 6.5 Status

**Trader**

```
            ajukan                 setujui
  (none) ─────────▶ pending ─────────────────▶ active ◀──────┐
                       │ tolak                 │  │  │        │ lanjutkan (trader)
                       ▼                       │  │  └─jeda──▶ paused
                   rejected                    │  │
                  (masa tunggu)                │  └─tangguhkan─▶ suspended ──(berakhir / dicabut tangguh)──▶ active
                                               │
                                cabut / berhenti▼
                                            revoked / withdrawn
```

**Langganan**

```
  minta ─▶ pending ─setujui─▶ active ⇄ muted
             │ tolak/kedaluwarsa      │ berhenti / unfollow / blokir / trader dicabut
             ▼                        ▼
          declined / expired       ended
```

## 7. Relay (`services/trade-relay`)

### 7.1 Ringkas

- Bahasa Go, versi awal 0.1.0, container sendiri dengan subcommand `healthcheck`, port ops internal (`/livez`, `/readyz`, `/metrics`) seperti service lain.
- Sama seperti notifier dan janitor, relay memakai JWT secret Supabase (Docker secret yang sudah ada) untuk memanggil RPC service_role lewat PostgREST internal. Semua konfigurasi lain ditarik dari database dan dikelola di Hub.
- Heartbeat lewat `public.service_heartbeat('trade-relay', …)` seperti service lain, sehingga tampil di Kesehatan sistem.
- Tidak menulis isi paket, `custId`, harga, atau volume ke log maupun disk. Log hanya berisi penghitung dan kejadian koneksi.

### 7.2 Sumber data dan protokol

Semua isi bagian ini diambil dari source server OLT di `legacy/olt-service-all` (tidak di-commit, diabaikan git): `idx/clientOrdersRealtimeMME.cc` (acuan utama), `idx/IProxy.cc`, `inc/IPackage.h`, `libs/IPackage.cc`, `inc/IConstants.h`. Kunci dan kredensial yang tertanam di source tersebut **tidak** disalin ke repo, dokumen, atau log.

#### Jalur yang dipilih: DEALER ke iProxy, meniru `clientOrdersRealtimeMME`

Relay **tidak** subscribe ke publisher `clientOrdersRealtimeMME`. Relay meniru cara kerja `clientOrdersRealtimeMME` (fungsi `ZMQIProxyRealtimeThread`): terhubung langsung ke iProxy sebagai ZMQ **DEALER** dengan identity sendiri, menerima paket realtime order dan trade dalam format `CIPackage`, lalu memprosesnya sendiri.

| Hal | Perilaku `clientOrdersRealtimeMME` | Yang ditiru relay |
|---|---|---|
| Socket | `ZMQ_DEALER`, `zmq_connect` ke iProxy (bawaan `tcp://localhost:9990`, kunci `[iproxy] addr`) | Sama. Alamat diatur di Hub |
| Identity | `ZMQ_IDENTITY` dari `[iproxy] identity` (bawaan `realtime`) | Identity sendiri, usulan `social_trade_relay`. **Tidak boleh** sama dengan identity proses OLT mana pun, karena libzmq menolak identity ganda di ROUTER |
| HWM | RCVHWM dan SNDHWM 0 (tak terbatas) | RCVHWM dibatasi (bawaan 100.000) |
| Batas waktu terima | `ZMQ_RCVTIMEO` 500 ms | Sama |
| Heartbeat | Bila tidak ada paket lebih dari 4 detik, kirim `CIPackage` kosong `IPKG_HEART_BEAT` (`0xffff`) dengan cap waktu | Sama |
| Paket diterima | Ukuran minimal `IHEADER_LENGTH` (23), cek signature, dekripsi bila bertanda, dekompresi bila bertanda | Sama, ditambah decode ketat |
| Paket diproses | `IPKG_REP_NEW_ORDER` `0x0022`, `IPKG_REP_AMEND_ORDER` `0x0023`, `IPKG_REP_TRADE` `0x0024`, `IPKG_BROADCAST_LOGIN`, `IPKG_SPEED_ORDER_BOOK` | Hanya `0x0022`, `0x0023`, dan `0x0024`. Sisanya dibuang |

**Yang perlu dari OLT.** iProxy hanya `zmq_proxy` (ROUTER 9990 untuk klien ↔ DEALER 9991 untuk engine). Paket realtime dikirim engine OLT ke identity tujuan yang dikonfigurasi di sisi engine, dan paket ke identity yang tidak terhubung dibuang diam-diam. Jadi selain membuka port iProxy untuk IP server kita, OLT perlu memastikan engine pengirim realtime juga mengirim ke identity relay, sama seperti ke identity `realtime` milik `clientOrdersRealtimeMME`.

**Akibat yang diterima.** Relay menerima realtime order dan trade **semua nasabah** OLT, sama seperti `clientOrdersRealtimeMME`. Penyaringan ke rekening yang disetujui terjadi di memori relay. Paket rekening lain dibuang tanpa disimpan, tanpa log, dan tanpa metrik per rekening.

#### Header `CIPackage` (23 byte, `inc/IPackage.h`, `libs/IPackage.cc`)

| Offset | Isi |
|---|---|
| 0–3 | Signature `0x332fad12` |
| 4–7 | Panjang paket |
| 8–9 | Package id |
| 10–11 | Flag: bit 0 terenkripsi, bit 1 terkompresi, bit 2 prioritas, bit 3 paket bersambung, bit 4 protokol berubah |
| 12–13 | Error code |
| 14 | Source id |
| 15–18 | Tanggal paket YYYYMMDD |
| 19–22 | Jam paket HHMMSS |

- **Enkripsi (disiapkan, dipakai bila paket bertanda):** saat ini `CIPackage::EncryptPackage` dan `DecryptPackage` kosong di library server OLT, jadi paket di iProxy biasanya tidak dienkripsi. Relay tetap menyiapkan dekripsi untuk paket yang bit 0 flag-nya menyala, mengikuti `CMCrypt` (`libs/CMCrypt.cc`) yang dipakai `CGPackage::EncryptAES` / `DecryptAES` di OLT:
  - algoritme `rijndael-128` (AES dengan blok 16 byte) lewat libmcrypt;
  - kunci berupa string ASCII apa adanya, panjang kunci = panjang string (16 karakter berarti AES-128, 24 berarti AES-192, 32 berarti AES-256);
  - mode bawaan **ECB** (IV tidak dipakai). `CMCrypt` juga punya konstruktor dengan mode lain, jadi relay mendukung **CBC** dengan IV 16 byte bila mode itu yang dipakai;
  - padding nol ke kelipatan 16 byte, tanpa PKCS7;
  - layout: header, uint32 big-endian panjang asli (termasuk header), lalu ciphertext. Panjang ciphertext harus kelipatan 16 byte. Hasil dekripsi dipotong ke panjang asli.
- **Kunci, IV, dan mode** diatur Super Admin di Hub dan disimpan di Vault (bagian 8.3 dan 10.2), tidak di repo, dokumen, env, atau log. Bila paket bertanda terenkripsi datang saat kunci belum diatur, paket dibuang, dihitung `encrypted_no_key`, dan alert dibuka.
- **Terenkripsi dan terkompresi sekaligus:** di OLT, kompresi dilakukan lebih dulu, lalu enkripsi (`SendToZmq` di `clientOrdersRealtimeMME.cc`). Penerima OLT melakukan kebalikannya, yaitu dekripsi bila bertanda lalu dekompresi bila bertanda (`ZMQIProxyRealtimeThread` dan loop utama `clientOrdersRealtimeMME`). Relay memakai urutan yang sama: cek signature, dekripsi bila bit 0, lalu dekompresi bila bit 1. Setelah dekripsi, isi data kembali menjadi bentuk terkompresi (uint32 panjang asli + blok Snappy) bila bit 1 juga menyala.
- Layout enkripsi untuk header `CIPackage` 23 byte diasumsikan sama dengan `CGPackage` (offset dimulai setelah header). Ini dipastikan dengan frame contoh dari OLT begitu tersedia. Sampai saat itu, dekripsi diuji dengan frame buatan `dummy-iproxy` yang dienkripsi dengan algoritme yang sama.
- **Kompresi:** header 23 byte, uint32 big-endian panjang asli (termasuk header), lalu blok Snappy mentah (`snappy_compress` dari snappy-c, bukan format framed). Cocok dengan `snappy.Decode` dari `golang/snappy`.
- **Tipe data:** integer big-endian (`ntohs`, `ntohl`, `be64toh`). String: panjang uint16 lalu byte ASCII, di-trim.

#### Isi realtime order (`IPKG_REP_NEW_ORDER` dan `IPKG_REP_AMEND_ORDER`)

Urutan field sama dengan yang dibaca `ProcessBroadcastRealtimeIOrderReply` di `clientOrdersRealtimeMME.cc` dari paket iProxy:

`orderStatus` (uint8), `orderId`, `amendId`, `idxOrderId` (string), `orderDate`, `orderTime`, `sentTime` (uint32), `exchangeCode`, `board` (string), `expiry` (uint8), `custId`, `alt` (string), `nationality`, `command` (uint8), `stockcode` (string), `price` (uint32), `openVolume`, `remainVolume`, `tradedVolume` (uint64), `inputUser`, `counterPartyUid` (string), `sourceId`, `amendSourceId` (uint8), `complianceId`, `clientId` (string).

Catatan: parser Dart OLT (`StockRealtimeOrderModel`) membaca `sid` di posisi `complianceId`. Urutannya sama, hanya namanya berbeda.

| Field | Arti (dikonfirmasi pemilik produk 15 Nov 2026) |
|---|---|
| `price` | Harga order dalam rupiah, apa adanya |
| `openVolume`, `remainVolume`, `tradedVolume` | Dalam **lembar**. Lot = lembar ÷ `trade_share.lot_size` (bawaan 100) |
| `custId` | Sama dengan isi klaim `accounts` token sosial. Rekening ganda per profil sudah ditangani `private.account_links` |
| `command` | `0` beli, `1` jual, `2` beli margin, `3` short sell (`IConstants.h`). Genap berarti beli, ganjil berarti jual |
| `board` | String `RG`, `TN`, `NG`, `ADV` |
| `sourceId` | Kode perangkat berupa integer: `4` web, `5` desktop, `6` Android phone, `7` Android tablet, `8` iPhone, `9` iPad. Tidak dipakai untuk menyaring dan tidak diteruskan |

| `orderStatus` (`IConstants.h`) | Arti | Dipakai untuk |
|---|---|---|
| 0 | Rejected | Order tidak pernah dibagikan |
| 1 | Open | Masih berjalan. Bila `tradedVolume` lebih dari 0 berarti terisi sebagian |
| 2 | Matched | Ada match. **Tidak selalu penuh**: penuh hanya bila `remainVolume` 0. Bila sisa lebih dari 0, order masih berjalan |
| 3 | Amending | Abaikan, tunggu hasil amend |
| 4 | Withdrawing | Abaikan, tunggu hasil penarikan |
| 5 | Withdrawn | Selesai. Bila `tradedVolume` lebih dari 0 berarti selesai sebagian |
| 6 | Amended | Perbarui harga dan volume order |

Field yang **langsung dibuang** di memori relay dan tidak pernah disimpan: `idxOrderId`, `alt`, `nationality`, `inputUser`, `counterPartyUid`, `sourceId`, `amendSourceId`, `complianceId`, `clientId`.

#### Isi realtime trade (`IPKG_REP_TRADE`)

Urutan field sama dengan yang dibaca `ProcessBroadcastRealtimeITradeReply` di `clientOrdersRealtimeMME.cc`:

`orderId`, `idxOrderId`, `idxTradeId` (string), `tradeDate` (YYYYMMDD), `tradeTime` (HHMMSS) (uint32), `exchangeCode`, `board` (string), `expiry` (uint8), `custId`, `alt` (string), `nationality`, `command` (uint8), `stockcode` (string), `price` (uint32), `volume` (uint64), `counterPartyUid` (string), `sourceId` (uint8).

- `price` adalah harga match dalam rupiah, `volume` dalam lembar.
- `orderId` + `custId` dipakai untuk mencocokkan trade dengan ordernya.
- Field yang **langsung dibuang** di memori relay: `idxOrderId`, `exchangeCode`, `expiry`, `alt`, `nationality`, `counterPartyUid`, `sourceId`. `idxTradeId` hanya dipakai untuk kunci idempoten lalu dibuang.

**Perbedaan sengaja dengan parser OLT.** Parser Dart dan C++ mengembalikan `0` atau string kosong bila buffer kurang. Relay **menolak** frame seperti itu (`decode_error`) agar frame rusak tidak menjadi order atau trade palsu.

### 7.3 Data yang diteruskan

Satu **update order** per paket `0x0022` / `0x0023` yang lolos saring:

| Field | Selalu | Keterangan |
|---|---|---|
| `cust_id` | Ya | Dinormalisasi sama dengan `private.integration_cust_id` (huruf besar, trim) |
| `order_ref` | Ya | SHA-256 dari `orderId` + `custId`. `orderId` mentah tidak dikirim |
| `seq` | Ya | SHA-256 dari `orderId`, `orderStatus`, `price`, `remainVolume`, `tradedVolume`, sama dengan penentuan duplikat di klien OLT |
| `status` | Ya | `rejected`, `open`, `matched`, `amending`, `withdrawing`, `withdrawn`, `amended` |
| `stock`, `side`, `board` | Ya | `side` dari `command`, `board` untuk pemeriksaan ulang di server |
| `order_date` | Ya | Untuk sapuan akhir hari |
| `order_shares`, `remain_shares`, `traded_shares` | Ya | Dalam lembar. Dipakai server untuk menentukan selesai atau sebagian. Angka lot hanya **ditampilkan** bila trader membukanya |
| `order_price` | Bila trader membuka harga | Rupiah |

Satu **fill** per paket `0x0024` yang lolos saring:

| Field | Selalu | Keterangan |
|---|---|---|
| `key` | Ya | SHA-256 dari `tradeDate`, `idxTradeId`, `custId`, `command`. Satu trade antara dua nasabah OLT menghasilkan dua paket dengan `custId` berbeda, jadi `custId` dan sisi ikut dalam kunci |
| `cust_id`, `order_ref`, `stock`, `side`, `board` | Ya | Sama seperti update order |
| `traded_at` | Ya | Dari `tradeDate` + `tradeTime`, zona WIB |
| `shares` | Ya | Dalam lembar |
| `price` | Bila trader membuka harga | Harga match, rupiah |

**Tidak pernah diteruskan:** `orderId` dan `idxTradeId` mentah, `amendId`, `idxOrderId`, `exchangeCode`, `expiry`, `alt`, `nationality`, `inputUser`, `counterPartyUid`, `sourceId`, `amendSourceId`, `complianceId`, `clientId`.

### 7.4 Kontrak dengan database

RPC `security definer` yang hanya bisa dipanggil `service_role`, lewat PostgREST internal (`http://rest:3000`).

| RPC | Isi |
|---|---|
| `trade_relay_config(p_known_version)` | Versi config, `enabled`, alamat iProxy, identity, interval heartbeat, kunci, IV, dan mode AES bila diatur (dari Vault), `reconnect_generation`, `restart_generation`, daftar rekening aktif + izin harga/lot + board yang dibagikan. Bila `p_known_version` sama dengan versi saat ini, hanya generation dan `enabled` yang dikembalikan |
| `trade_relay_events(p_instance, p_events)` | Batch 1–500 update order dan fill, berurutan sesuai kedatangan. Jawaban per event: `accepted`, `duplicate`, `dropped` + alasan, `invalid` |
| `trade_relay_status(p_instance, p_status)` | Versi relay, status koneksi ZMQ, waktu paket terakhir, penghitung (diterima, trade, cocok, diteruskan, decode error, dibuang per alasan), error terakhir (tanpa isi paket), generation yang sudah dijalankan |

### 7.5 Perilaku

| Hal | Perilaku |
|---|---|
| Tarik config | Setiap 15 detik. Perubahan alamat atau identity membuat relay menyambung ulang. Perubahan daftar rekening langsung dipakai tanpa memutus koneksi |
| Fitur dimatikan (`enabled=false`) | Relay tetap terhubung untuk status, tetapi tidak meneruskan apa pun. Daftar rekening dikosongkan dari memori |
| Database tidak terjangkau | Update order ditahan di antrean memori terbatas (bawaan 10.000) lalu dikirim ulang dengan backoff. Saat penuh, yang tertua dibuang dan dihitung `buffer_overflow`. Tidak ada penyimpanan ke disk |
| Membaca iProxy | Selalu secepatnya, lalu memproses di goroutine terpisah, supaya antrean iProxy untuk identity ini tidak menumpuk (iProxy memakai HWM 0) |
| RCVHWM | Diberi batas (bawaan 100.000) |
| Heartbeat dan putus | Heartbeat `IPKG_HEART_BEAT` setiap 4 detik saat sepi seperti `clientOrdersRealtimeMME`. Reconnect otomatis oleh ZMQ. Di jam bursa, bila tidak ada paket realtime sama sekali selama 5 menit, socket ditutup lalu dibuka lagi dan alert `trade_relay:silent` dibuka |
| Watchdog | Bila loop utama macet lebih dari 60 detik, proses keluar sendiri dan Docker menjalankannya lagi (`restart: unless-stopped`) |
| Status | Dikirim setiap 30 detik dan segera setelah kejadian penting (terhubung, putus, perintah dijalankan) |
| Healthcheck | Gagal bila watchdog macet atau config tidak berhasil ditarik lebih dari 5 menit |

### 7.6 Perintah dari Hub (sambung ulang dan restart)

Tidak ada akses ke Docker socket dari web, karena memberi web hak atas Docker terlalu besar risikonya. Healer yang sudah ada tetap memegang Docker socket, tetapi hanya untuk restart otomatis container yang unhealthy. Perintah manual dari Hub dijalankan oleh relay sendiri:

1. Staf berizin menekan **Sambung ulang** atau **Restart** di Hub dan wajib mengisi alasan. Ada konfirmasi dan batas satu perintah per menit.
2. `cs_api.trade_relay_command(action, reason)` menaikkan `reconnect_generation` atau `restart_generation` dan mencatatnya di audit.
3. Pada tarikan config berikutnya (maksimal 15 detik):
   - **Sambung ulang**: relay menutup socket ZMQ, memuat ulang config, lalu menyambung lagi tanpa keluar proses;
   - **Restart**: relay melaporkan bahwa perintah diterima, mengirim sisa antrean (maksimal 5 detik), lalu keluar. Docker langsung menjalankannya lagi.
4. Setelah berjalan lagi, relay melaporkan generation yang sudah dijalankan, dan Hub menampilkan "Selesai" beserta waktunya.

Batasnya: bila proses relay macet total dan tidak menarik config, perintah dari web tidak sampai. Untuk kasus itu ada watchdog internal (bagian 7.5), dan healer me-restart container bila healthcheck-nya unhealthy.

### 7.7 Dependensi baru (disetujui 15 Nov 2026)

| Dependensi | Alasan |
|---|---|
| `github.com/pebbe/zmq4` + libzmq di image | Memakai libzmq yang sama dengan iProxy OLT, jadi paling kecil risiko beda perilaku. Image memakai base dengan libzmq, bukan distroless static |
| `github.com/golang/snappy` | Dekompresi blok Snappy mentah (format snappy-c, sudah dipastikan dari source) |

Dekripsi AES (ECB dan CBC) memakai `crypto/aes` dan `crypto/cipher` bawaan Go, tanpa dependensi tambahan. Selebihnya Go standard library.

## 8. Database

Migrasi baru berurutan **0160–0164**, tes pgTAP **137–141**. Migrasi lama tidak diubah. Definisi fungsi yang diganti diambil dari migrasi terbaru (cari tanpa membedakan huruf besar-kecil). Semua file `.sql` berakhiran LF.

### 8.1 0160 — inti trader

| Objek | Isi |
|---|---|
| Pengaturan | Semua `trade_share.*` di bagian 6, plus `trade_share.enabled` (bawaan **false**) dan `trade_share.four_eyes` (bawaan false) |
| `private.trade_sharers` | Satu baris per profil: status, tampil harga, tampil lot, jeda, mode langganan, versi dan waktu persetujuan S&K, waktu pengajuan, keputusan (oleh, waktu, alasan, pengusul untuk empat mata), batas penangguhan, masa tunggu |
| `private.trade_sharer_accounts` | (profil, `cust_id`) yang dibagikan, beserta status per rekening (`active`, `blocked_shared`, `expired`) |
| `private.trade_share_events` | Riwayat semua perubahan status dan pengaturan (siapa, kapan, dari, ke, alasan). Sumber jejak audit untuk Kepatuhan |
| `private.trade_share_excluded_accounts` | Rekening karyawan, sales, atau afiliasi yang tidak boleh dibagikan. Dikelola Kepatuhan |
| RPC aplikasi | `get_trade_share_status` (termasuk `eligibility`), `submit_trade_share_application`, `update_trade_share_settings`, `pause_trade_share`, `resume_trade_share`, `withdraw_trade_share` |
| RPC Hub | `cs_api.trade_share_applications`, `cs_api.trade_share_detail`, `cs_api.trade_share_decide` (setujui / tolak, mendukung empat mata), `cs_api.trade_share_suspend`, `cs_api.trade_share_revoke`, `cs_api.trade_share_reinstate`, `cs_api.trade_share_excluded_accounts_*` |
| Pemicu | Saat `account_links` berubah: tandai rekening yang tidak tertaut lagi, tertaut ke profil kedua, atau kedaluwarsa, lalu jeda trader otomatis bila tidak ada rekening tersisa |

### 8.2 0161 — langganan

| Objek | Isi |
|---|---|
| `private.trade_subscriptions` | (pelanggan, trader), status, dibisukan, versi pernyataan risiko, waktu minta, waktu diputuskan, kedaluwarsa |
| RPC aplikasi | `request_trade_subscription`, `cancel_trade_subscription`, `mute_trade_subscription`, `my_trade_subscriptions`, `my_trade_subscribers` (khusus trader), `decide_trade_subscription` (trader menyetujui / menolak), `remove_trade_subscriber` |
| Pemicu | Unfollow, blokir, hapus akun, dan pencabutan trader mengakhiri langganan |
| RPC Hub | `cs_api.trade_share_subscribers` (daftar pelanggan per trader, hanya untuk staf berizin) |

Jumlah pelanggan **tidak** ditampilkan ke publik. Trader melihat daftar dan jumlahnya, Kepatuhan melihat semuanya.

### 8.3 0162 — relay dan penerimaan update order

| Objek | Isi |
|---|---|
| `private.trade_relay_config` | Satu baris: alamat iProxy, identity, interval heartbeat, mode AES (`ecb` / `cbc`), `secret_id` kunci dan IV di Vault, `reconnect_generation`, `restart_generation`, versi config, diubah oleh dan kapan |
| Kunci dan IV AES | Disimpan di Vault (`trade_relay.aes_key`, `trade_relay.aes_iv`) dengan pola kunci Firebase (0059). Hanya bisa ditulis dari Hub dan tidak pernah ditampilkan lagi. Hub hanya menampilkan sidik jari (SHA-256, 8 karakter pertama), panjang kunci, mode, dan waktu ubah. Hanya `trade_relay_config` (service_role) yang membaca nilainya |
| `private.trade_relay_status` | Status terakhir per instance relay |
| `private.trade_orders` | Satu baris per order (`order_ref`): trader, `cust_id`, saham, sisi, board, tanggal order, expiry, status versi aktif, jumlah amend, harga order (nullable), volume order, sisa, volume match, `seq` terakhir, volume match dari fill, harga rata-rata match, waktu fill terakhir, volume yang sudah dilaporkan, status pelaporan (`pending`, `reported`, `partial_reported`, `cancelled`) |
| `private.trade_fills` | Fill yang diterima: kunci idempoten (unik), `order_ref`, waktu trade, harga match (nullable), lembar |
| `private.trade_relay_daily` | Penghitung harian (diterima, duplikat, dibuang per alasan), disimpan 400 hari seperti `integration_daily` |
| RPC relay | `trade_relay_config`, `trade_relay_events`, `trade_relay_status` (hanya service_role, bagian 7.4) |
| RPC Hub | `cs_api.trade_relay_get`, `cs_api.trade_relay_update` (audit diff, khusus Super Admin), `cs_api.trade_relay_set_key`, `cs_api.trade_relay_command`, `cs_api.trade_relay_status` |

### 8.4 0163 — pengiriman

| Objek | Isi |
|---|---|
| `private.trade_activities` | Aktivitas: trader, saham, sisi, lot match dan lot order (nullable), harga order dan harga rata-rata match (nullable), penanda sebagian, jumlah fill, waktu order, waktu selesai, waktu kirim |
| `private.trade_fanout_jobs` | Job fan-out per putaran flush per trader (kursor pelanggan, penghitung terkirim, push, dilewati preferensi, kena batas harian) |
| Cron `trade-share-flush` | Setiap 30 detik: ambil order yang sudah selesai dan jedanya habis, buat aktivitas dan job, proses batch fan-out |
| Notifikasi | Jenis kotak notifikasi `trade_activity`, jenis push `trade_activity` dengan pemetaan preferensi baru di `push_allowed` (bawaan aktif, bisa dimatikan pengguna), `collapse_key` per trader |
| RPC aplikasi | `trade_activity_feed` (aktivitas dari trader yang dilanggan, berhalaman), `trade_activity_detail` |

### 8.5 0164 — Kepatuhan, pemantauan, dan pemeliharaan

| Objek | Isi |
|---|---|
| `private.trade_share_excluded_stocks` | Saham dikecualikan beserta alasan dan masa berlaku |
| Penanda pemantauan | Ditulis ke tabel penanda baru yang tampil di Hub (bisa juga ke `cs.manipulation_alerts` yang sudah ada bila Kepatuhan ingin satu antrean): pelanggan melonjak (misalnya naik lebih dari 3 kali dalam 7 hari), melewati ambang tinjauan, pola beli lalu jual cepat (kurang dari 60 menit) di saham tidak likuid, banyak trade di saham yang kemudian dikecualikan, rekening tertaut ke profil kedua |
| Dasbor | `cs_api.trade_share_dashboard`: jumlah trader aktif, pelanggan, aktivitas per hari, notifikasi terkirim, update order dibuang per alasan, kesehatan relay |
| Ekspor | `cs_api.trade_share_export` (CSV) untuk pemeriksaan Kepatuhan, tercatat di audit |
| Tombol darurat | `cs_api.trade_share_update_setting('trade_share.enabled', 'false', reason)`, ditambah trigger `cs_settings_trade_share_kill_switch`: saat dimatikan, semua order yang belum dilaporkan menjadi `cancelled` dan job fan-out berhenti seketika. Tercatat di audit |
| Alert (sentinel) | `trade_relay:down` (tidak ada status lebih dari 2 menit saat fitur aktif), `trade_relay:disconnected` (ZMQ putus lebih dari 1 menit di jam bursa), `trade_relay:silent` (tidak ada paket trade sama sekali selama 30 menit di jam bursa, memakai kalender `cs.holidays`), `trade_relay:decode_errors` (lonjakan frame rusak), `trade_relay:overflow` (antrean relay meluap) |
| `export_my_data` | Ditambah bagian berbagi trade: pengaturan, riwayat status, langganan, dan aktivitas milik sendiri |
| Hapus akun | Data fitur ini ikut terhapus (cascade dan pemicu, pola janitor dan `account_links_forget` yang sudah ada) |
| Cron pemeliharaan | Hapus status order dan aktivitas lebih dari `trade_share.retention_days`, kedaluwarsakan permintaan langganan, akhiri penangguhan yang lewat batas, bersihkan job selesai |

### 8.6 Keamanan data

- Semua tabel di skema `private` dengan RLS aktif. Akses hanya lewat RPC `security definer` dengan `search_path = ''`.
- Aplikasi hanya melihat data milik sendiri, data trader yang dilanggan, dan aktivitas yang memang sudah dikirim kepadanya.
- Update order yang dibuang tidak disimpan isinya, hanya penghitung alasan.
- `cust_id` tidak pernah dikirim ke aplikasi pelanggan.

## 9. Library `rendezvous_community` (1.28.0)

Rilis terakhir saat rencana ini disetujui adalah v1.27.0. Bila ada rilis lain sebelum fitur ini selesai, versinya menjadi minor berikutnya saat itu.

### 9.1 Status fitur

- `CommunityTradeShareRepository.status()` mengembalikan apakah fitur aktif dan status trader saat ini.
- Seluruh UI fitur ini tersembunyi bila fitur mati. Tidak ada rilis ulang aplikasi OLT yang diperlukan untuk mematikan atau menyalakan.
- Status disimpan sebentar (cache 5 menit) dan disegarkan saat aplikasi kembali ke depan.

### 9.2 Modul dan widget

| Bagian | Isi |
|---|---|
| Modul `trade_share` (data, domain, presentation per fitur) | Repository, entity, cubit untuk pengajuan, pengaturan, langganan, dan aktivitas |
| `CommunityTradeSharePage` | Status, syarat, pilih rekening, tampil harga / lot, jeda, mode langganan, S&K, tombol Ajukan / Jeda / Lanjutkan / Berhenti |
| Tanda dan lonceng di profil | Tanda "Membagikan trade". Lonceng dengan status Berlangganan / Menunggu persetujuan / Tidak tersedia, serta lembar pernyataan risiko |
| `CommunityTradeSubscriptionsPage` | Trader yang dilanggan, bisukan, berhenti |
| `CommunityTradeSubscribersPage` (trader) | Permintaan masuk, pelanggan aktif, keluarkan pelanggan |
| Item notifikasi `trade_activity` | Teks sesuai field yang dibuka, disclaimer di detail, ketuk membuka saham lewat callback `onStockTap` yang sudah ada |
| Filter **Trade** di pusat notifikasi | Memisahkan notifikasi trade dari interaksi sosial |
| Payload push | Jenis `trade_activity` diteruskan ke handler routing yang sudah ada |
| L10n | Indonesia dan Inggris |
| Ikon | Lewat `CommunityStyle.icons`, ditambah ikon untuk lonceng trade |

### 9.3 Aturan kode

- Tanpa komentar, tanpa dependensi baru, dan log lewat logger library.
- Tes repository, cubit, dan widget untuk setiap alur. Dokumentasi di `README.md`, `doc/integration.md`, dan `CHANGELOG.md`.

### 9.4 Yang perlu dilakukan aplikasi OLT

1. Naikkan ke `ref: v1.28.0`.
2. Pasang `CommunityTradeSharePage` di menu pengaturan dan halaman langganan di menu yang dipilih OLT. Tanda dan lonceng di profil sudah otomatis.
3. Pastikan callback buka saham sudah diteruskan (sudah dipakai untuk cashtag).

Tidak ada perubahan backend OLT.

## 10. Hub `rendezvous_hub`

### 10.1 Menu Kepatuhan → Berbagi Trade

| Tab | Isi |
|---|---|
| Pengajuan | Antrean pending dengan ringkasan peninjauan (bagian 5.2). Setujui, tolak dengan alasan, dan antrean usulan bila empat mata aktif |
| Trader | Daftar trader per status, detail pengaturan, rekening, jumlah pelanggan, riwayat. Aksi: tangguhkan (dengan batas waktu opsional), cabut, aktifkan kembali |
| Pelanggan | Daftar pelanggan per trader (baca saja) |
| Pemantauan | Dasbor dan penanda (bagian 8.5), tandai sudah ditinjau dengan catatan |
| Daftar | Saham dikecualikan dan rekening dikecualikan |
| Pengaturan | Tombol darurat, jeda minimum, paksa tutup harga / lot, board, batas-batas, empat mata, ambang tinjauan |
| Jejak audit | Semua keputusan dan perubahan pengaturan, bisa diekspor |

Syarat & Ketentuan Berbagi Trade dan pernyataan risiko dikelola di menu dokumen hukum yang sudah ada, sebagai dua jenis dokumen baru.

### 10.2 Menu Sistem → Relay Trade

| Bagian | Isi | Izin |
|---|---|---|
| Status | Terhubung / putus, versi, instance, waktu paket terakhir, penghitung per menit, error terakhir, waktu status terakhir | Lihat: Super Admin dan pemegang izin operasi relay |
| Perintah | Tombol Sambung ulang dan Restart dengan alasan wajib, konfirmasi, batas satu per menit, dan status "Menunggu / Selesai" | Super Admin dan pemegang izin `trade_relay.operate` |
| Konfigurasi | Alamat iProxy, identity, interval heartbeat. Perubahan tercatat dengan diff | Super Admin |
| Enkripsi AES | Isi atau ganti kunci dan IV (tulis saja, tidak bisa dibaca kembali), pilih mode `ecb` atau `cbc`, hapus. Tampil sidik jari, panjang kunci, mode, dan waktu ubah. Validasi panjang kunci 16, 24, atau 32 karakter dan IV 16 karakter | Super Admin |
| Riwayat | Perintah dan perubahan konfigurasi | Super Admin |

Relay juga tampil di **Kesehatan sistem** yang sudah ada (heartbeat, restart otomatis healer, alert).

### 10.3 Izin staf baru

| Izin | Untuk |
|---|---|
| `trade_share.review` | Meninjau pengajuan, menangguhkan, mencabut, mengaktifkan kembali, meninjau penanda |
| `trade_share.manage` | Pengaturan, tombol darurat, daftar dikecualikan, ekspor |
| `trade_relay.operate` | Melihat status relay dan menjalankan Sambung ulang / Restart. Cocok untuk staf IT jaga yang bukan Super Admin |

## 11. Deployment dan operasional

### 11.1 Container

| File | Isi |
|---|---|
| `services/trade-relay/Dockerfile` | Build Go, image runtime dengan libzmq, user nonroot, `HEALTHCHECK` lewat subcommand |
| `docker/compose.yml` | Service `trade-relay`: `restart: unless-stopped`, label `olt.autoheal=true`, secret JWT yang sudah ada, healthcheck, batas memori. Ikut dijalankan `make up` seperti service lain |
| `docker/compose.prod.yml` / `docker/stack.cluster.yml` | Satu replika saja. Dua relay akan menerima paket yang sama dan hanya mengandalkan idempotensi |
| `docker/compose.dummy-olt.yml` | Ditambah `dummy-iproxy` untuk dev, dan relay dev diarahkan ke dummy itu |
| `docker/.env.example` | Variabel relay (tanpa nilai rahasia) |

Fitur bawaannya mati (`trade_share.enabled=false`), dan relay yang belum dikonfigurasi alamat iProxy-nya di Hub hanya diam dan melaporkan status `not_configured`. Jadi menambahkan service ini ke compose aman untuk server yang belum memakai fitur ini.

### 11.2 Konfigurasi relay (env)

Hanya yang diperlukan untuk menghubungi database. Alamat iProxy, identity, dan pengaturan AES diatur di Hub.

| Variabel | Bawaan | Keterangan |
|---|---|---|
| `POSTGREST_URL` | `http://rest:3000` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Sama dengan service internal lain |
| `INSTANCE_ID` | hostname | Nama instance di heartbeat dan status |
| `CONFIG_INTERVAL` | `15s` | |
| `STATUS_INTERVAL` | `30s` | |
| `BUFFER_SIZE` | `10000` | Antrean update order dan fill di memori |
| `ZMQ_HWM` | `100000` | |
| `WATCHDOG_TIMEOUT` | `60s` | |
| `LOG_LEVEL` | `info` | |

### 11.3 Runbook (ditulis di `docs/berbagi-trade/operasional.md` saat pengerjaan)

- Permintaan ke OLT: buka port iProxy untuk IP server kita dan arahkan realtime ke identity relay.
- Mengisi alamat iProxy dan identity di Hub, serta kunci, IV, dan mode AES bila OLT mengaktifkan enkripsi.
- Rotasi kunci AES: isi kunci baru di Hub, relay memakainya pada tarikan config berikutnya.
- Arti setiap alert dan langkahnya.
- Sambung ulang dan restart dari Hub, serta `docker compose restart trade-relay` di server bila Hub tidak bisa dipakai.
- Mematikan fitur sementara (tombol darurat) dan permanen (matikan fitur, hapus data, copot relay).

### 11.4 Pensiun permanen

1. Matikan tombol darurat. UI hilang, notifikasi berhenti.
2. Kosongkan alamat iProxy di Hub. Relay memutus koneksi dan diam.
3. Minta OLT menutup kembali port iProxy untuk server kita dan menghapus identity relay dari tujuan realtime.
4. Data terhapus sendiri oleh masa simpan, atau langsung lewat aksi "Hapus seluruh data berbagi trade" di Pengaturan (Super Admin, konfirmasi ganda, tercatat).
5. Opsional, service relay dihapus dari compose pada rilis berikutnya.

Tidak ada yang dipasang di sistem OLT, jadi tidak ada sisa di sana selain aturan firewall yang ditutup kembali.

## 12. Pengujian

| Lapisan | Pengujian |
|---|---|
| Relay | Unit test decode dari **golden frame** (sementara frame buatan `dummy-iproxy`, frame UAT OLT menyusul), fuzz test parser bawaan Go (frame acak tidak boleh panik dan tidak boleh menghasilkan update order atau fill), tes dekripsi (ECB, CBC, kunci 16/24/32, tanpa kunci), tes dekompresi, tes paket terenkripsi sekaligus terkompresi, tes saring dan minimisasi field, tes antrean penuh, tes generation sambung ulang / restart, tes watchdog |
| Database (pgTAP 137–141) | Syarat dan pengajuan, empat mata, semua transisi status, langganan dan pemicu (unfollow, blokir, hapus akun), pemeriksaan ulang update order (rekening tertaut ganda, kedaluwarsa, saham dikecualikan, board), idempotensi, buang harga / lot sesuai pengaturan dan paksa tutup, seluruh tabel transisi bagian 5.4.1 termasuk paket tidak berurutan, volume match tidak pernah turun, `matched` dengan sisa lebih dari 0, amend setelah match sebagian, penggabungan order dan fill, fill datang sebelum order, perubahan setelah dilaporkan, order terlewat, fill terlewat, status matched dengan sisa dianggap sebagian, jeda, sapuan akhir hari, konversi lot dengan `lot_size`, fan-out dan batas harian, tombol darurat membatalkan order yang belum dilaporkan, RLS dan hak akses, `export_my_data`, masa simpan |
| Keamanan | `make test-security` tanpa temuan |
| Library | Tes repository, cubit, widget untuk semua alur. CI lengkap: komentar, logging, format, analyze, tes, lisensi |
| Hub | Tes komponen dan logika setiap tab, izin per peran |
| End-to-end dev | `dummy-iproxy` mengirim order dan trade sintetis (match penuh, beberapa trade sebagian dengan order tetap open lalu penuh, sebagian lalu withdrawn, sebagian masih open saat sapuan akhir hari, amend di tengah match, trade datang sebelum order, rejected, trade antara dua nasabah, rekening yang tidak disetujui, frame rusak, frame terkompresi) → relay → database → notifikasi dan push di aplikasi contoh. Dipastikan satu order hanya menghasilkan satu notifikasi dan label "sebagian" benar |
| Beban | Simulasi pembukaan pasar (misalnya 20.000 paket trade per menit dengan 1% rekening disetujui) untuk memastikan relay tidak tertinggal dan flush tetap di bawah 30 detik |
| UAT bersama OLT | Relay terhubung ke iProxy UAT OLT dengan identity sendiri, dipastikan `clientOrdersRealtimeMME`, websocket, dan notifEngine OLT tetap normal, serta notifikasi order penuh, sebagian, ditarik, dan amend sesuai kenyataan |

## 13. Yang perlu didapat dari OLT

Sebagian besar sudah terjawab dari source OLT (bagian 7.2).

**Sudah terjawab dari source:**

| Hal | Jawaban |
|---|---|
| Cara menerima | DEALER ke iProxy dengan identity sendiri, meniru `clientOrdersRealtimeMME` |
| Header, signature, package id | `CIPackage` 23 byte, signature `0x332fad12`, order `0x0022` / `0x0023`, trade `0x0024`, heartbeat `0xffff` |
| Enkripsi | Biasanya tidak ada di jalur iProxy. Dekripsi `CMCrypt` (rijndael-128, ECB bawaan, CBC opsional, padding nol) tetap disiapkan untuk paket bertanda |
| Kompresi | Blok Snappy mentah setelah header + panjang asli |
| Isi paket order dan trade, `orderStatus`, `command`, `board` | Bagian 7.2 |
| Heartbeat | Relay mengirim `IPKG_HEART_BEAT` setiap 4 detik saat sepi |

**Masih perlu dari OLT:**

| No | Kebutuhan | Dipakai untuk | Status |
|---|---|---|---|
| 1 | Membuka port iProxy di produksi dan UAT khusus untuk IP server kita (allowlist firewall). Bila jalurnya melewati internet, tunnel VPN site-to-site atau WireGuard | Koneksi dan keamanan jaringan | Ditunda. Selama pengembangan memakai `dummy-iproxy` |
| 2 | Mengarahkan realtime order ke identity relay (usulan `social_trade_relay`), sama seperti ke identity `realtime` milik `clientOrdersRealtimeMME` | Relay menerima paket | Bersamaan dengan nomor 1 |
| 3 | Beberapa frame contoh dari UAT (order baru, sebagian, matched, withdrawn, amend) | Golden test dengan data produksi. Sementara ini sudah ada golden test dari frame yang dihasilkan kode C++ OLT asli (`CIPackage`, Snappy, `CMCrypt`), termasuk heartbeat yang identik byte per byte | Ditunda. Sementara golden test memakai frame buatan `dummy-iproxy` |

**Sudah dijawab pemilik produk (15 Nov 2026):** harga apa adanya dalam rupiah, volume dalam lembar (lot dibagi `trade_share.lot_size`, bawaan 100), `sourceId` berupa kode perangkat integer, format `custId` sama dengan token sosial, status matched bisa sebagian, GTC tidak perlu ditangani, lot dan harga order diambil dari paket order, saat match sebagian order tetap open sehingga volume match diambil dari paket trade, tidak ada paket koreksi trade. Mekanisme dekripsi AES tetap disiapkan untuk paket yang bertanda terenkripsi (bagian 7.2). Nilai kunci dan IV tidak ditulis di repo atau dokumen. Super Admin memasukkannya sendiri di Hub, dan nilainya disimpan di Vault.

## 14. Keputusan Kepatuhan (diisi rekomendasi, 15 Nov 2026)

Pemilik produk meminta semua poin memakai rekomendasi terbaik. Semua angka bisa diubah dari Hub tanpa migrasi baru, jadi keputusan ini tidak menghambat pengerjaan. Poin 1 dan 2 tetap dikonfirmasi ke Kepatuhan sekuritas sebelum tahap pilot.

| No | Hal | Keputusan |
|---|---|---|
| 1 | Persetujuan fitur dan pelaporan ke OJK atau BEI | Dibawa ke Kepatuhan sekuritas sebelum pilot. Tidak menghambat pengerjaan karena fitur bawaannya mati |
| 2 | S&K Berbagi Trade dan pernyataan risiko pelanggan | Kita siapkan draf teks Indonesia dan Inggris saat tahap Hub, dimuat sebagai dokumen hukum yang bisa diedit Kepatuhan di Hub |
| 3 | Jeda minimum | 15 menit, trader boleh memilih lebih lama sampai 240 menit |
| 4 | Harga dan lot | Boleh tampil. **Bawaan tampil**, trader bisa menyembunyikan masing-masing, Kepatuhan bisa memaksa sembunyi untuk semua |
| 5 | Board | Hanya pasar reguler `RG` |
| 6 | Sumber order (`sourceId`) | Semua sumber ikut dibagikan, karena persetujuan berlaku per rekening. `sourceId` hanya kode perangkat dan tidak dipakai untuk menyaring |
| 7 | Rekening karyawan, sales, afiliasi | Tidak boleh dibagikan. Daftar rekening dikecualikan dikelola Kepatuhan di Hub. Akun resmi tidak bisa mengajukan |
| 8 | Empat mata | Mati di awal, bisa dinyalakan dari Hub |
| 9 | Ambang tinjauan dan penanda | Ambang 1.000 pelanggan. Penanda: pelanggan naik lebih dari 3 kali dalam 7 hari, beli lalu jual kurang dari 60 menit di saham tidak likuid, rekening tertaut ke profil kedua |
| 10 | Masa simpan dan ekspor | 30 hari, ekspor CSV tersedia untuk Kepatuhan dan tercatat di audit |

## 15. Tahapan pengerjaan

Setiap tahap selesai dengan tes hijau sebelum tahap berikutnya. Commit dan push hanya atas permintaan.

**Aturan cabang (permintaan pemilik produk 15 Nov 2026).** Posisi `main` saat ini adalah versi stabil yang sedang berjalan. Selama fitur ini dikerjakan:

- semua pekerjaan dilakukan di cabang `feat/berbagi-trade` di ketiga repo (server, library, Hub);
- **tidak ada merge atau push ke `main`** sampai pemilik produk menyatakan fitur siap;
- library tidak diberi tag rilis dari cabang ini sebelum diizinkan, supaya OLT tetap memakai versi stabil.

**Backup sebelum mulai (dibuat 15 Nov 2026).**

| Repo | Tag lokal `backup/2026-11-15-pre-berbagi-trade` |
|---|---|
| `chat_service_supabase` | `main` 1a3c466 |
| `rendezvous_community` | `main` 0f92833 (v1.27.0) |
| `rendezvous_hub` | `main` 1f9f8ab |

Bundle git lengkap (semua cabang dan tag) tersimpan di `D:/My Developments/Golang/_backup/2026-11-15-pre-berbagi-trade/`. Bundle ini lokal dan tidak boleh dibagikan, karena bundle server ikut memuat cabang lokal lama yang berisi file legacy dengan kredensial. Bila ada commit baru di `main` sebelum pengerjaan dimulai, backup dibuat ulang tepat sebelum tahap 1.

Format protokol sudah diketahui dari source OLT (bagian 7.2), jadi decoder relay dan iProxy tiruan (`dummy-iproxy`) bisa dikerjakan tanpa menunggu OLT. Yang masih menunggu OLT hanya pembukaan port, pengarahan realtime ke identity relay, dan frame contoh untuk golden test. Pengujian ujung ke ujung juga bisa memakai alat dev yang memanggil `trade_relay_events` langsung (tanpa ZMQ).

| Tahap | Pekerjaan | Bergantung pada |
|---|---|---|
| 1 | Database 0160–0161 + tes 137–138: trader, pengajuan, langganan | Dokumen ini (sudah disetujui) |
| 2 | Database 0162 + tes 139: config relay, status order, status relay, perintah. Alat dev pengirim event | Tahap 1 |
| 3 | Database 0163–0164 + tes 140–141: penentuan order selesai atau sebagian, sapuan akhir hari, jeda, penggabungan, fan-out, notifikasi, Kepatuhan, alert, pemeliharaan | Tahap 2 |
| 4 | Hub: menu Kepatuhan dan menu Sistem, izin staf, draf S&K dan pernyataan risiko | Tahap 1–3 |
| 5 | Library 1.28.0 | Tahap 1–3 |
| 6 | End-to-end dev dengan alat pengirim update order, dokumentasi operasional | Tahap 4 dan 5 |
| 7 | Relay: decoder `CIPackage`, AES, Snappy, paket order dan trade, fuzz test. `dummy-iproxy` | Tahap 2 (tidak menunggu OLT) |
| 8 | Relay lengkap: koneksi DEALER, heartbeat, saring per rekening, antrean, perintah, watchdog, status. End-to-end lewat `dummy-iproxy`, uji beban | Tahap 7 |
| 9 | Golden test dengan frame asli, lalu UAT bersama OLT (tombol darurat mati untuk publik, diuji dengan akun internal) | Tahap 8 + bahan OLT nomor 1–3 |
| 10 | Pilot: tombol darurat dinyalakan, pengajuan hanya untuk daftar nasabah yang diundang Kepatuhan | Tahap 9 + konfirmasi Kepatuhan poin 1–2 |
| 11 | Rilis umum | Evaluasi pilot |

Untuk tahap 10, pengaturan tambahan `trade_share.pilot_only` (bawaan true) membatasi pengajuan ke daftar profil undangan yang dikelola di Hub. Pengaturan ini dibuat di 0160.

## 16. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Fitur dipakai untuk pump and dump | Jeda minimum, beli dan jual wajib dibagikan, saham dikecualikan, penanda pola beli-jual cepat, peninjauan pengajuan, tombol darurat |
| Kebocoran data transaksi nasabah yang tidak setuju | Port iProxy hanya untuk IP server kita (plus tunnel bila lewat internet), saring di memori relay tanpa disimpan, pemeriksaan ulang di database, rekening tertaut ganda diblokir, field minimal, tanpa log isi |
| Relay membebani iProxy atau mengganggu proses OLT lain | Identity sendiri, selalu membaca secepatnya, RCVHWM terbatas, UAT memastikan `clientOrdersRealtimeMME` dan notifEngine normal, tombol darurat dan perintah dari Hub |
| Notifikasi tidak sesuai kenyataan karena match sebagian | Satu notifikasi per order saat order selesai, volume match dari paket trade karena order tetap open saat sebagian, lot dan harga order dari paket order, sapuan akhir hari |
| Kunci AES bocor | Disimpan di Vault, tulis saja dari Hub, hanya dibaca RPC service_role di jaringan internal, tidak ditulis ke disk atau log relay, bisa dirotasi |
| Frame rusak menjadi trade palsu | Decoder ketat, fuzz test, golden test, penghitung decode error dengan alert |
| Banjir notifikasi | Gabungan per order dan per putaran, batas harian, bisukan per trader, preferensi push, batas langganan |
| Trader berpengaruh dianggap memberi rekomendasi | S&K, disclaimer, tanpa imbalan, tanpa statistik kinerja, tinjauan pada ambang pelanggan |
| Relay macet dan tidak bisa dijangkau dari Hub | Watchdog internal, `restart: unless-stopped`, healer, alert `trade_relay:down` |
| Lonjakan beban saat pembukaan pasar | Saring di memori relay sebelum menyentuh database, batch, fan-out berkursor, batas memori container, uji beban |
| Koneksi keluar ke OLT mengganggu server kita | Hanya relay yang terhubung. Putus atau macet tidak memengaruhi service lain, dan relay bisa dimatikan dari Hub |
