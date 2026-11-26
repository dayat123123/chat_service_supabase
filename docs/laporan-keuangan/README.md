# Riset laporan keuangan emiten

Ringkasan laporan keuangan emiten dibuat otomatis dari file XBRL bursa, lalu diposting ke Stream oleh akun resmi setelah disetujui staf. Tidak ada AI di dalamnya: angka diambil dari XBRL, dihitung dengan rumus tetap, dan disusun dengan template per sektor. Hasilnya sama untuk file yang sama dan bisa diperiksa ulang.

| | |
|---|---|
| Layanan | `finreport` (Go, `services/finreport`), satu container terpisah |
| Pintu masuk | `POST /integration/v1/financial-reports` (API key izin **Kirim laporan keuangan**) dan unggah di Hub |
| Data | Tabel `private.finreport_files`, `private.finreport_reports`, `private.finreport_config`; file asli di bucket `financial-reports` |
| Postingan | `cs.community_posts` status `pending`, disetujui staf lain di **Komunitas → Postingan resmi** (empat mata) |
| Tersedia sejak | Server migrasi `0197`, layanan `finreport` 0.1.0 |
| Panduan API | [../integration/laporan-keuangan.md](../integration/laporan-keuangan.md) |

## 1. Alur

```
Sistem pengirim ─┐
  (POST zip)     │  finreport API: cek key, izin, batas, ukuran, isi zip
                 ├─▶ simpan zip ke bucket financial-reports ─▶ finreport_files (queued)
Hub (unggah) ────┘                                                │
                                                                   ▼
                                    finreport worker (satu file sekali jalan)
                                    unduh ─ sidik SHA-256 ─ ClamAV ─ buka zip aman ─ urai XBRL
                                    ambil laporan pembanding ─ hitung ─ susun ringkasan
                                                                   │
                                                                   ▼
                              finreport_reports + postingan resmi (pending) ─▶ disetujui ─▶ Stream
```

1. File masuk dari API atau Hub dan dicatat sebagai `queued`. Pengirim API langsung mendapat `id` untuk mengecek status.
2. Worker mengklaim satu file, mengunduhnya, mengecek sidik SHA-256 dan antivirus, membuka zip dengan batas ketat, lalu mengurai `instance.xbrl`.
3. Identitas laporan (kode emiten, periode, jenis audit, mata uang) dibaca dari isi XBRL, bukan dari nama file.
4. Worker mengambil laporan pembanding yang sudah tersimpan: laporan kumulatif sebelumnya di tahun buku yang sama dan laporan periode yang sama tahun lalu.
5. Angka dan rasio dihitung, ringkasan disusun, lalu semuanya disimpan dalam satu transaksi bersama postingan resmi berstatus `pending`.
6. Staf lain menyetujui di Hub. Postingan memakai cashtag (`$BBCA`), jadi ikut tampil di stream saham itu.

## 2. Keputusan desain

| Keputusan | Alasan |
|---|---|
| Layanan baru `finreport`, bukan menambah `integration` | Layanan `integration` melayani notifikasi transaksi dan bot. Unggahan dan penguraian XBRL dipisah ke container sendiri supaya tidak bisa menghabiskan slot, memori, atau CPU layanan itu. Kong mengarahkan `/integration/v1/financial-reports` ke `finreport`; rute lain tetap ke `integration`, yang kodenya tidak berubah |
| Key integrasi yang sama, izin baru `financial_report` | Pengirim cukup satu jenis key yang dikelola di **API Integrasi**. Key notifikasi tidak bisa mengirim laporan dan sebaliknya |
| Format masuk: `instance.zip` dari IDX apa adanya | Sudah terstruktur, angka per akun, dan pembanding tahun lalu ada di file yang sama. Format JSON baru ditambahkan bila ada sumber yang tidak memberi XBRL |
| File asli disimpan di storage, bukan di database | Database hanya menyimpan angka hasil urai (`jsonb`, ±50 KB per laporan). File asli tetap ada untuk diurai ulang bila template diperbaiki |
| Tanpa unduh otomatis dari situs IDX | Situs IDX memblokir skrip dengan proteksi Cloudflare. Menembusnya melanggar aturan situs dan rapuh. Data masuk dari sistem yang memang punya filenya (lewat API) atau dari staf (lewat Hub) |
| Postingan selalu `pending` lebih dulu | Konten keuangan yang salah angka berisiko tinggi. Posting otomatis tanpa persetujuan bisa dinyalakan Super Admin, dan hanya berlaku untuk laporan tanpa peringatan |
| Pembanding laba rugi dari laporan terbaru | Emiten bisa mereklasifikasi angka tahun lalu (contoh: BBCA Q3 2026). Angka pembanding di laporan terbaru selalu dipakai; perbedaan dengan laporan lama dicatat sebagai peringatan `restated` |
| Kuartal tunggal dihitung dari selisih kumulatif | Laba rugi XBRL kumulatif sejak awal tahun buku. Kuartal III = 9 bulan − 6 bulan. Tanpa ini, perbandingan kumulatif bisa menyesatkan |
| Template dipilih dari akun yang ada di file | Bank dikenali dari pos bunga dan kredit, perusahaan umum dari pos penjualan. Selain itu memakai template dasar dengan peringatan. Lebih tahan perubahan label sektor |
| Izin Hub memakai izin Komunitas yang sudah ada | Melihat dan mengunggah: izin Komunitas apa pun / **Buat postingan**. Menyetujui: **Terbitkan**. Pengaturan: Super Admin. Tidak perlu jenis izin baru |

