# Riset

Ringkasan riset dibuat otomatis lalu diposting ke Stream oleh akun resmi setelah disetujui staf. Di aplikasi, postingan riset tampil sebagai **kartu riset** yang bentuknya ditentukan server. Tidak ada AI di dalamnya: angka diambil dari sumber terstruktur, dihitung dengan rumus tetap, dan disusun dengan template. Hasilnya sama untuk data yang sama dan bisa diperiksa ulang.

Pipeline-nya umum. Jenis riset ditambahkan satu per satu; jenis pertama adalah **laporan keuangan emiten** dari file XBRL bursa.

| | |
|---|---|
| Layanan | `research` (Go, `services/research`), satu container terpisah |
| Pintu masuk | `POST /integration/v1/research` (API key izin **Kirim riset**, `research`) dan unggah di Hub |
| Jenis yang didukung | `financial_report`: `instance.zip` XBRL dari IDX |
| Data | `private.research_files`, `private.research_reports`, `private.research_config`; file XBRL asli di bucket `financial-reports` |
| Postingan | `cs.community_posts` status `pending` dengan lampiran kartu (`card`), disetujui staf lain di **Komunitas → Postingan resmi** (empat mata) |
| Hub | **Komunitas → Riset** |
| Tersedia sejak | Migrasi `0197` (laporan keuangan), `0199` (pipeline umum, kartu riset), layanan `research` 0.2.0 |
| Panduan API | [../integration/riset.md](../integration/riset.md) |

## 1. Alur

```
Sistem pengirim ─┐
  (POST)         │  research API: cek key, izin, batas, ukuran, isi
                 ├─▶ simpan file mentah ─▶ research_files (queued)
Hub (unggah) ────┘                               │
                                                  ▼
                       research worker (satu file sekali jalan)
                       unduh ─ sidik SHA-256 ─ ClamAV ─ urai sesuai jenis
                       ambil pembanding ─ hitung ─ teks polos + dokumen kartu
                                                  │
                                                  ▼
             research_reports + postingan resmi (pending, lampiran card) ─▶ disetujui ─▶ Stream
```

1. Masukan diterima dari API atau Hub dan dicatat sebagai `queued`. Pengirim API langsung mendapat `id` untuk mengecek status.
2. Worker mengklaim satu file, mengunduhnya, mengecek sidik SHA-256 dan antivirus, lalu mengurainya sesuai jenis.
3. Hasil hitung disimpan bersama dua keluaran: **ringkasan teks polos** (isi postingan, untuk aplikasi lama, pencarian, dan notifikasi) dan **dokumen kartu** (untuk aplikasi baru).
4. Postingan resmi berstatus `pending` dibuat dalam transaksi yang sama, dengan cashtag `$KODE` sehingga ikut tampil di stream saham itu.

## 2. Kartu (dokumen versi 1)

Dokumen adalah tata letak sebagai data: server menentukan isi dan urutannya, aplikasi merender blok-blok itu berurutan. Jenis blok baru bisa ditambahkan tanpa mengubah aplikasi lama, karena blok yang tidak dikenal dilewati. Format kartu yang sama dipakai postingan riset dan postingan resmi yang dibuat staf di Hub.

Lampiran di postingan (maks. satu): `{"type": "card", "source": "research" | "manual", "stock_code", "document"}`, ditambah `research_id` dan `kind` bila `source` = `research`. Lampiran ini tidak punya `path`, jadi library lama mengabaikannya dan tetap menampilkan teks polos. Hanya layanan riset dan staf (lewat `cs_api.community_save_post`) yang bisa membuatnya; pengguna yang mencoba mendapat `400 invalid_attachments`.

| Field | Isi |
|---|---|
| `version` | `1` |
| `badge` | Label kecil, opsional, mis. "Ringkasan otomatis" |
| `title`, `subtitle` | Judul sumber dan keterangan, mis. "Laporan Keuangan Kuartal III 2026" dan "PT Bank Central Asia Tbk. · Belum diaudit" |
| `headline` | Kalimat utama, mis. "Laba bersih kuartal III naik 9,0% YoY" |
| `blocks` | 1–20 blok, berurutan |
| `disclaimer` | Keterangan sumber, opsional untuk kartu manual; kartu riset selalu menyertakan "Bukan rekomendasi investasi" |

