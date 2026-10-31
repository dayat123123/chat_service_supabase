# Addendum 3 (Revisi): Customer Service via Chat + Matching Engine — Rendezvous OLT

> **Dokumen ini MENGGANTIKAN `docs/PROMPT-CUSTOMER-CARE.md`.** Pendekatan ticketing/helpdesk di dokumen itu **dibatalkan**.
> Simpan file ini sebagai `docs/PROMPT-CS-CHAT.md`. Dokumen lain (`PROMPT.md`, `PROMPT-PRODUCTION.md`, `PROMPT-FEATURES.md`) tetap berlaku.
> Bagian bertanda `[...]` silakan disesuaikan.

---

## 0. Konsep

Customer service di OLT adalah **chat dua arah** antara nasabah dan CS, **memakai fitur chat yang sudah dibangun** (`chat_rooms`, `messages`, Realtime Broadcast, presence, typing, lampiran, cache offline). Bentuknya bukan sistem tiket atau helpdesk terpisah.

Bagian baru yang dibangun:
1. **Room bertipe `support`**: setiap nasabah punya **satu room CS permanen** (seperti chat WhatsApp dengan akun resmi), sehingga riwayat percakapan selalu menyambung.
2. **Sesi CS (`support_sessions`)**: setiap kali nasabah butuh bantuan, dibuat satu sesi di dalam room tersebut. Sesi berstatus: antre → ditawarkan ke agen → aktif → selesai.
3. **Matching engine**: menentukan **agen CS mana** yang menangani sesi berdasarkan topik, keahlian, ketersediaan, beban, bahasa, prioritas, dan riwayat.
4. **Panel CS**: aplikasi chat untuk agen dan supervisor, memakai **widget chat yang sama** dari `rendezvous_community`.

**Prinsip:**
- Maksimalkan pemakaian ulang kode chat yang ada. Jangan membuat sistem pesan kedua.
- Semua aturan sebelumnya tetap berlaku: Docker, stateless, siap multi-node, RLS, rate limit, keamanan, moderasi, dan isolasi dari fitur trading.
- Sederhana untuk nasabah: tekan **"Chat CS"**, pilih topik, lalu langsung chat.

---

## 1. Pengalaman Nasabah (di aplikasi OLT)

### 1.1 Memulai chat
1. Tombol **"Chat CS"** tersedia di menu bantuan dan di layar penting (order, deposit/tarik dana, portofolio). Kalau dibuka dari layar tertentu, topik dan konteks terisi otomatis.
2. Nasabah memilih **topik singkat** (satu layar, maksimal `[6–8]` pilihan), misalnya: Akun & Login, Deposit/Tarik Dana, Order & Transaksi, Portofolio & Aksi Korporasi, Aplikasi/Teknis, Laporkan Penipuan, Lainnya.
3. Opsional: **lampirkan konteks** dengan sekali ketuk, misalnya memilih order atau transaksi dari daftar OLT nasabah. Hasilnya dikirim sebagai **kartu** di chat, jadi nasabah tidak perlu mengetik ulang.
4. Nasabah langsung masuk ke **room CS** dan bisa mengetik pesan pertama sambil menunggu agen.

### 1.2 Selama menunggu
- Pesan sistem menampilkan **posisi antrean** dan **perkiraan waktu tunggu**, diperbarui realtime.
- Pesan otomatis pertama (dapat dikonfigurasi):
  - Salam.
  - Pengingat keamanan: *"CS kami tidak pernah meminta PIN, password, atau OTP."*
  - Tautan bantuan singkat yang relevan dengan topik.
- **Di luar jam layanan** `[jam layanan]`: nasabah tetap bisa mengirim pesan. Muncul info "CS akan membalas mulai [waktu buka berikutnya]", dan sesi otomatis masuk antrean saat jam layanan dimulai.

### 1.3 Saat terhubung dengan agen
- Pesan sistem: "Anda terhubung dengan **[nama panggilan agen]** – CS Resmi". Agen tampil dengan **badge "CS Resmi"** yang tidak bisa ditiru akun lain.
- Fitur chat penuh: teks, gambar/screenshot, kartu order/saham, typing indicator, status terkirim/dibaca, balas pesan, dan cache offline.
- Agen bisa mengirim **pesan khusus**:
  - **Tombol pilihan cepat** (misalnya "Sudah", "Belum").
  - **Permintaan konfirmasi identitas** yang disetujui nasabah di aplikasi OLT (PIN/biometrik diproses OLT, **bukan** diketik di chat).
  - Tautan artikel bantuan.
  - Kartu order dari OLT.