## 3. Isolasi beban

Tujuannya: lonjakan kiriman laporan, file rusak, atau file berbahaya tidak memperlambat layanan lain.

| Lapisan | Batas |
|---|---|
| Container | `finreport` 1 replika, CPU 0,25, memori 128 MB, 64 proses, `cpu_shares` 256 (bobot CPU seperempat layanan biasa saat server sibuk), `GOMAXPROCS=1`, `GOMEMLIMIT` 96 MiB. Hanya di jaringan `app`, tanpa akses internet |
| Unggahan API | Maksimal 2 unggahan diproses bersamaan; yang lain menunggu paling lama 3 detik lalu dijawab `503 busy` dengan `Retry-After`. Ukuran file maksimal 8 MiB (`413` bila lebih). Batas per key per menit (`rate_limit_per_minute`) dan per jam (`finreport.files_per_hour`, bawaan 120) |
| Isi zip | Maksimal 16 entri, `instance.xbrl` maksimal 64 MiB setelah dibuka, rasio kompresi maksimal 200:1. Zip bom, file bukan zip, atau zip tanpa XBRL ditolak tanpa diurai |
| Penguraian | Satu file sekali jalan, batas waktu 60 detik per file, XML dibaca mengalir (tidak dimuat utuh ke struktur pohon), entitas eksternal tidak pernah diproses |
| Database | Semua akses lewat PostgREST yang sudah ada, jadi tidak menambah koneksi PgBouncer. Satu laporan = beberapa panggilan RPC kecil. Antrean diklaim dengan `FOR UPDATE SKIP LOCKED` dan indeks parsial |
| Antivirus | Memakai ClamAV yang sudah ada. File laporan ±100 KB. Bila ClamAV mati, file menunggu dan dicoba lagi; tidak ada file yang lolos tanpa dipindai |
| Gagal sementara | Storage, PostgREST, atau ClamAV tidak terjangkau: dicoba lagi dengan jeda bertambah (1, 4, 9, 16 menit), lalu ditolak setelah 5 kali |
| Bila `finreport` mati | Hanya rute laporan keuangan yang tidak menjawab. Layanan lain berjalan normal. File yang sudah diterima menunggu di antrean. Healer me-restart container (label `olt.autoheal`) |

## 4. Data

### 4.1 `private.finreport_files`

Satu baris per file yang diterima. Status: `queued` → `processing` → `done`, `duplicate`, atau `rejected`.

| Kolom | Isi |
|---|---|
| `source` | `api` (dengan `key_id`) atau `hub` (dengan `uploaded_by`) |
| `object_name` | Lokasi di bucket: `api/<sha256>/report.zip` (kiriman ulang file yang sama menimpa objek yang sama) atau `hub/<agent>/<uuid>/report.zip` |
| `sha256` | Sidik file. Dari API langsung terisi; dari Hub terisi setelah diproses |
| `attempts`, `available_at`, `locked_until`, `locked_by` | Antrean dan percobaan ulang |
| `error_code`, `error_detail` | Alasan ditolak (lihat §6) |
| `report_id` | Laporan hasil urai, atau laporan yang sudah ada bila `duplicate` |

### 4.2 `private.finreport_reports`

Satu baris per laporan unik (sidik SHA-256 unik).

| Kolom | Isi |
|---|---|
| `entity_code`, `entity_name`, `sector`, `subsector` | Dari `idx-dei` |
| `period` | `Q1`, `Q2`, `Q3`, atau `FY` |
| `period_start`, `period_end` | Awal dan akhir periode kumulatif |
| `audit` | `audited`, `unaudited`, atau `unknown` |
| `currency` | `IDR`, `USD`, atau kode lain |
| `template` | `bank`, `general`, atau `basic` |
| `facts` | Angka per akun untuk empat konteks: `current`, `prior` (durasi), `current_end`, `prior_year_end` (posisi) |
| `metrics`, `summary`, `warnings` | Hasil hitung, teks ringkasan, peringatan |
| `superseded_at`, `supersedes` | Revisi: laporan baru untuk emiten dan periode yang sama menggantikan yang lama |
| `community_post_id` | Postingan resmi yang dibuat |