| Blok | Field |
|---|---|
| `paragraph` | `text` |
| `list` | `style` (`numbered`/`bulleted`), `items` |
| `callout` | `title`, `text` |
| `metrics` | `metrics`: `label`, `value`, `change`, `trend` (`up`/`down`/`flat`) |

Database memeriksa bentuk dasar dokumen (`private.card_document_valid`: versi, judul dan kalimat utama wajib, 1–20 blok, jenis blok dikenal, ukuran ≤ 32 KB). Teks sudah diformat dalam bahasa Indonesia; aplikasi menampilkannya apa adanya.

### Kartu dari Hub

Di **Komunitas → Postingan resmi → Buat postingan**, staf bisa memilih tampilan **Kartu**, menyusun blok, dan melihat pratinjau seperti di aplikasi. `cs_api.community_save_post` menerima satu lampiran `card`, menormalkannya menjadi `source: manual`, memvalidasi kode saham, lalu **membuat teks pendamping otomatis** dari isi kartu (`private.card_text`: `$KODE — judul`, kalimat utama, blok, disclaimer). Teks itu menjadi isi postingan untuk aplikasi lama dan pencarian, dan ikut diperiksa daftar kata terlarang, sehingga isi kartu juga termoderasi. Persetujuan empat mata, jadwal, dan sematan tetap berlaku.

### Isi kartu laporan keuangan

| Bagian | Aturan |
|---|---|
| Headline | Laba bersih kuartal tunggal bila ada pembanding, selain itu kumulatif: naik/turun/stabil, berbalik dari rugi/laba, rugi menyempit/melebar |
| Paragraf | Nama emiten, laba periode itu, dan laba kumulatif bila kuartal tunggal tersedia |
| Angka | Maks. 4: laba bersih, pendapatan bunga bersih atau pendapatan, kredit atau total aset (YoY atau sejak akhir tahun buku), ROE |
| Poin bernomor | Maks. 5 kalimat dari pos pendapatan, neraca, dan rasio |
| Poin utama | Maks. 2 aturan yang terpenuhi, berurutan: laba berbalik arah, laba kuartal di atas/di bawah rata-rata kuartal sebelumnya, beban cadangan berubah ≥ 20%, kredit tumbuh ≥ 5 poin lebih cepat dari pendapatan bunga bersih (bank), laba dan pendapatan berlawanan arah, marjin kotor berubah ≥ 1 poin (umum) |

## 3. Keputusan desain

| Keputusan | Alasan |
|---|---|
| Satu pipeline umum dengan kolom `kind` | Jenis riset berikutnya (misalnya aksi korporasi) memakai gateway, antrean, persetujuan, kartu, dan halaman Hub yang sama; yang ditambah hanya pengurai dan template |
| Nama "Riset", bukan "AI research" | Isinya dihitung dengan rumus tetap tanpa AI; label "AI" akan menyesatkan nasabah dan staf |
| Layanan `research` terpisah dari `integration` | Unggahan dan penguraian tidak boleh menghabiskan slot, memori, atau CPU layanan notifikasi dan bot. Kong mengarahkan hanya `/integration/v1/research*` ke layanan ini |
| Dokumen kartu sebagai lampiran postingan | Ikut mengalir ke semua tempat postingan tampil (feed, detail, bagikan ke chat, realtime) tanpa mengubah tipe `feed_post`; library lama aman karena lampiran tanpa `path` diabaikan |
| Teks polos tetap menjadi isi postingan | Aplikasi lama, pencarian, notifikasi, dan moderasi konten tetap bekerja |
| Izin key `research` | Pengirim cukup satu jenis key untuk semua jenis riset |
| File XBRL tetap di bucket `financial-reports` | Bucket itu khusus file mentah laporan keuangan; jenis lain yang berupa JSON tidak perlu file |
| Postingan selalu `pending` lebih dulu | Konten keuangan yang salah angka berisiko tinggi. Posting otomatis hanya untuk laporan tanpa peringatan |
| Tanpa unduh otomatis dari situs IDX | Situs IDX memblokir skrip dengan proteksi Cloudflare. Data masuk dari sistem yang memang punya datanya atau dari staf |

## 4. Isolasi beban