- **Deteksi data sensitif**: kalau nasabah mengetik sesuatu yang mirip OTP, PIN, password, nomor kartu, atau rekening lengkap, aplikasi memperingatkan sebelum kirim. Kalau tetap terkirim, data tersebut dimasking di server sebelum disimpan dan ditampilkan.

### 1.4 Setelah selesai
- Agen menutup sesi. Nasabah melihat pesan "Sesi selesai" dan **rating 1–5** dengan komentar opsional.
- Room tetap ada beserta riwayatnya. Kalau nasabah mengetik lagi:
  - Dalam `[30 menit]`, sesi yang sama **dibuka kembali** ke agen yang sama bila masih online.
  - Setelah itu, sesi baru dibuat dan masuk matching (agen sebelumnya diutamakan, lihat 3.3).
- Nasabah bisa menandai **"Saya ingin mengajukan pengaduan"**. Sesi diberi flag `complaint` dan diarahkan ke agen dengan skill pengaduan (lihat 6).
- Notifikasi push (Android) dan notifikasi Windows untuk setiap balasan agen saat aplikasi tidak dibuka.

---

## 2. Model Data (memperluas chat yang ada)

Migrasi baru. **Jangan mengubah migrasi lama.** Semua tabel ber-RLS.

**Memperluas tabel yang ada:**
- `chat_rooms.type` ditambah nilai `support`, dengan constraint **satu room `support` per nasabah**.
- `messages`:
  - Tambah `kind` (`text`, `system`, `card`, `quick_reply`, `identity_request`, `csat`, dan seterusnya) bila belum ada.
  - Tambah `session_id` (nullable) untuk mengelompokkan pesan per sesi CS.
  - Pesan dari agen ditandai `sender_role = 'agent'`.

**Tabel baru (schema `cs`):**

| Tabel | Isi utama |
|---|---|
| `agents` | `user_id` (akun staf), nama panggilan, kode agen, bahasa, `max_concurrent`, tim, aktif/nonaktif |
| `agent_skills` | agen, topik/skill, level (1–3) |
| `agent_status` | status (`online` / `busy` / `break` / `offline`), alasan, `active_sessions`, `last_assigned_at`, `last_heartbeat_at` |
| `support_topics` | kode, nama ID/EN, skill yang dibutuhkan, prioritas default, urutan tampil, aktif |
| `support_sessions` | `room_id`, nasabah, topik, prioritas, flag (`complaint`, `fraud`, `vip`), status, agen saat ini, waktu (masuk antrean, ditawarkan, diterima, respons pertama, selesai), jumlah transfer, alasan penutupan, tag, rating |
| `session_events` | log append-only: masuk antrean, ditawarkan ke X, ditolak/timeout, diterima, transfer, tutup, buka kembali |
| `match_offers` | sesi, agen, waktu tawar, kedaluwarsa, hasil (`accepted` / `rejected` / `expired`) |
| `agent_notes` | catatan internal per sesi atau per nasabah. **Tabel terpisah dari `messages`**, supaya tidak mungkin bocor ke nasabah lewat RLS atau Realtime |
| `quick_replies` | balasan cepat (pribadi / tim / global) dengan variabel `{nama}`, `{agen}` |
| `cs_settings` | jam layanan, hari libur, bobot matching, timeout, pesan otomatis (berversi) |
| `cs_audit_log` | append-only: semua aksi agen dan supervisor, termasuk membuka profil nasabah |

**Status sesi** (state machine ditegakkan di server):
`queued` → `offered` → `active` → `closed`, ditambah `transferring` (kembali ke `queued` dengan target tim/agen) dan `reopened` (dari `closed` dalam batas waktu). Sesi `closed` tanpa aktivitas lebih dari `[30 menit]` menjadi final.

**RLS:**
- Nasabah hanya bisa membaca room `support` miliknya dan pesan **publik** di dalamnya.
- Agen bisa membaca room `support` yang **saat ini atau pernah** ditanganinya `[atau seluruh riwayat nasabah yang sedang ditanganinya — tentukan]`.
- Supervisor bisa membaca semua room `support`.
- `agent_notes` **tidak pernah** bisa diakses nasabah.
- Agen ditambahkan ke `chat_members` room saat sesi diterima, dan aksesnya dicabut saat sesi ditransfer atau ditutup. Riwayat tetap bisa dibaca sesuai aturan di atas.