### 4.3 `private.finreport_config`

Satu baris: akun resmi yang memposting dan saklar posting otomatis. Diubah Super Admin di Hub, tercatat di jejak audit.

## 5. Perhitungan

Semua nilai di XBRL sudah dalam satuan penuh. Konteks dikenali dari tanggalnya (sesuai `CurrentPeriodStartDate`, `CurrentPeriodEndDate`, `PriorPeriodStartDate`, `PriorPeriodEndDate`, `PriorYearEndDate`), bukan dari nama konteks.

| Pembanding | Sumber |
|---|---|
| Kumulatif YoY | Laporan ini: `current` dibanding `prior` |
| Kuartal tunggal | `current` laporan ini − `current` laporan kumulatif sebelumnya (tahun buku sama) |
| Kuartal tunggal YoY | `prior` laporan ini − `prior` laporan kumulatif sebelumnya |
| Neraca YoY | `current_end` laporan ini dibanding `current_end` laporan periode sama tahun lalu. Bila belum ada, dibanding `prior_year_end` (akhir tahun buku lalu) dan ditulis "sejak akhir tahun buku" |
| Neraca QoQ | `current_end` laporan ini dibanding `current_end` laporan kumulatif sebelumnya |

| Template | Pos dan rasio |
|---|---|
| `bank` | Pendapatan bunga bersih, pendapatan operasional lain, beban cadangan kerugian, beban operasional, laba sebelum pajak, laba bersih bagian induk, EPS, kredit, DPK (giro + tabungan + deposito), CASA, LDR, cadangan terhadap kredit, ROE disetahunkan, rasio biaya terhadap pendapatan |
| `general` | Pendapatan, laba kotor dan marjin kotor, laba bersih bagian induk dan marjin bersih, EPS, total aset, liabilitas, ekuitas, DER, rasio lancar, arus kas operasi, ROE disetahunkan |
| `basic` | Laba bersih bagian induk, EPS, total aset, ekuitas, ROE disetahunkan |

Pos yang tidak ada di file dilewati, tidak diisi nol. Persentase perubahan tidak ditulis bila pembandingnya nol atau negatif; teks menyebut "berbalik laba" atau "berbalik rugi".

### Peringatan

| Kode | Arti | Menahan posting otomatis |
|---|---|---|
| `restated` | Angka tahun lalu di laporan ini berbeda lebih dari 0,5% dari laporan tahun lalu yang tersimpan | Ya |
| `revision` | Laporan ini menggantikan versi sebelumnya untuk periode yang sama | Ya |
| `template_basic` | Jenis industri tidak dikenali, hanya ringkasan dasar | Ya |
| `missing_lines` | Pos utama template tidak ditemukan | Ya |
| `no_official_account` | Akun resmi belum diatur atau nonaktif; postingan tidak dibuat | — |
| `post_rejected` | Teks ditolak pemeriksaan konten; postingan tidak dibuat | — |

## 6. Kode penolakan file

| Kode | Arti |
|---|---|
| `not_zip` | Bukan file zip yang valid |
| `zip_unsafe` | Terlalu banyak entri, terlalu besar setelah dibuka, atau rasio kompresi mencurigakan |
| `no_instance` | Tidak ada `instance.xbrl` di dalam zip |
| `invalid_xbrl` | XML rusak, bukan XBRL IDX, atau identitas laporan (`idx-dei`) tidak lengkap |
| `infected` | Ditandai antivirus. File langsung dihapus |
| `checksum_mismatch` | Sidik file di storage tidak sama dengan yang dihitung saat diterima |
| `unknown_entity` | Kode emiten tidak valid |
| `too_many_attempts` | Gagal sementara 5 kali berturut-turut |

File duplikat dan file terinfeksi dihapus dari storage lewat antrean pembersih (`janitor`). File laporan yang berhasil disimpan.

## 7. Batasan versi ini

- Template `general` disusun dari nama akun taksonomi IDX umum dan belum dicocokkan dengan file emiten non-bank sungguhan. Template `bank` sudah dicocokkan dengan laporan BBCA Q2 2026, Q3 2025, dan Q3 2026.
- Asuransi, sekuritas, dan pembiayaan memakai template `basic`.
- NPL, NIM resmi, dan CAR tidak ada di XBRL laporan keuangan, jadi tidak ditampilkan.
- Laporan yang datang terlambat (misalnya Q2 dikirim setelah Q3) tidak membuat ulang ringkasan Q3.