| Lapisan | Batas |
|---|---|
| Container | `research` 1 replika, CPU 0,25, memori 128 MB, 64 proses, `cpu_shares` 256, `GOMAXPROCS=1`, `GOMEMLIMIT` 96 MiB, jaringan `app` saja |
| Unggahan API | 2 bersamaan (`503 busy` setelah 3 detik), 8 MiB per file, `rate_limit_per_minute` per key, `research.files_per_hour` (120) per key |
| Isi zip | Maks. 16 entri, satu `.xbrl`, 32 MiB setelah dibuka, rasio kompresi ≤ 200:1 |
| Penguraian | Satu file sekali jalan, batas 60 detik, XML dibaca mengalir |
| Database | Lewat PostgREST yang sudah ada; antrean `FOR UPDATE SKIP LOCKED` |
| Gagal sementara | Dicoba lagi 1, 4, 9, 16 menit, lalu ditolak `too_many_attempts` |

## 5. Data

| Tabel | Isi |
|---|---|
| `private.research_files` | Satu baris per masukan: sumber (`api` + key / `hub` + staf), lokasi file, sidik, status (`queued`, `processing`, `done`, `duplicate`, `rejected`), percobaan, alasan penolakan |
| `private.research_reports` | Satu baris per hasil unik: `kind`, emiten, periode, audit, mata uang, template, `facts`, `metrics`, `document`, `summary`, `warnings`, revisi (`supersedes`, `superseded_at`), postingan |
| `private.research_config` | Akun resmi yang memposting dan saklar posting otomatis (Super Admin, tercatat di jejak audit) |

Laporan baru untuk jenis, emiten, dan periode yang sama menggantikan versi lama dan membatalkan postingannya yang belum terbit.

## 6. Laporan keuangan (`financial_report`)

Konteks XBRL dikenali dari tanggal `idx-dei`. Pembanding: laporan kumulatif sebelumnya di tahun buku yang sama (kuartal tunggal, QoQ) dan laporan periode yang sama tahun lalu (neraca YoY, rasio tahun lalu). Laba rugi YoY selalu memakai angka pembanding di laporan terbaru; selisih > 0,5% dengan laporan tahun lalu yang tersimpan diberi peringatan `restated`.

| Template | Pos dan rasio |
|---|---|
| `bank` | Pendapatan bunga bersih, pendapatan operasional lain, beban cadangan, beban operasional, laba sebelum pajak, laba bersih, EPS, kredit, DPK, CASA, LDR, cadangan terhadap kredit, ROE, rasio biaya, biaya kredit |
| `general` | Pendapatan, laba kotor dan marjin, laba bersih dan marjin, EPS, aset, liabilitas, ekuitas, DER, rasio lancar, arus kas operasi, ROE |
| `basic` | Laba bersih, EPS, aset, ekuitas, ROE |

| Peringatan | Arti | Menahan posting otomatis |
|---|---|---|
| `restated` | Angka tahun lalu disajikan ulang | Ya |
| `revision` | Menggantikan versi sebelumnya | Ya |
| `template_basic` | Jenis industri tidak dikenali | Ya |
| `missing_lines` | Pos utama tidak ditemukan | Ya |
| `no_official_account` | Akun resmi belum diatur; postingan tidak dibuat | — |
| `post_rejected` | Teks ditolak pemeriksaan konten | — |

Kode penolakan file: `not_zip`, `zip_unsafe`, `no_instance`, `invalid_xbrl`, `unknown_entity`, `infected`, `checksum_mismatch`, `object_missing`, `too_many_attempts`, `invalid_report`.

## 7. Menambah jenis riset berikutnya

1. Migrasi: tambahkan nilai ke `research_reports_kind`, dan bila perlu longgarkan kolom yang khusus laporan keuangan (periode, audit, template).
2. Layanan `research`: pengurai untuk masukan jenis itu (zip atau JSON di endpoint yang sama), template teks polos, dan pembangun dokumen kartu. Blok kartu yang sudah ada biasanya cukup.
3. Hub: label jenis di daftar dan pratinjau. Aplikasi tidak perlu diubah selama blok kartu yang dipakai sudah dikenal library.

## 8. Batasan versi ini

- Template `general` belum dicocokkan dengan file emiten non-bank sungguhan; template `bank` sudah dicocokkan dengan laporan BBCA Q2 2026, Q3 2025, dan Q3 2026.
- Mengubah draf postingan riset yang ditolak lewat editor Hub menjadikannya kartu manual (teks pendamping dibuat ulang dari kartu). Untuk ringkasan asli, buat postingan baru dari detail laporan.
- Laporan yang dibuat sebelum `0199` tidak punya dokumen kartu; postingannya tetap teks polos.