---

## 3. Matching Engine

### 3.1 Bentuk
- Service **`cs-matcher`** (Dockerized, **stateless**, bisa banyak replika).
- **Pemicu** (event-driven), plus **sweep berkala** setiap `[2–5 detik]` sebagai jaring pengaman:
  - Sesi baru masuk antrean.
  - Agen berubah ke `online` atau kapasitasnya bertambah karena sesi ditutup.
  - Penawaran ditolak atau kedaluwarsa.
  - Transfer.
- Event diterima lewat Postgres `LISTEN/NOTIFY` atau Realtime Broadcast internal.
- **Atomik & aman multi-replika**:
  - Pengambilan sesi antrean memakai `SELECT ... FOR UPDATE SKIP LOCKED`.
  - Slot agen dikunci (`FOR UPDATE` pada `agent_status`) di dalam **satu transaksi**, sehingga satu sesi tidak pernah ditawarkan ke dua agen, dan kapasitas agen tidak pernah terlampaui.
  - Alternatifnya, logika inti dibuat sebagai fungsi Postgres `cs.match_next()` yang dipanggil service. Pilih yang paling sederhana dan teruji, lalu jelaskan alasannya.

### 3.2 Urutan antrean
Sesi diurutkan berdasarkan **skor prioritas efektif**:

```
skor_antre = bobot_prioritas[prioritas] + bobot_flag + (lama_menunggu_detik × faktor_aging)
```

- Prioritas: `P1` (fraud / dugaan peretasan / tidak bisa transaksi di jam bursa), `P2` (complaint, masalah dana), `P3` (normal), dan `P4` (umum).
- **Aging** memastikan sesi prioritas rendah tetap terlayani dan tidak menunggu selamanya (*no starvation*).
- Prioritas awal ditentukan dari topik, flag, kata kunci di pesan pertama (misalnya "dibobol", "tidak dikenal", "penipuan"), dan jam bursa. Semua aturannya bisa dikonfigurasi.

### 3.3 Memilih agen
**Langkah 1: saring agen yang layak**
- Status `online`, heartbeat masih segar (< `[30 detik]`), dan `active_sessions < max_concurrent`.
- Punya skill untuk topik sesi, dan bahasa yang cocok.
- Tidak sedang menolak atau timeout untuk sesi yang sama.
- Untuk flag `complaint` / `fraud`, hanya agen dengan skill tersebut.

**Langkah 2: beri skor setiap agen** (bobot dapat dikonfigurasi dari panel):

```
skor_agen = w_skill    × level_skill_untuk_topik
          + w_sticky   × (agen ini menangani nasabah ini dalam [48 jam] terakhir ? 1 : 0)
          + w_beban    × (1 − active_sessions / max_concurrent)
          + w_idle     × normalisasi(waktu sejak terakhir ditugaskan)
          + w_vip      × (nasabah VIP & agen ditandai untuk VIP ? 1 : 0)
```

Pilih skor tertinggi. Kalau skornya sama, pilih yang paling lama tidak ditugaskan (adil antar agen).

**Langkah 3: pelebaran bertahap** (kalau tidak ada agen layak)
- Setelah menunggu `[X menit]`: izinkan agen dengan skill level lebih rendah atau tim umum.
- Setelah `[Y menit]`: beri peringatan ke supervisor.
- Kategori `fraud` / P1: langsung alert supervisor dan on-call, tanpa menunggu.

### 3.4 Mode penugasan (per tim, dapat dikonfigurasi)
- **Offer–accept** (default): sesi ditawarkan ke agen terpilih dengan notifikasi + suara di panel.
  - Agen punya **`[30 detik]`** untuk menerima.
  - Kalau ditolak atau habis waktu, sesi ditawarkan ke agen berikutnya, dan kejadiannya tercatat di metrik agen.
  - Kalau agen timeout `[2]` kali berturut-turut, statusnya otomatis menjadi `break`, supaya sesi tidak terus ditawarkan ke agen yang sedang tidak di tempat.
- **Auto-assign**: sesi langsung masuk ke agen terpilih tanpa konfirmasi.

### 3.5 Transfer & intervensi
- Agen bisa **transfer** ke tim lain (masuk matching ulang dengan topik/skill baru) atau langsung ke agen tertentu yang online, beserta **catatan serah terima** (masuk `agent_notes`).
  - Nasabah melihat pesan sistem "Anda dialihkan ke tim [X]".
  - Riwayat chat tetap utuh.
- **Supervisor** bisa:
  - Memindahkan sesi ke agen lain.
  - **Memantau** chat aktif (hanya baca).
  - **Bergabung** ke chat (ditandai sebagai Supervisor).
  - Mengubah prioritas.
  - Mengambil alih sesi.
- Kalau agen **logout atau koneksinya putus** (heartbeat hilang lebih dari `[60 detik]`), sesi aktifnya dikembalikan ke antrean dengan prioritas tinggi, dan nasabah diberi tahu bahwa ia sedang dihubungkan ke CS lain.

### 3.6 Perkiraan waktu tunggu
- Dihitung dari rata-rata waktu tunggu `[30 menit]` terakhir per topik, jumlah antrean di depan, dan kapasitas agen online.
- Ditampilkan sebagai rentang yang jujur, misalnya "± 2–4 menit", dan diperbarui ke nasabah lewat pesan sistem / Realtime.

### 3.7 Pengujian matching (wajib)
- Unit test fungsi skor dan penyaringan.
- **Tes konkurensi**: banyak replika `cs-matcher` + ratusan sesi + puluhan agen secara bersamaan.
  - Tidak boleh ada sesi ganda, kapasitas terlampaui, atau sesi yang terlewat.
- Tes skenario:
  - Agen timeout.
  - Agen putus koneksi di tengah chat.
  - Transfer.
  - Buka kembali dalam 30 menit.
  - Di luar jam layanan.
  - Pelebaran skill.
  - Aging (sesi P4 akhirnya terlayani).
- **Simulator**: script yang membangkitkan nasabah dan agen palsu untuk menguji beban dan melihat metrik matching di Grafana.

---

## 4. Panel CS (Agent Console)

Dibangun sebagai **Flutter web** (`apps/cs-console`), memakai widget chat dari `rendezvous_community`, dan hanya bisa diakses lewat **VPN + akun staf dengan 2FA**. Bisa digabung dengan panel admin/moderasi (`apps/admin`) sebagai menu terpisah sesuai role. Pilih yang paling rapi dan jelaskan alasannya.

### 4.1 Tampilan agen
- **Bar atas**:
  - Tombol status (Online / Istirahat / Offline, dengan alasan).
  - Jumlah chat aktif / kapasitas, misalnya `2/3`.
  - Lonceng notifikasi.
- **Kolom kiri: daftar chat**:
  - Chat aktif saya, dengan badge pesan belum dibaca, waktu tunggu sejak pesan terakhir nasabah (warna kuning/merah jika lama), topik, dan flag.
  - Penawaran masuk dengan **hitung mundur** dan tombol Terima/Tolak.
  - Riwayat chat yang saya tutup hari ini.
- **Tengah: jendela chat**:
  - Widget chat yang sama dengan nasabah, ditambah fitur khusus agen:
    - **Quick reply** lewat ketik `/` lalu pilih, dengan variabel otomatis.
    - Kirim tombol pilihan.
    - Kirim permintaan konfirmasi identitas.
    - Kirim kartu order.
    - Tautan bantuan.
  - Tab **Catatan internal**, ditampilkan dengan warna berbeda dan label jelas "Tidak terlihat nasabah".
  - **Pemeriksaan sebelum kirim**: pesan agen yang meminta OTP, PIN, atau password **diblokir** dan supervisor diberi peringatan.
  - Tombol **Transfer**, **Tutup sesi** (wajib pilih tag/hasil: selesai, perlu tindak lanjut, pengaduan, dan lainnya), dan **Tandai pengaduan**.
- **Kolom kanan: info nasabah**:
  - Nama panggilan, kode nasabah, dan status akun, **dengan masking** (NIK, rekening, email, dan HP dimasking). Tombol "Tampilkan" membuka satu field sementara setelah agen memilih alasan, dan tercatat di audit log.
  - **Data OLT hanya-baca** dari `customer-adapter` (lihat 5), dimuat saat dibuka: order terakhir, transaksi dana terakhir, perangkat & sesi login, dan status keamanan akun.
  - Riwayat sesi CS sebelumnya beserta rating.
  - Catatan internal tentang nasabah (persisten antar sesi).
- **Notifikasi**: suara dan notifikasi browser untuk penawaran baru dan pesan nasabah, termasuk saat tab tidak aktif.
- **Shortcut keyboard**: terima penawaran, pindah antar chat, quick reply, dan tutup sesi.
- Satu agen bisa menangani **beberapa chat sekaligus** sesuai `max_concurrent`.

### 4.2 Tampilan supervisor
- **Dashboard realtime**:
  - Jumlah antrean per topik dan prioritas, serta waktu tunggu terlama.
  - Agen online, istirahat, dan beban masing-masing.
  - Chat aktif.
  - Sesi P1 / fraud / pengaduan yang perlu perhatian.
- Aksi:
  - Pantau, gabung, atau ambil alih chat.
  - Pindahkan sesi.
  - Ubah status agen.
  - Ubah prioritas.
- **Laporan** (harian/mingguan, per agen/topik):
  - Jumlah sesi dan waktu tunggu (median, p90).
  - Waktu respons pertama dan durasi sesi.
  - Tingkat transfer, tingkat penawaran ditolak/timeout, dan rating rata-rata.
  - Topik terbanyak.
  - Ekspor CSV/XLSX.

### 4.3 Pengaturan (role `cs_admin`)
- Agen: tambah/nonaktifkan, tim, skill & level, bahasa, kapasitas, dan penanda VIP. Menonaktifkan agen langsung mencabut sesi aktifnya dan mengembalikan sesinya ke antrean.
- Topik & mapping topik → skill → prioritas default.
- **Bobot dan parameter matching** (3.3–3.4), dengan nilai default yang aman dan tombol "kembalikan ke default".
- Jam layanan dan hari libur (libur nasional, cuti bersama, libur bursa).
- Pesan otomatis (salam, antrean, di luar jam, penutup) dalam ID/EN.
- Quick reply global/tim.

Semua perubahan pengaturan berversi dan tercatat di audit log.

### 4.4 Role

| Role | Akses |
|---|---|
| `cs_agent` | Chat yang ditugaskan, info nasabah ber-masking, catatan, quick reply pribadi |
| `cs_supervisor` | Semua chat & antrean, intervensi, laporan, quick reply tim |
| `cs_admin` | Pengaturan agen, topik, matching, jam layanan |
| `compliance` | Baca semua sesi berflag `complaint`/`fraud`, audit log, dan ekspor |

Semua dicek di server (RLS + fungsi), bukan hanya di UI.

---

## 5. Integrasi OLT (`customer-adapter`)

- Service **stateless & Dockerized**, atau modul di `market-adapter`. Fungsinya mengambil data nasabah dari OLT secara **hanya-baca**: profil, order terakhir, transaksi dana, perangkat/sesi, dan status keamanan.
- Sumber data: `[jelaskan: WebSocket OLT / GRPC ClientEngine / API internal, format & autentikasi service-to-service]`.
- Setiap akses mencatat agen, sesi, data yang diakses, dan waktunya di `cs_audit_log`.
- Agen **tidak bisa** bertransaksi atau mengubah data nasabah dari panel.
- Satu-satunya aksi ke OLT yang diizinkan adalah **permintaan konfirmasi identitas** (disetujui nasabah di aplikasi) dan **"Amankan akun"** untuk laporan peretasan `[sesuai kemampuan OLT: logout semua perangkat / kunci sementara]`.
- **Mode mock** untuk development.

---

## 6. Keamanan, Moderasi & Kepatuhan (versi ringkas)

- **Anti CS palsu**:
  - Hanya akun agen di tabel `agents` yang mendapat badge "CS Resmi".
  - Di fitur sosial, akun atau pesan yang mengaku CS diblokir oleh `moderation`.
  - Tombol **"Laporkan CS palsu"** di room CS membuat sesi `fraud` prioritas P1.
- **Masking otomatis** pola sensitif (OTP, PIN, kartu, rekening, NIK) di pesan nasabah maupun agen sebelum disimpan.
- **Lampiran** memakai jalur upload yang sama: validasi, hapus EXIF, dan pemindaian `moderation`. Disimpan di bucket privat dengan signed URL berumur pendek.
- **Pengaduan**: sesi berflag `complaint` mencatat waktu pengaduan diterima, dan dashboard menampilkan **hitung mundur hari kerja** sesuai ketentuan pengaduan OJK `[konfirmasi angka dengan tim kepatuhan, umumnya 5 hari kerja untuk lisan dan 10 hari kerja untuk tertulis, dapat diperpanjang dengan pemberitahuan]`. Transkrip bisa diekspor ke PDF bernomor. **Cukup ini dulu. Tidak perlu sistem ticketing.**
- **Retensi**: riwayat chat CS disimpan `[X tahun]` sesuai kebijakan sekuritas dan tidak terhapus saat nasabah menghapus akun, sejauh diwajibkan regulasi.
- **Audit log** append-only untuk semua aksi agen/supervisor/admin.
- **Rate limit**: nasabah `[30]` pesan/menit dan `[5]` sesi baru/jam. Panel dibatasi jumlah profil yang dibuka per jam per agen (deteksi anomali).

---

## 7. Non-Fungsional

- Realtime memakai topik privat `cs:room:<id>`, `cs:agent:<id>` (penawaran & notifikasi), dan `cs:queue` (dashboard supervisor). Database tetap sumber kebenaran, dan client sinkron ulang setelah reconnect.
- **Presence agen** memakai heartbeat Realtime + `agent_status` di database, sehingga tetap akurat di multi-node.
- Target waktu: penawaran sampai ke agen < `[1 detik]` setelah sesi masuk antrean (jika ada agen layak), dan pesan sampai < `[500 ms]` p95.
- Metrik Prometheus:
  - Panjang antrean, waktu tunggu, dan waktu matching.
  - Penawaran ditolak/timeout.
  - Agen online.
  - Sesi aktif.

  Alert untuk antrean menumpuk, sesi P1 menunggu lebih dari `[2 menit]`, dan `cs-matcher` mati.
- Kalau `cs-matcher` mati, sesi tetap tersimpan di antrean dan diproses begitu service kembali. Tidak boleh ada sesi hilang.

---

## 8. Tahapan

1. **CS1: Fondasi**
   - Migrasi (perluasan chat + schema `cs`), state machine sesi, RLS, `agent_notes` terpisah, audit log, dan `customer-adapter` mode mock.
   - Kriteria selesai: tes RLS lulus, terutama catatan internal tidak bisa bocor ke nasabah.
2. **CS2: Matching engine**
   - `cs-matcher`, antrean berprioritas + aging, skor agen, offer–accept, pelebaran, transfer, penanganan agen putus, estimasi waktu tunggu, dan simulator.
   - Kriteria selesai: semua tes di 3.7 lulus, termasuk tes konkurensi multi-replika.
3. **CS3: Aplikasi nasabah**
   - Tombol Chat CS, pilih topik, kartu konteks, antrean & ETA, room CS (memakai widget chat yang ada), rating, buka kembali, notifikasi, dan laporkan CS palsu. Berjalan di Windows & Android.
4. **CS4: Panel agen**
   - Daftar chat, penawaran dengan hitung mundur, multi-chat, quick reply, catatan internal, info nasabah ber-masking, transfer, dan tutup sesi.
5. **CS5: Supervisor & admin**
   - Dashboard realtime, intervensi, laporan, pengaturan agen/topik/matching/jam layanan, dan hitung mundur pengaduan + ekspor transkrip PDF.

Setiap tahap: berhenti, ringkas hasilnya, lalu tunggu konfirmasi saya.

---

## 9. Instruksi Pembersihan (wajib dibaca dulu)

Jika sebelumnya sudah ada pekerjaan berdasarkan `docs/PROMPT-CUSTOMER-CARE.md` (ticketing, helpdesk, schema `care`, package `olt_care`, dan seterusnya):
1. **Audit dulu**: daftar semua file, migrasi, tabel, service, dan package yang sudah dibuat dari dokumen itu.
2. Kelompokkan menjadi:
   - **Bisa dipakai ulang** di desain baru (misalnya kalender hari libur, masking data sensitif, `customer-adapter`, audit log, role staf).
   - **Harus diubah**.
   - **Harus dihapus**.
3. **Jangan menghapus atau me-rollback apa pun sebelum saya setujui.** Migrasi yang sudah terlanjur dijalankan dibatalkan lewat **migrasi baru** (bukan dengan mengedit atau menghapus migrasi lama).
4. Pindahkan `docs/PROMPT-CUSTOMER-CARE.md` ke `docs/archive/` dan tandai sebagai **dibatalkan**.

Setelah itu, tunggu konfirmasi saya sebelum mulai CS1.
